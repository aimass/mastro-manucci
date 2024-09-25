BEGIN {
  use Cwd;
  push @INC, getcwd . '/t';
  #$ENV{DBI_TRACE}=1;
}

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Test::Named;
use JSON;

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
  $headers{'x-manucci-ledger'} = "ledger_one";
  $t->{headers} = \%headers;
  if(defined $t->app->config->{base_uri} ){
    $base_uri = $t->app->config->{base_uri};
    $t->{base_uri} = $base_uri;
  }
});


before_exit( sub { done_testing() });
exit main( @ARGV );

sub test_create_coa {

  my %coa = (
    foo => 'bar',
  );

  my $reference = int(rand(1000000));

  # OpenAPI Schema Validations
  $t->post_ok("$base_uri/coa" =>  \%headers => json => \%coa)
    ->status_is(400)->content_like(qr/errors.*Missing property.*/i);

  %coa = (
          account     => '1035',
          description => 'Sports X Cash',
          type        => 'BADTYPE',
          heading     =>  JSON::false
  );

  $t->post_ok("$base_uri/coa" => \%headers => json => \%coa)
    ->status_is(400)->content_like(qr/Not in enum list/i);


  $coa{type} = 'ASSET';
  $t->post_ok("$base_uri/coa" => \%headers => json => \%coa)
    ->status_is(201)
    ->json_is('/account' => $coa{account})
    ->json_is('/type' => $coa{type})
    ->json_is('/heading' => JSON::false)
    ->json_is('/drcr' => 'DR');

  $t->get_ok("$base_uri/coa/".$coa{account} => \%headers)
    ->status_is(200)
    ->json_is('/account' => $coa{account})
    ->json_is('/type' => $coa{type})
    ->json_is('/heading' => JSON::false)
    ->json_is('/drcr' => 'DR');

  $t->delete_ok("$base_uri/coa/foo" =>  \%headers => json => \%coa)
    ->status_is(404)->content_like(qr/errors.*not found.*/i);

  $t->delete_ok("$base_uri/coa/".$coa{account} => \%headers)
    ->status_is(204);




}

