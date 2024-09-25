package Mojolicious::Plugin::AuthFlow;
use Mojo::Base 'Mojolicious::Plugin', -strict, -signatures ;
use Mojo::Util qw(b64_decode);
use Mojo::JSON qw(decode_json encode_json);
use Scalar::Util 'looks_like_number';
use Carp qw( croak );

our $VERSION = '0.01';

has auth_uri => '/ui/auth';
has ignore_bearer => 0;
has ignore_cookie => 0;
has auto_renew => 0;
has session_expiry => 86400;
has https_force_rewrite => 0;

has ignored_paths => sub {
    return [
        '/static',
        '/favicon.ico',
        '/favicon.png',
        '/ui/auth',
        '/ui/login',
        '/ui/connect',
    ]
};

has provider_auth_config => sub {
    return { }
};

has user_search => '';
has user_create => '';
has preprocess => '';
has validate_itk_claims => '';
has validate_atk_claims => '';
has postprocess => '';


sub register ($self, $app, $config) {

    $app->log->debug("AuthFlow Plugin Registered");

    ## Load Plugin configuration

    # scalars
    $self->auth_uri($config->{auth_uri})
        if (defined $config->{auth_uri} && ref $config->{auth_uri} eq '');
    $self->ignore_bearer($config->{ignore_bearer})
        if (defined $config->{ignore_bearer} && ref $config->{ignore_bearer} eq '');
    $self->ignore_cookie($config->{ignore_cookie})
        if (defined $config->{ignore_cookie} && ref $config->{ignore_cookie} eq '');
    $self->auto_renew($config->{auto_renew})
        if (defined $config->{auto_renew} && ref $config->{auto_renew} eq '');
    $self->session_expiry($config->{session_expiry})
        if (defined $config->{session_expiry} && ref $config->{session_expiry} eq '');
    $self->https_force_rewrite($config->{https_force_rewrite})
        if (defined $config->{https_force_rewrite} && ref $config->{https_force_rewrite} eq '');

    if($self->ignore_bearer && $self->ignore_cookie){
        croak "You cannot ignore both cookie and bearer! choose one.";
    }

    # arrays
    $self->ignored_paths($config->{ignored_paths})
        if (defined $config->{ignored_paths} && ref $config->{ignored_paths} eq 'ARRAY');

    # hashes
    $self->provider_auth_config($config->{provider_auth_config})
        if (defined $config->{provider_auth_config} && ref $config->{provider_auth_config} eq 'HASH');

    # callbacks
    $self->preprocess($config->{preprocess})
        if (defined $config->{preprocess} && ref $config->{preprocess} eq 'CODE');
    $self->user_search($config->{user_search})
        if (defined $config->{user_search} && ref $config->{user_search} eq 'CODE');
    $self->user_create($config->{user_create})
        if (defined $config->{user_create} && ref $config->{user_create} eq 'CODE');
    $self->validate_itk_claims($config->{validate_itk_claims})
        if (defined $config->{validate_itk_claims} && ref $config->{validate_itk_claims} eq 'CODE');
    $self->validate_atk_claims($config->{validate_atk_claims})
        if (defined $config->{validate_atk_claims} && ref $config->{validate_atk_claims} eq 'CODE');
    $self->postprocess($config->{postprocess})
        if (defined $config->{postprocess} && ref $config->{postprocess} eq 'CODE');

    # set the filter
    $app->hook(before_dispatch => sub ($c) { $self->_do_filter($c) });

}

sub _config_ignored_paths($self, $ignored_paths){
    if($ignored_paths && ref $ignored_paths eq 'ARRAY'){
        foreach my $ignored_path (@{$ignored_paths}){
            push @{$self->ignored_paths}, $ignored_path;
        }
    }
}

