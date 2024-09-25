package MastroManucci::Controller::Ui;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::Util qw(b64_decode);
use JSON;

sub index ($self) {
    my $ui = $self->template_init();
    my @menu = (
        {
            text => 'Account Balances',
            link => "$ui/balance"
        },
        # {
        #     text => 'Chart of Accounts',
        #     link => "$ui/coa"
        # },
    );
    $self->respond_to(
        html => { menu => \@menu }
    );
}

sub ledgers ($self) {
    $self->template_init();
    my $ledger = $self->req->param('ledger');
    $self->log->debug("Changing selected ledger to: $ledger");
    $self->session( selected_ledger => $ledger);
    my $redirect_to = $self->req->headers->referrer || '/ui/auth';
    $self->redirect_to($redirect_to);
}

sub auth ($self) {
    $self->log->debug('Entering auth controller method...');
    $self->template_init();
    # hydrate ledgers in stash because /auth does not trigger preprocess hook
    unless(defined $self->stash('ledgers')){
        $self->stash( ledgers => $self->app->util->get_ledger_names );
    }
    # default to ledger 0 if no ledger selected yet for this session
    unless(defined $self->session('selected_ledger')){
        $self->session( selected_ledger => $self->util->get_ledger_name(0));
        $self->log->debug('selected_ledger set to default:'.$self->session('selected_ledger'));
    }
    # make sure active ledger is in stash for /auth
    unless(defined $self->stash('ledger')){
        $self->app->util->get_active_ledger($self);
        $self->log->debug('stash ledger:'.$self->stash('ledger'));
    }
    $self->respond_to(
        html => {  }
    );
}

sub login ($self) {
    my $ui = $self->template_init();
    my $provider = $self->req->param('provider');
    my $redirect_uri = $self->param('redirect_uri');
    $self->log->debug("IdP selected: $provider");
    $self->session( selected_provider => $provider);
    $redirect_uri = $redirect_uri ? $redirect_uri : "$ui/connect";
    $self->redirect_to($self->oauth2->auth_url($provider, redirect_uri  => $self->url_for($redirect_uri)->to_abs->to_string).'&response_type=code');
}

sub logout ($self) {
    $self->log->debug('Entering logout controller method...');
    my $ui = $self->template_init();
    $self->session(expires => 1);
    $self->redirect_to("$ui/auth", format => 'html');
}

sub connect ($self) {
    my $ui = $self->template_init();
    $self->log->trace("Entering connect...");

    my %get_token = (redirect_uri => $self->url_for("$ui/connect")->userinfo(undef)->to_abs);

    $self->log->debug("Calling get_token_p with redirect_uri:".$get_token{redirect_uri});

    return $self->oauth2->get_token_p($self->session('selected_provider') => \%get_token)->then(sub {

        my $provider_res = shift;
        $self->log->debug("get_token_p returned: $provider_res");

        # Redirected to IdP
        return unless $provider_res;

        # Token received
        $self->session(access_token => $provider_res->{access_token});
        $self->session(expiration => $ENV{SESSION_EXPIRY});
        $self->session(id_token => $provider_res->{id_token});
        $self->session(scope => $provider_res->{scope});
        $self->session(token_type => $provider_res->{token_type});
        $self->session(refresh_token => $provider_res->{refresh_token});
        my $idk_claims = $self->decode_token($provider_res->{id_token});
        $self->stash(username => $idk_claims->{sub});

        if($self->session('json_response')){
            $self->render(json => { login => 'OK', username => $self->stash('username') });
        }
        else{
            $self->redirect_to($ui);
        }

    })->catch(sub {
        if($self->session('json_response')){
            $self->render(json => { login => 'FAILED', error => shift });
        }
        else{
            $self->render(template => "$ui/connect", format => 'html', error => shift);
        }
    });

}

sub balance ($self) {
    $self->template_init();
    $self->req->params->param(no_cache => 1);
    $self->respond_to(
        html => { balance => $self->ledger->getBalance($self) }
    );

}

sub journal ($self) {
    $self->template_init();

    my $criteria_str = $self->req->params->param('__criteria');
    $self->log->debug("Previous Criteria:".($criteria_str || 'none'));
    $self->log->debug("New Criteria:".$self->req->params->to_string);

    my %previous_criteria = ( );
    eval {
        if ($criteria_str) {
            foreach my $p (split /,/, $criteria_str) {
                my ($k, $v) = split /=/, $p;
                $previous_criteria{$k} = $v;
            }
        }
    };

    # possible injection attack on criteria string
    if($@){
        $self->log->warn("Possible injection attack on journal criteria: $criteria_str");
        $criteria_str=undef;
        %previous_criteria = ( );
    }

    # check to see if the form was changed
    my $reset = 0;
    if($criteria_str && (keys %previous_criteria) > 0){
        my %new_criteria = %{$self->req->params->to_hash};
        foreach my $k (keys %new_criteria){
            next if $k eq '__criteria';
            next if $k eq 'starting_after'; # allows to go back or skip pages
            next if $new_criteria{$k} eq "";
            # if new criteria is not empty and exists in previous, then compare values
            if(defined $previous_criteria{$k}){
                unless($previous_criteria{$k} eq $new_criteria{$k}){
                    $self->log->debug("Criteria $k changed prev:".$previous_criteria{$k}.' new:'.$new_criteria{$k});
                    $reset = 1 ;
                    last;
                }
            }
            # any newly found criteria requires reset
            else {
                $self->log->debug("New criteria found $k");
                $reset = 1;
                last;
            }
        }
    }

    # if anything in the form changed, we need to reset to page 0
    if($reset){
        $self->log->debug("Reset to first page");
        $self->req->params->param(starting_after => 0);
    }
    else{
        # remove the +1 added by the screen
        my $starting_after = $self->req->params->param('starting_after');
        if($starting_after && $starting_after > 0){
            $self->req->params->param(starting_after => $starting_after - 1);
        }
    }

    # clear the __criteria state before rendering a new screen
    $self->req->params->param(__criteria => undef);

    $self->respond_to(
        html => { journal => $self->ledger->getJournal($self) }
    );

}

sub transaction ($self) {
    $self->template_init();

    $self->respond_to(
        html => { transaction => $self->ledger->getTransaction($self) }
    );

}


### HELPERS

# decode token
sub decode_token($self, $token){
    my @tokenparts = split/\./, $token;
    unless(scalar @tokenparts  == 3){
        $self->app->log->info("Could not decode token from IdP");
        return undef;
    }
    my $claims = undef;
    eval { $claims = decode_json(b64_decode($tokenparts[1])) };
    if ($@ || ref $claims ne 'HASH') {
        $self->app->log->info("Could not decode claims from Token: $@");
        return undef;
    }
    return($claims);
}

sub template_init($self){
    my $ui = $self->config('ui_uri');
    $self->stash(ui => $ui);
    $self->stash(static => "$ui/static");
    return $ui;
}


1;