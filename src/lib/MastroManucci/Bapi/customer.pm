package MastroManucci::Bapi::customer;

use strict;
use warnings;
no warnings qw(experimental);
use experimental qw(signatures);
use MastroManucci::Model::Error;
use MastroManucci::Model::LedgerCommons;
use MastroManucci::Model::Ledger::Entity;
use MastroManucci::Model::Ledger::SubAcct;
use MastroManucci::Model::Ledger::Balance;
use MastroManucci::Bapi::bapicommons;
use JSON;

sub new($class) { bless {}, $class }

sub post($self, $app, $errors){
    my $ledger = $app->stash('ledger');

    my $data = $app->req->json;
    my $db = $app->$ledger->db;
    my $operation = $data->{operation};
    unless(defined $operation){
        $errors->addError("You must specify an operation on this BAPI",'operation: [null]');
        return $errors->getErrors
    }

    if ($operation eq 'create') {
        my $dbtx = $db->begin;
        my $enrollment = $self->createCustomer($db, $data, $errors);
        return $errors->getErrors if $errors->hasErrors;
        $dbtx->commit;
        return $enrollment;
    }
    else {
        $errors->addError("Operation $operation not supported on this BAPI", 'operation:');
        return $errors->getErrors;
    }

}

sub get($self, $app, $errors){
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;

    if(defined $app->param('customerId')){
        return $self->getEnrollment ($db, $app->param('customerId'), $app->param('on'), $errors)
    }
    elsif(defined $app->param('ledgerAccount')){
        return $self->getEnrollment ($db, $app->param('ledgerAccount'), $app->param('on'), $errors)
    }
    else{
        $errors->addError('You must specify customerId or ledgerAccount','customer:');
        return $errors->getErrors;
    }

}


sub createCustomer ($self, $db, $data, $errors) {

    # BAPI specific validations
    $errors->addError("Account name cannot be null or blank", 'customerName:')
        unless (defined $data->{customerName} && $data->{customerName} ne '');
    $errors->addError("Enrollment ID cannot be null or blank", 'enrollmentId:')
        unless (defined $data->{customerId} && $data->{customerId} ne '');
    $errors->addError("Account ID cannot be null or blank", 'accountId:')
        unless (defined $data->{accountId} && $data->{accountId} ne '');

    return $errors->getErrors if $errors->hasErrors;

    ### Create the entity ###

    my %new_entity = (
        name              => $data->{customerName},
        reference         => $data->{customerId},
        type              => 'ORGANIZATION',
        subtype           => 'CUSTOMER',
        meta              => to_json({accountId => $data->{accountId}}),
    );

    my $entity = &createEntity($db, \%new_entity, $errors);

    if(!defined $entity || $errors->hasErrors){
        $errors->addError("Could not create Customer Account", 'entity:');
        return $errors->getErrors;
    }

    ### Create the Accounts ###

    my $subacct_type = 'STANDARD';

    # AR
    my $ar = qq|$AR_ACCOUNT.$entity->{acct_num}.$CUST_ACCRU_AR|;
    $self->create_subaccount($db,$ar,$AR_ACCOUNT,$subacct_type,qq|Accrued Receivables|,$entity->{acct_num},$errors);
    return $errors->getErrors if $errors->hasErrors;

    #Revenue
    my $revenue = qq|$REVENUE_ACCT.$entity->{acct_num}.$CUST_TXN_REVN|;
    $self->create_subaccount($db,$revenue,$REVENUE_ACCT,$subacct_type,qq|Transaction Revenue for $entity->{acct_num}|,$entity->{acct_num},$errors);
    return $errors->getErrors if $errors->hasErrors;
    return $self->mapEnrollmentResponse($db, $entity);

}

sub getEnrollment($self, $db, $id, $on, $errors) {

    my $entity = &get_entity_by_account_or_ref($db, $id);
    return $errors->getErrors if $errors->hasErrors;
    return $self->mapEnrollmentResponse($db, $entity, $on) if defined $entity;
    return undef;

}


sub create_subaccount($self,$db,$subacct,$acct,$subacct_type,$desc,$owner,$errors){

    my %new_subacct = (
        subaccount      => $subacct,
        account         => $acct,
        type            => $subacct_type,
        description     => $desc,
        owner           => $owner,
        notes           => undef,
    );
    &createSubAccount($db, \%new_subacct, $errors)
}

sub mapEnrollmentResponse($self, $db, $entity, $on =  undef) {

    my $meta = from_json($entity->{meta}) if defined $entity->{meta};
    my %mapped = (
        ledgerAccount => $entity->{acct_num},
        customerName  => $entity->{name},
        cuistomerId  => $entity->{reference},
        created       => $entity->{created},
        accountId     => $meta->{accountId},
    );
    $mapped{notes} = $entity->{notes} if defined $entity->{notes};

    return \%mapped;
}

1;