package MastroManucci::Model::Ledger;

use strict;
use warnings;
no warnings qw(experimental);
use experimental qw(signatures);
use MastroManucci::Model::Error;
use MastroManucci::Model::Util;
use JSON;

use constant STATUS_CREATED     => 1;
use constant STATUS_APPROVED    => 2;
use constant STATUS_IN_PROGRESS => 3;
use constant STATUS_COMPLETE    => 4;
use constant STATUS_CLOSED      => 5;

sub new ($class) { bless {}, $class }

sub postSubacct($self, $app){

    ### handles

    my $errors = MastroManucci::Model::Error->new();
    my $db = $app->pg->db;
    my $data = $app->req->json;

    ### basic data (already validated by OpenAPI)

    my %new_subacct;
    $new_subacct{name} = $data->{name};
    $new_subacct{reference} = $data->{reference};
    $new_subacct{notes} = $data->{notes};
    $new_subacct{type} = $data->{type};

    ### business logic validations

    my $account = $db->select('coa',undef,{account => $data->{account}})->hash;
    $errors->addError("Account does not exist in COA",'account:'.$data->{account}) unless $account;

    if($new_subacct{type} eq 'DEBTOR'){
        $errors->addError('Debtor account must be of type ASSET','account:'.$data->{account})
          unless $account->{type} eq 'ASSET';
    }
    elsif($new_subacct{type} eq 'CREDITOR'){
        $errors->addError('Creditor account must be of type LIABILITY','account:'.$data->{account})
          unless $account->{type} eq 'LIABILITY';
    }
    else{
        $errors->addError(qq|Book type $new_subacct{type} is invalid|,'type');
    }
    $new_subacct{coa_id} = $account->{id};

    if($data->{subType}){
        if(my $subtype = $db->select('subacct_subtype',undef,{name => $data->{subType}})->hash){
            $new_subacct{subacct_subtype_id} = $subtype->{id};
        }
        else{
            $errors->addError(qq|Book subtype $data->{subType} is invalid|,'subType');
        }
    }

    return $errors->getErrors if $errors->hasErrors;

    # insert the subacct
    my $id = $db->insert(subacct => \%new_subacct, {returning => 'id'})->hash->{id};
    my $new_subacct = $db->select('subacct',undef,{id => $id})->hash;
    return $self->mapBookResponse($new_subacct,$db);

}

sub mapBookResponse($self, $subacct, $db){
    my %mapped;
    # mandatory
    $mapped{id} = $subacct->{uid};
    $mapped{reference} = $subacct->{reference};
    $mapped{type} = $subacct->{type};
    $mapped{account} = $db->select('coa',undef,{id => $subacct->{coa_id}})->hash->{account};
    # optional
    if($subacct->{subacct_subtype_id}){
        $mapped{subType} = $db->select('subacct_subtype',undef,{id => $subacct->{subacct_subtype_id}})->hash->{name};
    }
    $mapped{name} = $subacct->{name} if defined $subacct->{name};
    $mapped{link} = $subacct->{link} if defined $subacct->{link};
    $mapped{notes} = $subacct->{notes} if defined $subacct->{notes};
    return \%mapped;
}


