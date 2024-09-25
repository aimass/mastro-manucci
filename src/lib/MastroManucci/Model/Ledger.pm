package MastroManucci::Model::Ledger;

#TODO: fomally document this.
# Ledger.pm is an orchestrator that maps HTTP semantiics to Ledger semantics.
# Usually this is 1:1 but this may not always be the case. I.e. one HTTP method
# could invoke multiple Ledger operations in one big transaction
# This module is split into multiple static modules that export all their
# subs and some constants to this one (e.g. Transaction, Journal, Balance,etc.)
# In general, all the API semantics for both the OpenAPI 3 HTTP API are identical for the Internal API
# I.e. all methods use transactionId instead of txn_id, or groupTyp instead of group_typ, etc.
# only the actual processing code (inside the sub itself) uses perl and database semantics.

use strict;
use warnings;
no warnings qw(experimental);
use experimental qw(signatures);
use Scalar::Util qw(looks_like_number);
use MastroManucci::Model::Error;
use MastroManucci::Model::Ledger::Entity;
use MastroManucci::Model::Ledger::Transaction;
use MastroManucci::Model::Ledger::Balance;
use MastroManucci::Model::Ledger::Journal;
use MastroManucci::Model::Ledger::SubAcct;
use MastroManucci::Model::LedgerCommons;
use JSON;


sub new($class) {bless {}, $class}


sub postEntity($self, $app) {

    my $errors = MastroManucci::Model::Error->new();
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    my $data = $app->req->json;

    my $dbtx = $db->begin;
    my $entity =  &createEntity($db, $data, $errors);
    return $errors->getErrors if $errors->hasErrors;
    $dbtx->commit;
    return &mapEntityResponse($entity, $data->{subtype});

}

sub postSubacct($self, $app) {

    my $errors = MastroManucci::Model::Error->new();
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    my $data = $app->req->json;

    my $dbtx = $db->begin;
    my $subacct =  &createSubAccount($db, $data, $errors);
    return $errors->getErrors if $errors->hasErrors;
    $dbtx->commit;
    return &mapSubacctResponse($db,$subacct);
}

sub postTransaction($self, $app) {

    my $errors = MastroManucci::Model::Error->new();
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    my $data = $app->req->json;
    my $dbtx = $db->begin;
    my $new_transaction = &createTransaction($db, $data, $errors);
    return $errors->getErrors if $errors->hasErrors;
    $dbtx->commit;
    return $new_transaction;

}

sub putTransaction($self, $app) {
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    my $data = $app->req->json;
    my $errors = MastroManucci::Model::Error->new();
    if($data->{account}){
        my $dbtx = $db->begin;
        my $transaction = &addTransactionLine($app,$errors);
        return $errors->getErrors if $errors->hasErrors;
        $dbtx->commit;
        return $transaction;
    }
    elsif($data->{newState}){
        my $dbtx = $db->begin;
        my $transaction = &changeTransactionState($db, $app->param('id'), $data->{newState}, $data, $errors);
        return $errors->getErrors if $errors->hasErrors;
        $dbtx->commit;
        return $transaction;
    }
    elsif($data->{reverse}){
        my $dbtx = $db->begin;

        my %reversal_data = ( );
        $reversal_data{reference} = $data->{reference} if defined $data->{reference};
        $reversal_data{groupTyp} = $data->{groupTyp} if defined $data->{groupTyp};
        $reversal_data{groupSta} = $data->{groupSta} if defined $data->{groupSta};
        $reversal_data{linkedTo} = $data->{linkedTo} if defined $data->{linkedTo};
        $reversal_data{description} = $data->{description} if defined $data->{description};
        $reversal_data{notes} = $data->{notes} if defined $data->{notes};
        $reversal_data{meta} = $data->{meta} if defined $data->{meta};
        $reversal_data{postDate} = $data->{postDate} if defined $data->{postDate};

        my $transaction = reverseTransaction($db, $app->param('id'), \%reversal_data, $errors);
        return $errors->getErrors if $errors->hasErrors;
        $dbtx->commit;
        return $transaction;

    }
    $errors->addError(qq|Cannot determine what to update to transaction from data|, 'system');
    return $errors->getErrors;

}

sub getTransaction ($self, $app) {
    my $errors = MastroManucci::Model::Error->new();
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    return &queryTransaction($db, $app->param('id'), $errors);
}

sub getTransactions ($self, $app) {
    my $errors = MastroManucci::Model::Error->new();
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    my $params = $app->req->params->to_hash;
    return &queryTransactions($db, $params, $errors);
}

sub getBalance($self, $app) {
    my $errors = MastroManucci::Model::Error->new();
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    my $params = $app->req->params->to_hash;
    return &calculateBalance($db, $params, $errors);
}

sub getBalanceCheck($self, $app) {
    my $errors = MastroManucci::Model::Error->new();
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    my $params = $app->req->params->to_hash;
    return &balanceCheck($db, $params, $errors);
}

sub getJournal ($self, $app) {
    my $errors = MastroManucci::Model::Error->new();
    my $ledger = $app->stash('ledger');
    my $db = $app->$ledger->db;
    my $params = $app->req->params->to_hash;
    return &queryJournal($db, $params, $errors);
}


1;


