BEGIN {
  use Cwd;
  push @INC, getcwd.'/t';
  #$ENV{DBI_TRACE}=1;
}

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Test::Named;
use JSON;
use DateTime;


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

sub test_build {

  $t->get_ok("$base_uri/build" => \%headers )
      ->status_is(200)
      ->json_has('/built')
      ->json_has('/project')
      ->json_has('/revision')
      ->json_has('/version');

  diag "RECEIVED:\n".$t->tx->res->body;

}

sub test_create_subacct {


  my $reference = int(rand(1000000));
  my $smallrand = int(rand(999));


  my %coa = (
      account     => "1.1.1.$smallrand",
      description => 'Test cash account',
      type        => 'ASSET',
      heading     =>  JSON::false
  );

  $t->post_ok("$base_uri/coa" => \%headers => json => \%coa)
      ->status_is(201)
      ->json_is('/account' => $coa{account})
      ->json_is('/type' => $coa{type})
      ->json_is('/heading' => JSON::false)
      ->json_is('/drcr' => 'DR');

  my %meta = (
      ldap => 'bc1ef2b2-1980-11ee-be56-0242ac120002',
      foo  => 'bar',
  );

  my $meta_json = to_json(\%meta);

  my %new_entity = (
      name      => "TEST$reference",
      reference => "REF$reference",
      type      => 'ORGANIZATION',
      subtype   => 'CUSTOMER',
      meta      => $meta_json,
      notes     => 'ENTITY NOTES'
  );

  # Create the entity for these tests
  $t->post_ok("$base_uri/entities" =>  \%headers => json => \%new_entity)
      ->status_is(201)
      ->json_is('/name' => $new_entity{name})
      ->json_is('/reference' => $new_entity{reference})
      ->json_is('/type' => 'ORGANIZATION')
      ->json_is('/subtype', 'CUSTOMER')
      ->json_is('/notes', 'ENTITY NOTES')
      ->json_has('/meta')
      ->json_has('/accountNumber');

  my $entity = from_json($t->tx->res->body);

  $t->post_ok("$base_uri/entities" =>  \%headers => json => \%new_entity)
      ->status_is(400);

  my %subacct = (
      subaccount  => "1.1.1.$smallrand.$smallrand",
      account     => "1.1.1.$smallrand",
      type        => 'STANDARD',
      owner       => $entity->{accountNumber},
      description => 'Subaccount description',
      notes       => 'ACCOUNT NOTES'
  );

  $t->post_ok("$base_uri/subaccts" => \%headers => json => \%subacct)
    ->status_is(201)
    ->json_is('/subaccount' => $subacct{subaccount})
    ->json_is('/account' => $subacct{account})
    ->json_is('/description' => $subacct{description})
    ->json_is('/notes' => $subacct{notes})
    ->json_is('/type' => $subacct{type});

  return from_json($t->tx->res->body);

}

