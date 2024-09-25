#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';


BEGIN {
    use Cwd;
    push @INC, getcwd . '/t';
    #$ENV{DBI_TRACE}=1;
}

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use JSON;
use Data::UUID;
use Test::Named;

my %headers = (
    'Accept'       => 'application/json',
    'Content-Type' => 'application/json',
);

my $t = Test::Mojo->new('MastroManucci');

my $base_uri = '';
if(defined $t->app->config->{base_uri} ){
    $base_uri = $t->app->config->{base_uri};
}

before_launch(sub {
    $headers{Authorization} = "Bearer ".$t->app->util->get_oauth_token($t->app,'authpro')->{access_token};
    $t->{headers} = \%headers;
    if(defined $t->app->config->{base_uri} ){
        $base_uri = $t->app->config->{base_uri};
        $t->{base_uri} = $base_uri;
    }
});


before_exit( sub { done_testing() });
exit main( @ARGV );

sub test_balance_check {

    $t->get_ok("$base_uri/rbcheck?method=all" => \%headers )
        ->status_is(200);

    my $result = from_json($t->tx->res->body);

    $t->get_ok("$base_uri/rbcheck?method=ok" => \%headers )
        ->status_is(200);

    my $result2 = from_json($t->tx->res->body);

    ok(ref $result->{accounts} eq 'ARRAY');
    ok(ref $result2->{accounts} eq 'ARRAY');
    cmp_ok(scalar @{$result->{accounts}}, '==', scalar @{$result2->{accounts}});

    $t->get_ok("$base_uri/rbcheck?method=nok" => \%headers )
        ->status_is(200);

    $result = from_json($t->tx->res->body);

    ok(ref $result->{accounts} eq 'ARRAY');
    cmp_ok(scalar @{$result->{accounts}}, '==', 0);

    diag "RECEIVED:\n".$t->tx->res->body;


}