sub postTransaction($self, $app){

    ### handles

    my $errors = MastroManucci::Model::Error->new();
    my $db = $app->pg->db;
    my $data = $app->req->json;

    ### basic data (already validated by OpenAPI)

    my %new_transaction;
    # optional fields
    $new_transaction{postdate} = $data->{postDate} if defined $data->{postDate};
    $new_transaction{reference} = $data->{reference} if defined $data->{reference};
    $new_transaction{description} = $data->{description} if defined $data->{description};
    $new_transaction{subtype} = $data->{subType} if defined $data->{subType};

    ### additional data validations

    # link must ne JSON
    my $valid_json = eval { decode_json($data->{link}) };
    $errors->addError(qq|link is not valid JSON: $@|,'link') if ($@);
    #$new_transaction{link} = $data->{link};

    # dataIn must be JSON (for transaction history)
    $valid_json = eval { decode_json($data->{dataIn}) };
    $errors->addError(qq|dataIn is not valid JSON: $@|,'dataIn') if ($@);

    # transaction state
    if($data->{state}){
        if(my $state = $db->select('transaction_state',undef,{name => $data->{state}})->hash){
            $new_transaction{state_id} = $state->{id};
        }
        else{
            $errors->addError(qq|Transaction State $data->{state} is invalid|,'state');
        }
    }
    else{
        $new_transaction{state_id} = STATUS_CREATED;
    }

    # validate transaction subacct
    my $subacct;
    if($subacct = $db->select('subacct',undef,{uid => $data->{subacctId}})->hash){
        $new_transaction{subacct_id} = $subacct->{id};
    }
    else{
        $errors->addError(qq|Could not find subacct with ID: $data->{state} is invalid|,'state');
    }
    $new_transaction{coa_id} = $subacct->{coa_id};
    $new_transaction{type} = $subacct->{type} eq 'DEBTOR' ? 'AR' : 'AP';

    ### transaction lines and accounting logic

    my @transaction_lines = ( );
    my $transaction_total = 0;
    foreach my $line (@{$data->{lineItems}}){
        my $line_subacct = $db->select('subacct',undef,{uid => $line->{subacctId}})->hash;
        unless($line_subacct){
            $errors->addError(qq|Book $line->{subacctId} is invalid for line with amount $line->{amount}|,'state')
        }
        if($new_transaction{type} eq 'AR'){
            unless($line_subacct->{type} eq 'CREDITOR'){
                $errors->addError(qq|Book type must be CREDITOR for $line->{subacctId} for line with amount $line->{amount}|,'state')
            }
        }
        else{
            unless($line_subacct->{type} eq 'DEBTOR'){
                $errors->addError(qq|Book type must be DEBTOR for $line->{subacctId} for line with amount $line->{amount}|,'state')
            }
        }
        my %transaction_line = (
          subacct_id     => $line_subacct->{id},
          coa_id      => $line_subacct->{coa_id},
          amount      => $line->{amount},
          reference   => $line->{reference},
          description => $line->{description},
          notes       => $line->{notes},
        );
        push @transaction_lines, \%transaction_line;
        $transaction_total += $line->{amount};
    }

    $new_transaction{amount} = $transaction_total;

    ## cannot start transaction if errors up to this point
    return $errors->getErrors if $errors->hasErrors;

    ### start actual db transaction (auto rollback when $dbtx gets destroyed)
    my $dbtx = $db->begin;

    ### NOTE: As of Pg 13 returning id does not work on partitioned tables
    ### https://dba.stackexchange.com/questions/58497/return-id-from-partitioned-table-in-postgres

    # insert the main transaction
    $db->insert(transaction => \%new_transaction);
    my $id = $db->query(q|SELECT currval('transaction_id_seq'::regclass) AS id|)->hash->{id};

    unless($id){
        $errors->addError(qq|Error creating Transaction in System. Please contact support.|,'system');
        return $errors->getErrors;
    }

    my $new_transaction = $db->select('transaction',undef,{id => $id})->hash;

    ### insert the transaction lines
    foreach my $line (@transaction_lines){
        $line->{transaction_id} = $new_transaction->{id};
        $db->insert(transaction_line => $line);
        $id = $db->query(q|SELECT currval('transaction_line_id_seq'::regclass) AS id|)->hash->{id};
        unless($id){
            $errors->addError(qq|Error creating Transaction Line in System. Please contact support.|,'system');
            return $errors->getErrors;
        }
    }

    ### insert transaction history
    my %new_transaction_history;
    $new_transaction_history{transaction_id} = $new_transaction->{id};
    $new_transaction_history{data_in} = $data->{dataIn};
    $new_transaction_history{state_from_id} = undef;
    $new_transaction_history{state_to_id} = $new_transaction->{state_id};
    $new_transaction_history{notes} = 'NEW DOCUMENT';

    &insertHistory($db,$errors,\%new_transaction_history);
    return $errors->getErrors if $errors->hasErrors;

    ### end actual db transaction
    $dbtx->commit;

    return $self->mapTransactionResponse($new_transaction,$db);

}


