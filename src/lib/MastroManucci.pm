package MastroManucci;
use Time::HiRes qw(time);
use Mojo::Base 'Mojolicious', -signatures;
use Mojo::Pg;
use MastroManucci::Model::Admin;
use MastroManucci::Model::Ledger;
use MastroManucci::Model::Util;

use constant  BUILD_VERSION => $ENV{BUILD_VERSION};
use constant  BUILD_REVISION => $ENV{BUILD_REVISION};
use constant  BUILD_TIMESTAMP => $ENV{BUILD_TIMESTAMP};
use constant  BUILD_PROJECT => $ENV{BUILD_PROJECT};

sub startup ($self) {

  $ENV{INT_CURR_SYMBOL} = defined $ENV{INT_CURR_SYMBOL} ? $ENV{INT_CURR_SYMBOL} : '$';

  $self->log->format(sub ($t, $level, @lines) {
    my $time = time;
    my ($s, $m, $h, $day, $month, $year) = localtime time;
    $time = sprintf('%04d-%02d-%02d %02d:%02d:%08.5f', $year + 1900, $month + 1, $day, $h, $m,
        "$s." . ((split '\.', $time)[1] // 0));
    my $log;
    $level=~s/error/ERROR/isg;
    foreach my $line (@lines) {
      $log.="[$time] [$$] [$level] $line\n";
    };
    return $log;
  });

  my $the_secret = <<'THE_SECRET';

The murder of their beloved ones shall they see
and over supplication unto eternity,
but mercy and peace shall ye not attain

THE_SECRET

  my $dsn = qq|dbi:Pg:dbname=$ENV{PGDATABASE};host=$ENV{PGHOST};port=$ENV{PGPORT};|;

  $self->secrets([$the_secret]);
  $self->plugin('NotYAMLConfig');
  $self->plugin('DefaultHelpers');
  $self->plugin( OpenAPI => { url => $self->home->rel_file('openapi/openapi.yaml') } );
  $self->plugin(
    SwaggerUI => {
      route   => $self->routes()->any('api'),
      url     => "/api",
      title   => "Mastro Manucci Ledger",
      favicon => "/public/favicon.png"
    }
  );
  $self->plugin('NotYAMLConfig');
  $self->helper(admin => sub { state $admin = MastroManucci::Model::Admin->new });
  $self->helper(ledger => sub { state $ledger = MastroManucci::Model::Ledger->new });
  $self->helper(util => sub { state $util = MastroManucci::Model::Util->new });
  # assume OpenAPI mode
  $self->renderer->default_format('json');

  # connect to the ledgers
  my $l = 1;
  $self->util->{ledgers} = [ ];
  while($l){
    if (defined $ENV{"LEDGER_$l"}) {
      my $name = $ENV{"LEDGER_$l"};
      my $schema = $ENV{"LEDGER_$l".'_SCHEMA'};
      $self->helper($name => sub { state $pg = Mojo::Pg->new->dsn($dsn)});
      $self->$name->username($ENV{"LEDGER_$l".'_ROLE'});
      $self->$name->password($ENV{"LEDGER_$l".'_PASSWORD'});
      $self->$name->on(connection => sub ($pg, $dbh) {
        $dbh->do("SET search_path TO $schema, public");
      });
      $self->util->add_ledger($name, $schema);
      $l++;
    }
    else{
      $l=0;
    }
  }

  # configure identity providers (up to 5)
  my $auth_enabled = 0;
  my %provider_config = ( );
  my %provider_auth_config = ( );
  for (1 .. 5) {
    if (defined $ENV{"AUTH_PROVIDER_$_"}) {
      $auth_enabled = 1;
      $provider_config{$ENV{"AUTH_PROVIDER_$_"}} = {
          key            => $ENV{"AUTH_PROVIDER_$_".'_KEY'},
          scope          => 'email openid profile',
          secret         => $ENV{"AUTH_PROVIDER_$_".'_SEC'},
          well_known_url => $ENV{"AUTH_PROVIDER_$_".'_WKU'},
      };
      $provider_auth_config{$ENV{"AUTH_PROVIDER_$_"}} = {
          use_atk   => $ENV{"AUTH_PROVIDER_$_" . '_ATK'},
      };
    }
  }
  $self->plugin(OAuth2 => \%provider_config);

  # Static files
  my $ui = $self->config->{ui_uri};
  #$self->static->prefix('/static'); #requires Mojo 9.35
  foreach (@{$self->static->paths}) {
    $self->log->debug("Static path: $_");
  };

  my @ignored_paths = (
      $self->config->{base_uri} . '/build',
      "$ui/auth",
      "$ui/login",
      "$ui/logout",
      "$ui/ledgers",
      "$ui/connect",
      "$ui/static",
      "/favicon.ico",
      "/mojo",
  );

  if ($auth_enabled) {
    $self->plugin(AuthFlow => {
        auth_uri             => "$ui/auth",
        ignored_paths        => \@ignored_paths,
        user_search          => \&user_search,
        user_create          => \&user_create,
        validate_itk_claims  => \&validate_itk_claims,
        validate_atk_claims  => \&validate_atk_claims,
        preprocess           => \&auth_preprocess,
        auto_renew           => 1,
        provider_auth_config => \%provider_auth_config,
        session_expiry       => $ENV{SESSION_EXPIRY} ? $ENV{SESSION_EXPIRY} : undef,
        https_force_rewrite  => $ENV{HTTPS_FORCE_REWRITE} ? $ENV{HTTPS_FORCE_REWRITE} : undef,
    });
  }


  # UI Routes
  $self->defaults(layout => 'default');
  $self->routes->get($ui)->to('ui#index');
  $self->routes->get("$ui/auth")->to('ui#auth');
  $self->routes->get("$ui/login")->to('ui#login');
  $self->routes->get("$ui/logout")->to('ui#logout');
  $self->routes->get("$ui/connect")->to('ui#connect');
  $self->routes->get("$ui/balance")->to('ui#balance');
  $self->routes->get("$ui/journal")->to('ui#journal');
  $self->routes->get("$ui/transaction/:id")->to('ui#transaction');
  $self->routes->get("$ui/ledgers")->to('ui#ledgers');
  $self->routes->get("$ui/static/*")->to(cb => sub ($c) {
    $c->log->debug("Serve static file:".$c->req->url->path);
    $c->reply->static($c->req->url->path);
  });

  my $r = $self->routes;

}

sub user_search ($c, $username) {
  # only for code clarity...
  my $ledger = $c->stash('ledger');
  # ...it doesn't matter which ledger you use because user and role tables are in the public schema
  $ledger = $c->app->util->get_ledger_names->[0] unless (defined $ledger && $ledger ne '');
  return $c->app->$ledger->db->select('ledger_user', undef, { username => $username })->hash;
}

sub user_create ($c, $claims) {
  # only for code clarity...
  my $ledger = $c->stash('ledger');
  # ...it doesn't matter which ledger you use because user and role tables are in the public schema
  $ledger = $c->app->util->get_ledger_names->[0] unless (defined $ledger && $ledger ne '');
  my $r = $c->app->$ledger->db->insert('ledger_user',
      {
          username              => $claims->{sub},
          name                  => $claims->{name} || undef,
          given_name            => $claims->{given_name} || undef,
          family_name           => $claims->{family_name} || undef,
          sub                   => $claims->{sub} || undef,
          aud                   => $claims->{aud} || undef,
          accountid             => $claims->{accountId} || undef,
          iss                   => $claims->{iss} || undef,
          email                 => $claims->{email} || undef,
          email_verified        => $claims->{email_verified} || undef,
          zoneinfo              => $claims->{zoneinfo} || undef,
          locale                => $claims->{locale} || undef,
          phone_number          => $claims->{phone_number} || undef,
          phone_number_verified => $claims->{phone_number_verified} || undef,
      }
  );
  if($r->sth->err){
    $c->app->log->error("Could not insert user into system:".$r->sth->errstr);
  }
  my $user = $c->app->$ledger->db->select('ledger_user', undef, { username => $claims->{sub} })->hash;
  my $viewer_role = $c->app->$ledger->db->select('ledger_role', undef, { name => "viewer" })->hash;
  $c->app->$ledger->db->insert('ledger_user_role', { ledger_user_id => $user->{id}, ledger_role_id => $viewer_role->{id} });

  return $user;

}

sub auth_preprocess ($c) {
  $c->app->log->debug("auth_preprocess called");

  my $base_uri = $c->app->config->{base_uri};

  # hydrate available ledgers for every request (except ignored paths)
  $c->stash( ledgers => $c->app->util->get_ledger_names );

  # try to determine active ledger from request
  my $ledger = $c->app->util->get_active_ledger($c);
  $c->app->log->debug('Ledger determined from request:'.(defined $ledger ? $ledger : 'NONE'));

  # cannot proceed without a ledger
  unless(defined $ledger && $ledger ne ''){
    return {
        code    => 422,
        message => 'No ledger selected'
    }
  }
  $c->app->log->debug("Selected ledger: $ledger");

}

# use this method to add addtional validations to ID Token claims, scopes, etc.
sub validate_itk_claims ($c, $claims) {
  $c->app->log->debug("Additional validations on ID Token called");

  # add any global per-request validations here and return 0 if they fail

  #inject itk_data into stash so it's available everywhere for this request
  $c->stash(itk_data => $claims);

  return 1;
}

# use this method to add addtional validations to Access Token claims, scopes, etc.
sub validate_atk_claims ($c, $claims) {
  $c->app->log->debug("Additional validations on Access Token called");

  # add any global per-request validations here and return 0 if they fail

  #inject itk_data into stash so it's available everywhere for this request
  $c->stash(atk_data => $claims);

  return 1;
}


1;
