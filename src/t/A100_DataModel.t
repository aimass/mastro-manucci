use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

exit main( @ARGV );

my $tc; 

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

  test_model_rules($t);

  done_testing;
  return 0;
}

sub test_model_rules {
  my $t = shift;

  my $db = $t->app->pg->db;

  # make sure we can query
  my $account = $db->select('coa',undef,{account => '3000'})->hash;
  cmp_ok($account->{description}, 'eq', 'CAPITAL', 'Got capital header account');


  # insert into coa
  my %new_account = (
    account     => '2510',
    alias       => '100000572',
    description => 'Five, Seven and Two',
    type        => 'LIABILITY',
    drcr        => 'CR',
    heading     => 'false',
  );

  my $r = $db->insert('coa',\%new_account);

  $account = $db->select('coa',undef,{alias => '100000572'})->hash;
  cmp_ok($account->{description}, 'eq', 'Five, Seven and Two', 'Got capital header account');

  $account = $db->delete('coa',{alias => '100000572'});

  $account = $db->select('coa',undef,{alias => '100000572'})->hash;
  ok(!defined $account, 'Delete account OK');



}