sub postInvoice($self, $app){

    ### handles

    my $errors = MastroManucci::Model::Error->new();
    my $db = $app->pg->db;
    my $order_uid = $app->param('id');

    #TODO: accept an optional status in body
    #TODO: accept reference and description for GL entries

    my $order = $db->select('transaction',undef,{uid => $order_uid})->hash;

    unless($order){
        $errors->addError(qq|Could not find order with UID: $order_uid|,'id');
        $errors->setCode(404);
    }
    unless($order->{subtype} eq 'ORDER' && ($order->{state_id} != STATUS_CLOSED)){
        $errors->addError(qq|Document must be of subType 'ORDER' and must not be status 'CLOSED': $order_uid|,'id');
    }

    return $errors->getErrors if $errors->hasErrors;

    ### start actual db transaction (auto rollback when $dbtx gets destroyed)
    my $dbtx = $db->begin;

    # close the order
    my %new_history = (
      transaction_id   => $order->{id},
      state_from_id => $order->{state_id},
      state_to_id   => STATUS_CLOSED,
      notes         => 'Closing ORDER to transform to INVOICE',
    );
    &insertHistory($db,$errors,\%new_history);
    return $errors->getErrors if $errors->hasErrors;

    # transform to INVOICE
    my $results = $db->update('transaction',
      {
        subtype  => 'INVOICE',
        state_id => STATUS_IN_PROGRESS,
      },
      {id => $order->{id}});
    unless($results->rows == 1){
        $errors->addError(qq|Could not change ORDER to INVOICE: $order_uid|,'id');
        return $errors;
    }

    # invoice is now in progress
    %new_history = (
      transaction_id   => $order->{id},
      state_from_id => STATUS_CLOSED,
      state_to_id   => STATUS_IN_PROGRESS,
      notes         => 'Reopening INVOICE to IN_PROGRESS',
    );
    &insertHistory($db,$errors,\%new_history);
    return $errors->getErrors if $errors->hasErrors;

    my $invoice_coa = $db->select('coa',undef,{id => $order->{coa_id}})->hash;

    ### GL main journal entry: INVOICE
    my %gl_entry = (
      coa_id      => $order->{coa_id},
      transaction_id => $order->{id},
    );
    $gl_entry{reference} = $order->{reference} if defined $order->{reference};
    $gl_entry{description} = $order->{description} if defined $order->{description};
    if($invoice_coa->{drcr} eq 'DR') {
        $gl_entry{credit} = $order->{amount};
        $gl_entry{debit} = 0;
    }
    else{
        $gl_entry{credit} = 0;
        $gl_entry{debit} = $order->{amount};
    }
    my $parent_id = &insertJournal($db,$errors,\%gl_entry);
    return $errors->getErrors if $errors->hasErrors;

    ### GL journal double entry: INVOICE LINES
    my $invoice_lines = $db->select('transaction_line',undef,{transaction_id => $order->{id}});
    while(my $line = $invoice_lines->hash) {
        my $coa = $db->select('coa',undef,{id => $line->{coa_id}})->hash;
        $gl_entry{coa_id} = $line->{coa_id};
        $gl_entry{parent_id} = $parent_id;
        if($coa->{drcr} eq 'DR') {
            $gl_entry{credit} = $order->{amount};
            $gl_entry{debit} = 0;
        }
        else{
            $gl_entry{credit} = 0;
            $gl_entry{debit} = $order->{amount};
        }
        &insertJournal($db, $errors, \%gl_entry);
        return $errors->getErrors if $errors->hasErrors;
    }
    ### end actual db transaction
    $dbtx->commit;

    # refresh the [now] invoice from db
    $order = $db->select('transaction',undef,{id => $order->{id}})->hash;
    return $self->mapTransactionResponse($order,$db);

}

sub insertHistory($db,$errors,$record){
    $db->insert(transaction_history => $record);
    my $id = $db->query(q|SELECT currval('transaction_history_id_seq'::regclass) AS id|)->hash->{id};
    unless($id){
        $errors->addError(qq|Error creating Transaction History in System. Please contact support.|,'system');
        return 0;
    }
    return $id;
}

sub insertJournal($db,$errors,$record){
    $db->insert(journal => $record);
    my $id = $db->query(q|SELECT currval('journal_id_seq'::regclass) AS id|)->hash->{id};
    unless($id){
        $errors->addError(qq|Error creating Journal Entry in System. Please contact support.|,'system');
        return 0;
    }
    return $id;
}


sub mapTransactionResponse($self,$transaction,$db){

    my %mapped;
    # mandatory
    $mapped{id} = $transaction->{uid};
    $mapped{state} = $db->select('transaction_state',undef,{id => $transaction->{state_id}})->hash->{name};
    $mapped{postDate} = &dateFromTS($transaction->{postdate});
    $mapped{subacctId} = $db->select('subacct',undef,{id => $transaction->{subacct_id}})->hash->{uid};
    $mapped{type} = $transaction->{type};
    $mapped{subType} = $transaction->{subtype};
    $mapped{amount} = $transaction->{amount};

    # optional
    $mapped{reference} = $transaction->{reference} if defined $transaction->{reference};
    $mapped{description} = $transaction->{description} if defined $transaction->{description};
    $mapped{link} = $transaction->{link} if defined $transaction->{link};

    my @line_items = ( );
    my $new_transaction_lines = $db->select('transaction_line',undef,
      {transaction_id => $transaction->{id}}, {order_by => 'id'});
    while(my $transaction_line = $new_transaction_lines->hash){
        my %line = (
          subacctId      => $db->select('subacct', undef, { id => $transaction_line->{subacct_id} })->hash->{uid},
          account     => $db->select('coa', undef, { id => $transaction_line->{coa_id} })->hash->{account},
          amount      => $transaction_line->{amount},
        );
        # optional
        $line{reference} = $transaction_line->{reference} if defined $transaction_line->{reference};
        $line{description} = $transaction_line->{description} if defined $transaction_line->{description};
        $line{notes} = $transaction_line->{note} if defined $transaction_line->{note};

        push @line_items, \%line;
    }
    $mapped{lineItems} = \@line_items;

    return \%mapped;

}

1;