sub _do_filter($self, $c) {

    my $access_token = undef;
    my $id_token = undef;
    my $headers = $c->req->headers;
    my $http_status_code = undef;
    my $error_message = undef;
    my $redirect_uri = undef;

    # if auth is enabled, we are probably behind a reverse proxy
    $c->req->url->base->scheme('https') if $self->https_force_rewrite;

    $c->app->log->debug("Entering authentication hook with path:" . $c->req->url->path);


    foreach my $ignored_path (@{$self->ignored_paths}){
        return if $c->req->url->path->contains($ignored_path);
    }

    ##########################
    # PREPROCESSING CALLBACK #
    ##########################
    if(ref $self->preprocess eq 'CODE'){
        $c->app->log->debug("Preprocess hook found. Calling...");
        my $retval = $self->preprocess->($c);
        if(defined $retval && ref $retval eq 'HASH'){
            $http_status_code = $retval->{code} if(defined $retval->{code} && &valid4xxcode($retval->{code}));
            $error_message = $retval->{message} if defined $retval->{message};
            $redirect_uri = $retval->{redirect_uri} if defined $retval->{redirect_uri};
            goto BAIL_OUT;
        }
    }

    ###################################################################################
    ###                                                                             ###
    ###   PHASE 1: extract ATK and/or ITK from Mojo Signed Cookie or Bearer Token   ###
    ###                                                                             ###
    ###################################################################################

    my $session = $c->session;

    # try to extract ATK from cookie first
    unless($self->ignore_cookie){
        if ($session->{access_token}) {
            $c->app->log->debug("Found ATK in cookie...");
            $c->app->log->debug(qq|Valid Session, expires in: $session->{expiration}|);
            $access_token = $session->{access_token};
            if ($session->{id_token}) {
                $id_token = $session->{id_token};
            }
            $c->app->log->debug("Access Token (from cookie): $access_token");
            $c->app->log->debug("OIDC Token (from cookie): $id_token") if defined $id_token;
        }
    }

    # if we don't have an ATK and we are not ignoring Bearer try that
    unless($self->ignore_bearer || $access_token) {
        $access_token = $headers->authorization;
        if ($access_token && $access_token =~ /^Bearer\s*(.*)$/) {
            $access_token = $1;
            $c->app->log->debug("Obtained access token from Bearer...");
        }
    }

    # if there's no atk up to this point don't even bother checking anything else
    unless ($access_token) {
        goto BAIL_OUT;
    }

    ###################################################################################
    ###                                                                             ###
    ###   PHASE 2: validate token claims depending on each case and/or hydrate req  ###
    ###                                                                             ###
    ###################################################################################

    # peek into tokens to try to determine provider
    my $provider = undef;
    my @jwtparts = split/\./, $access_token;
    my @idtparts = split/\./, $id_token if defined $id_token;

    ### VALIDATE ID TOKEN
    if($id_token){

        unless(scalar @idtparts  == 3){
            $c->app->log->info("Invalid or opaque ITK.");
            goto BAIL_OUT;
        }

        # try to match provider from non-validated claims
        my $claims = undef;
        eval { $claims = decode_json(b64_decode($idtparts[1])) };
        if ($@ || ref $claims ne 'HASH') {
            $c->app->log->warn("POSSIBLE SPOOFING: Could not decode claims from IDK: $@");
            goto BAIL_OUT;
        }
        foreach my $idp (keys %{$c->app->oauth2->providers}){
            # found our if idp name string is contained anywhere in the iss
            if(defined $claims->{iss} && $claims->{iss} =~ /$idp/){
                $provider = $idp;
            }
        }

        # bail unless defined provider
        unless(defined $provider){
            $c->app->log->info("Could not determine provider from iss on ITK");
            goto BAIL_OUT;
        }

        # OIDC provider should match provider in session
        unless($provider eq $c->session->{selected_provider}){
            $c->app->log->warn("POSSIBLE SPOOFING: Provider or does not match UI session");
            goto BAIL_OUT;
        }

        # formally validate token with provider and get validated claims
        $c->log->debug("Decoding IDK for $provider");
        eval { $claims = $c->app->oauth2->jwt_decode($provider, data => $id_token) };
        if ($@ || ref $claims ne 'HASH') {
            if($@ =~ /.*expired.*/i){
                goto TOKEN_EXPIRED;
            }
            $c->app->log->warn("POSSIBLE SPOOFING: Could not validate ITK: $@");
            goto BAIL_OUT;
        }

        $c->app->log->debug("ITK Expires in:".($claims->{exp} - time));

        unless(defined $claims->{sub}){
            $c->app->log->debug("ITK did not contain sub");
            goto BAIL_OUT;
        }

        unless(defined $claims->{iss}){
            $c->app->log->debug("ITK did not contain iss");
            goto BAIL_OUT;
        }

        # hydrate session or create user
        unless($c->session->{username}){

            my $user = undef;
            if(ref $self->user_search eq 'CODE'){
                $user = $self->user_search->($c,$claims->{sub});
            }

            # make sure user belongs to the original iss !
            if(defined $user) {
                unless ($user->{iss} eq $claims->{iss}) {
                    $c->app->log->warn("POSSIBLE SPOOFING: iss in claims did not match stored user's iss");
                    goto BAIL_OUT;
                }
            }

            # create user
            unless($user){
                if(ref $self->user_create eq 'CODE'){
                    $user = $self->user_create->($c,$claims);
                }
            }

            $c->app->log->debug("Provider from ITK: $provider");
            $c->session->{provider} = $provider;
            $c->session->{username} = defined $user->{username} ? $user->{username} : $claims->{sub};
        }

        # additional ITK claim validations callback
        if(ref $self->validate_itk_claims eq 'CODE'){
            $claims->{raw} = $id_token;
            goto BAIL_OUT unless ($self->validate_itk_claims->($c, $claims));
        }

    }

    # make sure stash always has user as well
    $c->stash( username => $c->session->{username}) if defined $c->session->{username};

    ### VALIDATE ACCESS TOKEN

    # allow request for non JWT or opque ATKs (e.g. Google, etc.)
    if(defined $provider){
        return unless $self->provider_auth_config->{$provider}->{use_atk};
    }

    unless(scalar @jwtparts == 3){
        $c->app->log->info("API does not allow an opaque ATK");
        goto BAIL_OUT;
    }

    # try to match provider from non-validated claims
    my $claims = undef;
    eval { $claims = decode_json(b64_decode($jwtparts[1])) };
    if ($@ || ref $claims ne 'HASH') {
        $c->app->log->warn("POSSIBLE SPOOFING: Could not decode claims from API request ATK: $@");
        goto BAIL_OUT;
    }
    foreach my $idp (keys %{$c->app->oauth2->providers}){
        # found our if idp name string is contained anywhere in the iss
        if(defined $claims->{iss} && $claims->{iss} =~ /$idp/){
            $provider = $idp;
        }
    }

    # bail unless defined provider
    unless(defined $provider){
        $c->app->log->info("Could not determine provider from iss on API call ATK");
        goto BAIL_OUT;
    }

    $c->app->log->debug("Provider from ATK: $provider");

    # formally validate token with provider and get validated claims
    eval { $claims = $c->app->oauth2->jwt_decode($provider, data => $access_token) };
    if ($@ || ref $claims ne 'HASH') {
        if($@ =~ /.*expired.*/i){
            $c->app->log->debug("ATK expired");
            goto TOKEN_EXPIRED;
        }
        $c->app->log->warn("POSSIBLE SPOOFING: Could not validate ATK: $@");
        goto BAIL_OUT;
    }

    $c->app->log->debug("ATK Expires in:".($claims->{exp} - time));

    unless(defined $claims->{sub}){
        $c->app->log->debug("ATK did not contain sub");
        goto BAIL_OUT;
    }

    unless(defined $claims->{iss}){
        $c->app->log->debug("ATK did not contain iss");
        goto BAIL_OUT;
    }

    # additional claim validations
    if(ref $self->validate_atk_claims eq 'CODE'){
        $claims->{raw} = $access_token;
        goto BAIL_OUT unless ($self->validate_atk_claims->($c, $claims));
    }


    ###########################
    # POSTPROCESSING CALLBACK #
    ###########################
    if(ref $self->postprocess eq 'CODE'){
        my $retval = $self->postprocess->($c);
        if(defined $retval && ref $retval eq 'HASH'){
            $http_status_code = $retval->{code} if(defined $retval->{code} && &valid4xxcode($retval->{code}));
            $error_message = $retval->{message} if defined $retval->{message};
            $redirect_uri = $retval->{redirect_uri} if defined $retval->{redirect_uri};
            goto BAIL_OUT;
        }
    }

    # all good! allow request to proceed...
    return;

    TOKEN_EXPIRED:
    if($self->auto_renew){
        $c->render_later;
        $self->_auto_renew($c);
        return undef;
    }

    BAIL_OUT:
    $self->_bail_out($c, $http_status_code, $error_message, $redirect_uri);

}

