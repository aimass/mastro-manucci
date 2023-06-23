BEGIN {
  use Cwd;
  push @INC, getcwd.'/t';
  #$ENV{DBI_TRACE}=1;
}

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use JSON;


exit main( @ARGV );

sub main {
  my @args  = @_;

  my $t = Test::Mojo->new('MastroManucci');

  if (@args) {
    for my $name (@args) {
      die "No test method test_$name\n"
        unless my $func = __PACKAGE__->can( 'test_' . $name );
        $func->($t);
      }
    done_testing;
    return 0;
  }

  test_create_coa($t);

  done_testing;
  return 0;
}

sub test_create_coa {

  my $t = shift;

  my %headers = (
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
  );

  my %coa = (
    foo => 'bar',
  );

  my $reference = int(rand(1000000));

  # OpenAPI Schema Validations
  $t->post_ok('/coa' =>  \%headers => json => \%coa)
    ->status_is(400)->content_like(qr/errors.*Missing property.*/i);

  %coa = (
          account     => '1035',
          description => 'Sports X Cash',
          type        => 'BADTYPE',
          heading     =>  JSON::false
  );

  $t->post_ok('/coa' => \%headers => json => \%coa)
    ->status_is(400)->content_like(qr/Not in enum list/i);


  $coa{type} = 'ASSET';
  $t->post_ok('/coa' => \%headers => json => \%coa)
    ->status_is(201)
    ->json_is('/account' => $coa{account})
    ->json_is('/type' => $coa{type})
    ->json_is('/heading' => JSON::false)
    ->json_is('/drcr' => 'DR');

  $t->get_ok('/coa/'.$coa{account} => \%headers)
    ->status_is(200)
    ->json_is('/account' => $coa{account})
    ->json_is('/type' => $coa{type})
    ->json_is('/heading' => JSON::false)
    ->json_is('/drcr' => 'DR');

  $t->delete_ok('/coa/foo' =>  \%headers => json => \%coa)
    ->status_is(404)->content_like(qr/errors.*not found.*/i);

  $t->delete_ok('/coa/'.$coa{account} => \%headers)
    ->status_is(204);




}