sub test_create_transaction () {


  my $reference = int(rand(1000000));
  my $smallrand = int(rand(999));

  # create an AR account
  my %coa = (
      account     => "1.2.1.$smallrand",
      description => 'Test AR account',
      type        => 'ASSET',
      heading     =>  JSON::false
  );

  $t->post_ok("$base_uri/coa" => \%headers => json => \%coa)
      ->status_is(201)
      ->json_is('/account' => $coa{account})
      ->json_is('/type' => $coa{type})
      ->json_is('/heading' => JSON::false)
      ->json_is('/drcr' => 'DR');

  # create an INCOME account
  %coa = (
      account     => "4.1.2.$smallrand",
      description => 'Test INCOME account',
      type        => 'INCOME',
      heading     =>  JSON::false
  );

  $t->post_ok("$base_uri/coa" => \%headers => json => \%coa)
      ->status_is(201)
      ->json_is('/account' => $coa{account})
      ->json_is('/type' => $coa{type})
      ->json_is('/heading' => JSON::false)
      ->json_is('/drcr' => 'CR');


  # create an entity and a subaccount
  my %meta = (
      ldap => 'bc1ef2b2-1980-11ee-be56-0242ac120002',
      foo  => 'bar',
  );

  my $meta_json = to_json(\%meta);

  my %new_entity = (
      name      => "TEST$reference",
      reference => "REF$reference",
      type      => 'ORGANIZATION',
      subtype   => 'CUSTOMER',
      meta      => $meta_json,
      notes     => 'ENTITY NOTES'
  );

  # Create the entity for these tests
  $t->post_ok("$base_uri/entities" =>  \%headers => json => \%new_entity)
      ->status_is(201)
      ->json_is('/name' => $new_entity{name})
      ->json_is('/reference' => $new_entity{reference})
      ->json_is('/type' => 'ORGANIZATION')
      ->json_is('/subtype', 'CUSTOMER')
      ->json_is('/notes', 'ENTITY NOTES')
      ->json_has('/meta')
      ->json_has('/accountNumber');

  my $entity = from_json($t->tx->res->body);

  my %subacct = (
      subaccount  => "1.2.1.$smallrand.$smallrand",
      account     => "1.2.1.$smallrand",
      type        => 'STANDARD',
      owner       => $entity->{accountNumber},
      description => 'Subaccount description',
      notes       => 'ACCOUNT NOTES'
  );

  $t->post_ok("$base_uri/subaccts" => \%headers => json => \%subacct)
      ->status_is(201)
      ->json_is('/subaccount' => $subacct{subaccount})
      ->json_is('/account' => $subacct{account})
      ->json_is('/description' => $subacct{description})
      ->json_is('/notes' => $subacct{notes})
      ->json_is('/type' => $subacct{type});


  my $dt = DateTime->now;
  my $dd = DateTime::Duration->new(days => 1);
  for(0..5) {
    $reference = int(rand(1000000));
    my %transaction = (
        reference   => $reference,
        description => "Invoice test $reference",
        meta        => $meta_json,
        notes       => "TXN NOTES",
        state       => 'COMPLETE',
        postDate    => $dt->ymd.' 12:00:00',
        lines       => [
            {
                account     => "1.2.1.$smallrand.$smallrand",
                amount      => 100.2345,
                entry       => 'DEBIT',
                description => "AR for Customer $reference"
            },
            {
                account     => "4.1.2.$smallrand",
                amount      => 100.2345,
                entry       => 'CREDIT',
                description => "Revenue for Customer $reference"
            }
        ]
    );

    diag "SENT:\n".to_json(\%transaction);

    $t->post_ok("$base_uri/transactions" => \%headers => json => \%transaction)
        ->json_is('/reference' => $reference)
        ->json_has('/meta')
        ->json_has('/transactionId')
        ->json_is('/description' => "Invoice test $reference")
        ->json_has('/postDate')
        ->json_is('/state' => "COMPLETE")
        ->json_is('/lines' =>
        eval qq|
      [
          {
              'description' => 'AR for Customer $reference',
              'entry' => 'DEBIT',
              'amount' => '100.23',
              'account' => '1.2.1.$smallrand.$smallrand'
          },
          {
              'entry' => 'CREDIT',
              'account' => '4.1.2.$smallrand',
              'amount' => '100.23',
              'description' => 'Revenue for Customer $reference'
          }
      ],
      |
    )
        ->status_is(201);
    diag "RECEIVED:\n".$t->tx->res->body;
    $dt = $dt + $dd;
  }

  # check meta data is good
  my $transaction = from_json($t->tx->res->body);
  is_deeply(\%meta, from_json($transaction->{meta}), 'Link deserialized ok');

  # TODO: finish location header
  #my $location = $t->tx->res->headers->location;
  #say $location;


  use Data::Dumper;
  warn Dumper($transaction);

  ### GET Transaction by Id and Collection


}

sub test_balance {



}

sub test_get_transactions(){




}