sub _bail_out($self, $c, $http_status_code, $error_message, $redirect_uri){
    $error_message = defined $error_message ? $error_message : 'No valid access and/or id token found in request.';
    $c->app->log->debug("Bailing out on: $error_message");

    # return 401 to REST/JSON API
    if ($c->req->headers->accept =~ /json/i || (defined $c->stash('format') && $c->stash('format') eq 'json')) {
        $c->app->log->debug("API returning 401 to UA");

        return $c->render(
            json   => { error => defined $error_message ? $error_message : 'Unauthorized: invalid access token' },
            status => defined $http_status_code ? $http_status_code : 401
        )
    }
    # HTML redirect to auth page
    $c->app->log->debug("UI redirect to auth page");
    $c->stash('error' => $error_message) if defined $error_message;
    $c->redirect_to(defined $redirect_uri ? $redirect_uri : $self->auth_uri, format => 'html');
    return;
}

sub _auto_renew ($self, $c){
    $c->log->debug("Entering auto_renew, calling get_refresh_token_p");

    my $provider = $c->session('selected_provider');
    my $data = {refresh_token => $c->session('refresh_token')};
    return $c->oauth2->get_refresh_token_p($provider => $data)->then(sub {
        my $provider_res = shift;

        # Renew failed
        unless ($provider_res){
            $c->log->debug("Refresh token failed :-(");
            $c->session(expires => 1);
            $self->_bail_out($c);
        }

        $c->log->debug("Refreshing session...");

        # Token received
        $c->session(access_token => $provider_res->{access_token});
        $c->session(expiration => $self->session_expiry);
        $c->session(id_token => $provider_res->{id_token});
        $c->session(scope => $provider_res->{scope});
        $c->session(token_type => $provider_res->{token_type});
        $c->session(refresh_token => $provider_res->{refresh_token});

        $c->log->debug("Refreshing session done. Continue to render:".$c->req->url->path);
        $c->app->routes->dispatch($c);

    })->catch(sub {
        my $error = shift;
        $c->log->debug("get_refresh_token_p returned error: $error");
        $self->_bail_out($c);
    });

}

sub valid4xxcode {
    my $code = shift;
    if(looks_like_number($code) && $code > 399 && $code < 500){
        return 1;
    }
    return 0;
}

1;