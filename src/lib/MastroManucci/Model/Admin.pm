package MastroManucci::Model::Admin;

use strict;
use warnings;
no warnings qw(experimental);
use experimental qw(signatures);
use MastroManucci::Model::Error;
use MastroManucci::Model::Util;
use JSON;


sub new ($class) { bless {}, $class }

sub postCOA($self, $app) {

  ### handles

  my $errors = MastroManucci::Model::Error->new();
  my $db = $app->pg->db;
  my $data = $app->req->json;

  ### basic data (already validated by OpenAPI)

  my $drcr = &getDRCR($data->{type});
  $errors->addError('Invalid account type.','ty[e:'.$data->{type})
    unless defined $drcr;

  my $account;
  if($account = $db->select('coa',undef,{account => $data->{account}})->hash){
    $errors->addError('Account number already exists','account:'.$data->{account})
      if defined $account;
  }

  return $errors->getErrors if $errors->hasErrors;

  my %new_account;
  $new_account{account} = $data->{account};
  $new_account{description} = $data->{description};
  $new_account{type} = $data->{type};
  $new_account{heading} = $data->{heading};
  $new_account{drcr} = $drcr;

  # insert the new account
  my $id = $db->insert(coa => \%new_account, {returning => 'id'})->hash->{id};
  my $new_account = $db->select('coa',undef,{id => $id})->hash;
  return $self->mapCOAResponse($new_account,$db);
  
}

sub getCOA($self, $app) {

  ### handles
  my $errors = MastroManucci::Model::Error->new();
  my $db = $app->pg->db;
  my $account_param = $app->stash('account');

  my $account = $self->findAccount($db,$account_param);
  $errors->addError('Account not found',"account: .$account_param")
    unless defined $account;

  return $errors->getErrors if $errors->hasErrors;
  return $self->mapCOAResponse($account,$db);

}

sub deleteCOA($self, $app) {

  ### handles
  my $errors = MastroManucci::Model::Error->new();
  my $db = $app->pg->db;
  my $account_param = $app->stash('account');

  my $account = $self->findAccount($db,$account_param);
  $errors->addError('Account not found',"account: .$account_param")
    unless defined $account;

  my $jentries = $db->query('SELECT COUNT(*) as jentries FROM journal WHERE coa_id = ?',$account->{id})->hash->{jentries};
  $errors->addError('Account cannot be deleted because it has journal entries',"account: .$account_param")
    if ($jentries && $jentries > 0);

  return $errors->getErrors if $errors->hasErrors;

  $db->delete('coa', {id => $account->{id}});
  return undef;

}

sub findAccount($self, $db, $account){
  return $db->select('coa',undef,{account => $account})->hash;
}

sub mapCOAResponse($self, $account, $db){
  my %mapped;
  # mandatory
  $mapped{account} = $account->{account};
  $mapped{description} = $account->{description};
  $mapped{type} = $account->{type};
  $mapped{heading} = $account->{heading}  ? JSON::true : JSON::false;
  $mapped{drcr} = $account->{drcr};
  
  return \%mapped;
}


1;