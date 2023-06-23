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

  test_create_subacct($t);

  done_testing;
  return 0;
}

sub test_create_subacct {

  my $t = shift;

  my %headers = (
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
  );

  my %subacct = (
    foo => 'bar',
  );

  my $reference = int(rand(1000000));

  # OpenAPI Schema Validations
  $t->post_ok('/subacct' =>  \%headers => json => \%subacct)
    ->status_is(400)->content_like(qr/errors.*Missing property.*/i);

  # Wrong account
  %subacct = (
    reference => $reference,
    type      => 'CREDITOR',
    name      => 'Every Day Checking Account',
    link      => '{ system: "customers", id: 498764 }',
    account   => '9', #wrong
  );

  $t->post_ok('/subacct' => \%headers => json => \%subacct)
    ->status_is(400)->content_like(qr/does not exist in coa/i);

  # Wrong type for CREDITOR
  $subacct{account} = '1010';
  $t->post_ok('/subacct' => \%headers => json => \%subacct)
    ->status_is(400)->content_like(qr/must be of type liability/i);

  $subacct{account} = '2010';
  $t->post_ok('/subacct' => \%headers => json => \%subacct)
    ->status_is(201)
    ->json_is('/account' => $subacct{account})
    ->json_has('/id')
    ->json_is('/name' => $subacct{name})
    ->json_is('/reference' => $subacct{reference})
    ->json_is('/type' => $subacct{type})
    ->json_hasnt('/subType');

}

