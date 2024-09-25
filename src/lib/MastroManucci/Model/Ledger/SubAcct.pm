package MastroManucci::Model::Ledger::SubAcct;
use strict;
use warnings FATAL => 'all';
use experimental qw(signatures);
use MastroManucci::Model::LedgerCommons;

use Exporter qw(import);

our @EXPORT = qw(
    createSubAccount
    mapSubacctResponse
);
our @EXPORT_OK = qw();


sub createSubAccount($db, $data, $errors){

    my $parent = $db->select('coa', undef, { account => $data->{account} })->hash;
    $errors->addError("Account does not exist in COA", 'account:' . $data->{account}) unless $parent;

    my $subacct_type = $db->select('subacct_type', undef, { name => $data->{type} })->hash;
    $errors->addError("Subaccount type does not exist in COA", 'type:' . $data->{type}) unless $subacct_type;

    my $entity = $db->select('entity', undef, { acct_num => $data->{owner} })->hash;
    $errors->addError("Entity does not exist in database", 'acct_num:' . $data->{owner}) unless $entity;

    return $errors->getErrors if $errors->hasErrors;

    my %new_subacct = (
        account         => $data->{subaccount},
        coa_id          => $parent->{id},
        subacct_type_id => $subacct_type->{id},
        description     => $data->{description},
        entity_id       => $entity->{id},
        notes           => $data->{notes},
    );

    my $id = $db->insert(subacct => \%new_subacct, { returning => 'id' })->hash->{id};
    return $db->select('subacct', undef, { id => $id })->hash;
}

sub mapSubacctResponse($db, $subacct) {

    my $parent = $db->select('coa', undef, { id => $subacct->{coa_id} })->hash;
    my $entity = $db->select('entity', undef, { id => $subacct->{entity_id} })->hash;

    # mandatory
    my %mapped = (
        subaccount => $subacct->{account},
        account    => $parent->{account},
        owner      => $entity->{acct_num},
    );

    # optional
    if(defined $subacct->{subacct_type_id}){
        my $subacct_type = $db->select('subacct_type', undef, { id => $subacct->{subacct_type_id} })->hash;
        $mapped{type} = $subacct_type->{name} ;
    }
    $mapped{description} = $subacct->{description} if defined $subacct->{description};
    $mapped{notes} = $subacct->{notes} if defined $subacct->{notes};
    return \%mapped;
}


1;