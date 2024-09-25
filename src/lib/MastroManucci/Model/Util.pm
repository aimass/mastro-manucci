package MastroManucci::Model::Util;
use strict;
use warnings FATAL => 'all';
use experimental qw(signatures);
use Mojo::UserAgent;
use JSON;

sub new ($class) {
    my $self = {
        ledgers => [],
    };
    bless $self, $class;
}

sub add_ledger ($self, $ledger_name, $ledger_schema) {
    push @{$self->{ledgers}}, {
        name   => $ledger_name,
        schema => $ledger_schema,
    };
}

sub get_ledger ($self, $index) {
    return $self->{ledgers}->[$index];
}

sub get_ledger_name ($self, $index) {
    return $self->{ledgers}->[$index]->{name};
}

sub get_ledger_names ($self) {
    my @names = ( );
    foreach my $ledger (@{$self->{ledgers}}) {
        push @names, $ledger->{name};
    }
    return \@names;
}

sub get_oauth_token ($self, $app, $provider){

    my $p = $app->oauth2->providers->{$provider};
    unless($p){
        $app->app->log->error("No identity provider named $provider");
        return(undef);
    }

    my $user = 'ledger';
    my $pass = 'secret';
    my $ua  = Mojo::UserAgent->new;
    my $url = Mojo::URL->new($p->{token_url})->userinfo("$user:$pass");

    my $tx = $ua->post(
        $url => {
            'Accept' => 'application/json',
            'Content-Type' => 'application/x-www-form-urlencoded'
        } => form => {
            'grant_type' => 'client_credentials',
            'scope' => 'openid profile email',
        }
    );

    return from_json($tx->res->body);

}

# used to check active/selected ledger on every request
sub get_active_ledger ($self, $c) {
    my $found = sub {
        my $ledger = shift;
        $c->stash('ledger' => $ledger);
        return $ledger;
    };

    # header is preferred for API case
    my $ledger = $c->req->headers->header('x-manucci-ledger');
    if(defined $ledger && $ledger ne ''){
        return $found->($ledger);
    }

    # from session for UI case
    $ledger = $c->session('selected_ledger');
    if(defined $ledger && $ledger ne ''){
        return $found->($ledger);
    }

    # if a default ledger is set
    $ledger = $ENV{DEFAULT_LEDGER};
    if(defined $ledger && $ledger ne ''){
        return $found->($ledger);
    }
    return undef;
}


1;