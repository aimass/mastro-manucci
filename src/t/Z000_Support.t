

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

before_exit( sub { done_testing() });
exit main( @ARGV );

sub test_usio {

    #red path
    my %bapi_body = (
        operation    => 'creat', #typo
        customerName => "Usio",
        enrollmentId => "280821216",
        accountId    => "1234567890",
    );

    diag "SENT:\n".to_json(\%bapi_body);

    $t->post_ok('/bapi/enrollments' => \%headers => json => \%bapi_body)
        ->status_is(400)
        ->json_has('/errors',$bapi_body{customerName});

    diag "RECEIVED:\n".$t->tx->res->body;

    # green path
    $bapi_body{operation} = 'create';
    diag "SENT:\n".to_json(\%bapi_body);

    $t->post_ok('/bapi/enrollments' => \%headers => json => \%bapi_body)
        ->json_has('/accountNumber')
        ->json_is('/customerName',$bapi_body{customerName})
        ->json_is('/enrollmentId',$bapi_body{enrollmentId})
        ->json_is('/accountId',$bapi_body{accountId});

    diag "RECEIVED:\n".$t->tx->res->body;

    return(from_json($t->tx->res->body))


}

