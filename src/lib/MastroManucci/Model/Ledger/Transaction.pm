package MastroManucci::Model::Ledger::Transaction;
use strict;
use warnings FATAL => 'all';
no warnings qw(experimental);
use experimental qw(signatures);
use MastroManucci::Model::LedgerCommons;
use MastroManucci::Model::Commons;
use Scalar::Util qw(looks_like_number);
use JSON;
use Exporter qw(import);

=head1 TRANSACTION MODULE

This module encapsulates all the logic pertaining to Transaction Management in the Ledger. All the methods
are static and public methods are automatically exported to the module who uses it. Normally, this module
is used by the Ledger.pm module and BAPI code.

B<The data input and output of the public methods are marshalled according to the semantics of the core REST
API defined in the OpenAPI Specification of the system.>

=cut

our @EXPORT = qw(
    createTransaction
    changeTransactionState
    addTransactionLine
    queryTransactions
    queryTransaction
    updateTransactionMeta
    reverseTransaction
);
our @EXPORT_OK = qw(
);

=head2 PUBLIC METHODS

These methods are meant to be used externally by the Ledger.pm module and BAPIs

=head3 createTransaction

This method creates a transaction in the system. It first unmarshalls and validates the incoming data
and then records the transaction in the system.

B<This method returns a marshalled transaction object.>

=cut


sub createTransaction($db, $data, $errors){
    my %unmarshalled = %{ &__unmarshall_transaction($db, $data, $errors) };
    return $errors->getErrors if $errors->hasErrors;
    my $transaction = __create_transaction($db, \%unmarshalled, $errors);
    return $errors->getErrors if $errors->hasErrors;
    return &__marshall_transaction_response($db, $transaction);
}

=head3 changeTransactionState

This method changes the state of a transaction according to the transaction state machine. It can
optionally update the following non protected fields:

=over 4

=item notes

=item groupRef

=item groupTyp

=item groupSta

=back

B<This method returns a marshalled transaction object.>

=cut

sub changeTransactionState($db, $transactionId, $newState, $optionalData, $errors){

    my $transaction = $db->select('transaction', undef, { txn_id => $transactionId })->hash;

    unless(defined $transaction){
        $transactionId = 'NULL' unless (defined( $transactionId && $transactionId ne ''));
        $errors->addError(qq|Cannot find transaction: $transactionId|, 'id');
    }

    my $new_state = $db->select('transaction_state', undef, { name => $newState })->hash;
    unless(defined $new_state){
        $errors->addError(qq|State is invalid: $newState|, 'newState');
    }

    my %optional_data = ();
    if (defined $optionalData && ref $optionalData eq 'HASH') {
        $optional_data{notes} = $optionalData->{notes} if defined $optionalData->{notes};
        $optional_data{group_ref} = $optionalData->{groupRef} if defined $optionalData->{groupRef};
        $optional_data{group_typ} = $optionalData->{groupTyp} if defined $optionalData->{groupTyp};
        $optional_data{group_sta} = $optionalData->{groupSta} if defined $optionalData->{groupSta};
    }

    return $errors->getErrors if $errors->hasErrors;

    my $original_state_name = $db->select('transaction_state', undef, { id => $transaction->{state_id} })->hash->{name};

    my $post_transaction = 0;

    ###############################################
    ##     S I M P L E  S T A T E  L O G I C     ##
    ##       basic states, except REVERSED       ##
    ###############################################

    # CANCELLED cannot change state
    if($transaction->{state_id} == $STATUS_CANCELED){
        $errors->addError(qq|Cannot change CANCELED transaction to any state|, 'newState');
    }
    # DRAFT can change to any other state
    elsif($transaction->{state_id} == $STATUS_DRAFT){
        if($new_state->{id} == $STATUS_CANCELED){
            $post_transaction = 0;
        }
        elsif (grep {/^$new_state->{id}$/}  ($STATUS_APPROVED, $STATUS_IN_PROGRESS, $STATUS_COMPLETE)) {
            $post_transaction = 1;
        }
        else{
            $errors->addError(qq|Cannot change from $original_state_name to $newState'|, 'newState');
        }
    }
    # IN_PROGRESS can only change to COMPLETE
    elsif($transaction->{state_id} == $STATUS_IN_PROGRESS){
        unless ($new_state->{id} == $STATUS_COMPLETE) {
            $errors->addError(qq|Cannot change from $original_state_name to $newState |, 'newState');
        }
    }
    else{
        $errors->addError(qq|Change from $original_state_name to $newState is not supported |);
    }

    return $errors->getErrors if $errors->hasErrors;

    # Update state and history
    $transaction = &__update_transaction_state_and_history($db, $transaction, $new_state->{id}, \%optional_data, undef, $errors);
    return $errors->getErrors if $errors->hasErrors;

    # Post to Journal
    $transaction = &__post_transaction_to_journal($db, $transaction, $errors) if $post_transaction == 1;
    return $errors->getErrors if $errors->hasErrors;

    return &__marshall_transaction_response($db,$transaction);

}

=head3 reverseTransaction


This method reverses a posted transaction by generating the exact opposite journal entries and posting it to
transactions and the journal. It also mutually links the transactions by the reverse_id field in the database.

The reversed transaction will copy all the data of the original transaction unless the data is overriden by
passing reversalData. Fields that can be overriden are:

=over 4

=item notes

=item meta

=item description

=item linkedTo

=item groupRef

=item groupTyp

=item groupSta

=back

B<This method receives and returns a marshalled transaction objects.>

=cut

sub reverseTransaction($db, $transactionId, $reversalData, $errors) {

    my $original_transaction = $db->select('transaction', undef, { txn_id => $transactionId })->hash;
    unless(defined $original_transaction){
        $errors->addError(qq|Could not find transaction with id: $transactionId|, '/transactionId');
    }

    my $current_state_id = $original_transaction->{state_id};
    my $current_state = $db->select('transaction_state', undef, { id => $current_state_id })->hash->{name};

    unless(defined $reversalData->{reference}){
        $errors->addError(qq|Cannot reverse without a reference|, '/reference');
    }
    my $reference = $reversalData->{reference};

    my $ref_found = $db->select('transaction', undef, { reference => $reference })->hash;
    if (defined $ref_found) {
        $errors->addError(qq|Reference provided is not unique: $reference|, '/reference');
    }

    unless (grep $current_state_id, ($STATUS_APPROVED, $STATUS_IN_PROGRESS, $STATUS_COMPLETE)) {
        $errors->addError(qq|Transaction: $transactionId in state $current_state cannot be reversed|, 'id');
    }

    return $errors->getErrors if $errors->hasErrors;

    my %reverse_transaction = (
        state_id => $STATUS_COMPLETE,
        reference => $reference,
    );

    # postdate is now() unless provided
    $reverse_transaction{postdate} = $reversalData->{postDate} if defined $reversalData->{postDate};

    # these default to the original transaction unless overriden
    $reverse_transaction{notes} = defined $reversalData->{notes} ? $reversalData->{notes} : $original_transaction->{notes};
    $reverse_transaction{meta} = defined $reversalData->{meta} ? $reversalData->{meta} : $original_transaction->{meta};
    $reverse_transaction{description} = defined $reversalData->{description} ? $reversalData->{description} : $original_transaction->{description};
    $reverse_transaction{linked_to} = $reversalData->{linkedTo} ? $reversalData->{linkedTo} : $original_transaction->{txn_id};
    $reverse_transaction{group_ref} = $reversalData->{groupRef} ? $reversalData->{groupRef} : $original_transaction->{group_ref};
    $reverse_transaction{group_typ} = $reversalData->{groupTyp} ? $reversalData->{groupTyp} : $original_transaction->{groupTyp};
    $reverse_transaction{group_sta} = $reversalData->{groupSta} ? $reversalData->{groupSta} : $original_transaction->{group_sta};
    # these cannot be overridden
    $reverse_transaction{amount} = $original_transaction->{amount} if defined $original_transaction->{amount};
    $reverse_transaction{entity_id} = $original_transaction->{entity_id} if defined $original_transaction->{entity_id};

    my @reverse_transaction_lines = ( );
    my $original_transaction_lines = $db->select('transaction_line', undef, { transaction_id => $original_transaction->{id} }, { order_by => 'id' });
    while (my $line = $original_transaction_lines->hash) {
        # get textual account number for createTransaction()
        my $account;
        # use subaccount if defined
        if(defined $line->{subacct_id}){
            $account = $db->select('subacct', undef, { id =>  $line->{subacct_id} })->hash->{account};
        }
        # else use account
        else{
            $account = $db->select('coa', undef, { id =>  $line->{coa_id} })->hash->{account};
        }
        # identical lines but with inverted CREDIT and DEBIT
        my $entry = $line->{entry} eq 'DEBIT' ? 'CREDIT' : 'DEBIT';
        my %reverse_transaction_line = (
            reference   => $line->{reference},
            description => $line->{description},
            notes       => $line->{notes},
            account     => $account,
            entry       => $entry,
            amount      => $line->{amount},
        );
        push @reverse_transaction_lines, \%reverse_transaction_line;
    }

    $reverse_transaction{lines} = \@reverse_transaction_lines;

    # create the reverse transaction
    my $reversed_transaction = &__create_transaction($db, \%reverse_transaction, $errors);
    return $errors->getErrors if $errors->hasErrors;

    # update cross reference reversed_id in both transactions
    $db->update('transaction',  {reverse_id => $reversed_transaction->{id}}, {id => $original_transaction->{id} });
    $db->update('transaction',  {reverse_id => $original_transaction->{id}}, {id => $reversed_transaction->{id} });
    &__update_transaction_state_and_history($db, $original_transaction, $STATUS_REVERSED, undef, undef, $errors);
    return $errors->getErrors if $errors->hasErrors;

    # return updated reversed transaction
    return &__marshall_transaction_response($db, $db->select('transaction', undef, { id => $reversed_transaction->{id} })->hash);

}

sub updateTransactionMeta ($db, $transactionId, $meta, $errors) {

    my $transaction = $db->select('transaction',  undef, {txn_id => $transactionId})->hash;
    unless(defined $transaction){
        $errors->addError(qq|Transaction id:$transactionId not found|, '/transactionId');
    }

    my $json_meta;
    eval {
        $json_meta = to_json($meta);
    };
    unless(defined $json_meta){
        $errors->addError(qq|Invalid metadata|, '/meta');
    }

    return $errors->getErrors if $errors->hasErrors;

    $db->update('transaction',  {meta => $json_meta}, {id => $transaction->{id}});

    # add transaction history
    my %new_transaction_history = (
        transaction_id => $transaction->{id},
        notes          => "Updated metadata"
    );
    &__insert_transaction_history($db, \%new_transaction_history, $errors);
    return $errors->getErrors if $errors->hasErrors;

    return &__marshall_transaction_response($db, $db->select('transaction',  undef, {id => $transaction->{id}})->hash);
}

#TODO: this feature will allow to add transaction lines to IN_PROGRESS documents
sub addTransactionLine($app, $errors){
    warn "TODO";
}

sub queryTransaction($db, $txn_id, $errors) {

    my $transaction = $db->select('transaction', undef, { txn_id => $txn_id })->hash;
    if($transaction){
        return __marshall_transaction_response($db, $transaction);
    }
    return $errors->getErrors;

}

sub queryTransactions($db, $criteria, $errors){

    my %where = ( );

    ### GROUP FILTERS ###

    $where{group_typ} = $criteria->{groupTyp} if defined  $criteria->{groupTyp};
    $where{group_ref} = $criteria->{groupRef} if defined  $criteria->{groupRef};
    $where{group_sta} = $criteria->{groupSta} if defined  $criteria->{groupSta};

    ### UNLINKED ###
    if(defined $criteria->{unlinked} && $criteria->{unlinked} eq JSON::true){
        $where{linked_to} = undef;
    }

    ### LINKED TO ###
    if(defined $criteria->{linkedTo} && looks_like_number($criteria->{linkedTo})){
        $where{linked_to} = $criteria->{linkedTo};
    }

    ### STATUS ###

    if (defined $criteria->{status}) {
        if ($criteria->{status} eq 'o'){
            $where{state_id} = { -in => [$STATUS_DRAFT, $STATUS_APPROVED, $STATUS_IN_PROGRESS]}
        }
        elsif($criteria->{status} eq 'c'){
            $where{state_id} = { -in => [$STATUS_COMPLETE, $STATUS_CANCELED, $STATUS_REVERSED]}
        }
        else{
            $errors->addError(qq|Status criteria $criteria->{status} is invalid|, '/status');
        }
    }

    ### ENTITY ###

    if (defined $criteria->{entity}){
        my $entity = get_entity_by_account_or_ref($db, $criteria->{entity});
        if (defined $entity) {
            $where{entity_id} = $entity->{id};
        }
        else{
            $errors->addError(qq|Entity not found: $criteria->{entity}|, '/entity');
        }
    }

    ### DATES ###

    $where{postdate} = { '>=', $criteria->{from_date} } if defined $criteria->{from_date};
    if (defined $criteria->{to_date}) {
        if (defined $where{postdate}) {
            $where{postdate} =
                [ -and =>
                    { '>=', $criteria->{from_date} },
                    { '<=', $criteria->{to_date}   }
                ];
        }
        else {
            $where{postdate} = { '<=', $criteria->{to_date} }
        };
    }

    ### METADATA ###

    my $meta_query;
    my $meta_operator = '@>'; #only this one supported
    if(defined $criteria->{meta}) {
        if($criteria->{meta} =~ /^\s*@>\s*\'((\{|\[).*(\}|\]))\'$/){
            $meta_query = $1;
        }
        else{
            $errors->addError(qq|Metadata query is invalid: $criteria->{meta}|, '/meta');
        }
    }

    $where{meta} = { $meta_operator, $meta_query } if defined $meta_query;

    ### ORDER AND PAGINATION ###

    #FIXME: this is not correct

    my $order_clause = undef;
    $criteria->{order} = 'oldest_first' unless defined $criteria->{order};
    $criteria->{order_by} = 'postdate' unless defined $criteria->{order_by};
    if ($criteria->{order} eq 'oldest_first') {
        if($criteria->{order_by} eq 'created') {
            #id and created are the same but id is faster
            $order_clause = { -asc => 'id' };
        }
        else{
            $order_clause = { -asc => 'postdate' };
        }
    }
    elsif ($criteria->{order} eq 'newest_first') {
        if($criteria->{order_by} eq 'created') {
            #id and created are the same but id is faster
            $order_clause = { -desc => 'id' };
        }
        else{
            $order_clause = { -desc => 'postdate' };
        }
    }

    my %order = (order_by => $order_clause);
    my $order_by = &doPagination(
        \%order, $errors,
        defined $criteria->{limit} ? $criteria->{limit} + 1 : undef,
        defined $criteria->{starting_after} ? $criteria->{starting_after} : undef
    );

    return $errors->getErrors if $errors->hasErrors;

    ### EXECUTE QUERY ###

    my $results;
    eval {
        $results = $db->select('transaction', undef, \%where, $order_by);
    };
    if($@ =~ /.*json\sDETAIL:\s*(\w+.*)\s.*/mg){
        $errors->addError(qq|Metadata JSON query failed with: $1|, '/meta');
    }

    return $errors->getErrors if $errors->hasErrors;

    #&debugQueryFromResults($results);

    my $include_lines = defined $criteria->{detail} && $criteria->{detail} eq 'false' ? 0 : 1;

    my @data = ( );
    while (my $transaction = $results->hash ){
        push @data, &__marshall_transaction_response($db, $transaction, $include_lines);
    }

    my $has_more = JSON::false;
    if(defined $data[$order_by->{limit}-1] ) {
        $has_more = JSON::true;
        pop(@data);
    }

    return {
        has_more => $has_more,
        data     => \@data
    };

}

=head2 PRIVATE METHODS

These methods are meant to be used internally by the Transaction module and are not exported.

=head3 __create_transaction

This method creates a transaction in the system.

B<This method consumes and returns the unmarshalled objects.>

=cut

sub __create_transaction($db, $data, $errors){

    my %new_transaction = ( );

    # make sure reference is unique
    if (defined $data->{reference}) {
        my $found = $db->select('transaction', undef, { reference => $data->{reference} })->hash;
        if (defined $found) {
            $errors->addError(qq|Reference provided is not unique: $data->{reference}|, '/reference');
        }
    }
    $new_transaction{reference} = $data->{reference};

    # metadata
    if (defined $data->{meta}) {
        eval {decode_json($data->{meta})};
        $errors->addError(qq|metadata is not valid JSON|, 'meta') if ($@);
    }
    $new_transaction{meta} = $data->{meta};

    # dataIn must be JSON (for transaction history)
    if ($data->{dataIn}) {
        eval {decode_json($data->{dataIn})};
        $errors->addError(qq|dataIn is not valid JSON|, 'dataIn') if ($@);
    }

    # transaction state and decision to post or not
    my $post_to_journal = 0;
    if ($data->{state_id}) {
        if (grep {/^$data->{state_id}$/}  ($STATUS_APPROVED, $STATUS_IN_PROGRESS, $STATUS_COMPLETE)) {
            $new_transaction{state_id} = $data->{state_id};
            $post_to_journal = 1;
        }
        elsif(grep {/^$data->{state_id}$/}  ($STATUS_CANCELED, $STATUS_REVERSED)){
            $errors->addError(qq|Transaction cannot be created in this state: $data->{state}|, '/state');
        }
    }
    # if not provided, assume draft
    else {
        $new_transaction{state_id} = $STATUS_DRAFT;
    }

    return $errors->getErrors if $errors->hasErrors;

    # optional fields
    $new_transaction{description} = $data->{description} if defined $data->{description};
    $new_transaction{postdate} = $data->{postdate} if defined $data->{postdate};
    $new_transaction{notes} = $data->{notes} if defined $data->{notes};
    $new_transaction{reverse_id} = $data->{reverse_id} if defined $data->{reverse_id};
    $new_transaction{entity_id} = $data->{entity_id} if defined $data->{entity_id};
    $new_transaction{linked_to} = $data->{linked_to} if defined $data->{linked_to};
    $new_transaction{group_ref} = $data->{group_ref} if defined $data->{group_ref};
    $new_transaction{group_typ} = $data->{group_typ} if defined $data->{group_typ};
    $new_transaction{group_sta} = $data->{group_sta} if defined $data->{group_sta};
    $new_transaction{amount} = $data->{amount} if defined $data->{amount};


    ### transaction lines and accounting logic

    my @new_transaction_lines = ();
    my $debit_total = 0;
    my $credit_total = 0;

    my $line_index = 1;
    foreach my $line (@{$data->{lines}}) {

        unless (defined $line->{account}) {
            $errors->addError(qq|No line account for line $line_index|, 'line: account');
            next;
        }

        # check to see if it's an acocunt or subaccount
        my $line_account;
        my $line_subacct = $db->select('subacct', undef, { account => $line->{account} })->hash;
        if (defined $line_subacct) {
            $line_account = $db->select('coa', undef, { id => $line_subacct->{coa_id} })->hash;
        }
        else {
            $line_account = $db->select('coa', undef, { account => $line->{account} })->hash;
        }

        unless (defined $line_account) {
            $errors->addError(qq|Invalid account [$line->{account}] for line $line_index|, 'line: account')
        }

        my %transaction_line = (
            subacct_id  => $line_subacct ? $line_subacct->{id} : undef,
            coa_id      => $line_account->{id},
            amount      => $line->{amount},
            entry       => $line->{entry},
        );
        # optional
        $transaction_line{reference} = $line->{reference} if defined $line->{reference};
        $transaction_line{description} = $line->{description} if defined $line->{description};
        $transaction_line{notes} = $line->{note} if defined $line->{note};

        if ($line->{entry} eq 'DEBIT') {
            $debit_total += $line->{amount};
        }
        else {
            $credit_total += $line->{amount};
        }
        push @new_transaction_lines, \%transaction_line;
        $line_index++;
    }

    if ($debit_total != $credit_total) {
        $errors->addError(qq|Credits do not equal debits.|, 'line')
    }

    ## cannot start transaction if errors up to this point
    return $errors->getErrors if $errors->hasErrors;

    ### NOTE: As of Pg 13 returning id does not work on partitioned tables
    ### https://dba.stackexchange.com/questions/58497/return-id-from-partitioned-table-in-postgres

    # insert the main transaction
    my $results;
    eval {
        #TODO: evaluate results further
        $results = $db->insert(transaction => \%new_transaction);
    };
    if($@){
        $errors->addError(qq|Error creating Transaction in System, code CT01 Please contact support.|, 'system');
        return $errors->getErrors;
    }
    my $id = $db->query(q|SELECT currval('transaction_id_seq'::regclass) AS id|)->hash->{id};
    unless ($id) {
        $errors->addError(qq|Error creating Transaction in System, code CT02 Please contact support.|, 'system');
        return $errors->getErrors;
    }

    my $new_transaction = $db->select('transaction', undef, { id => $id })->hash;

    ### insert the lines
    foreach my $line (@new_transaction_lines) {
        $line->{transaction_id} = $new_transaction->{id};
        my $results;
        eval {
            #TODO: evaluate results further
            $results = $db->insert(transaction_line => $line);
        };
        if($@){
            $errors->addError(qq|Error creating Transaction Line in System, code CT03. Please contact support.|, 'system');
            return $errors->getErrors;
        }
    }

    if ($post_to_journal) {
        $new_transaction = &__post_transaction_to_journal($db, $new_transaction, $errors);
    }

    __update_transaction_state_and_history($db, $new_transaction, $new_transaction->{state_id}, undef, undef, $errors);

    return $errors->getErrors if $errors->hasErrors;

    return $new_transaction;

}

=head3 __update_transaction_state_and_history

Updates transaction state according to

B<This method receives and returns the unmarshalled transaction objects.>

=cut


sub __update_transaction_state_and_history($db, $transaction, $new_state_id, $optional_data, $history_data, $errors){

    my %update_data = (
      state_id => $new_state_id
    );
    # merge optional data if present
    if(defined $optional_data && ref $optional_data eq 'HASH') {
        %update_data = (%update_data, %{$optional_data});
    }
    $db->update('transaction',  \%update_data, {id => $transaction->{id}});

    # add transaction history
    my %new_transaction_history = (
        transaction_id => $transaction->{id},
        state_from_id  => $transaction->{state_id},
        state_to_id    => $new_state_id,
    );
    # optional
    $new_transaction_history{data_in} = $history_data->{data_in} if defined $history_data->{data_in};
    $new_transaction_history{data_out} = $history_data->{data_in} if defined $history_data->{data_out};
    $new_transaction_history{notes} = $history_data->{notes} if defined $history_data->{notes};
    &__insert_transaction_history($db, \%new_transaction_history, $errors);
    return $errors->getErrors if $errors->hasErrors;

    # refresh and return
    return $db->select('transaction', undef, { id => $transaction->{id} })->hash;

}

=head3 __insert_transaction_history

Helper method to insert a transaction history record.

B<This method receives and returns the unmarshalled transaction objects.>

=cut

sub __insert_transaction_history($db, $record, $errors) {
    my $result; #TODO: further evaluate $result
    eval {
        $result = $db->insert(transaction_history => $record);
    };
    if($@){
        $errors->addError(qq|Error creating Transaction History in System. Please contact support.|, 'system');
        return undef;
    }
}


=head3 __post_transaction_to_journal

This method posts the transaction lines to the journal.

B<This method receives and returns the unmarshalled transaction objects.>

=cut


sub __post_transaction_to_journal($db, $transaction, $errors) {

    #my $db_fields_lines = $db->select('transaction_line', undef, { transaction_id => $transaction->{id} }, { order_by => 'id' });
    my $query = qq|
        select transaction_line.*
        from transaction_line left join balance_cache on balance_cache.unique_key = CONCAT(CONCAT(transaction_line.coa_id::text,':'),transaction_line.subacct_id::text)
        where transaction_line.transaction_id = $transaction->{id}
        order by balance_cache.id desc
        |;
    my $db_fields_lines = $db->query($query);
    while (my $line = $db_fields_lines->hash) {
        my %gl_entry = (
            postdate       => $transaction->{postdate},
            coa_id         => $line->{coa_id},
            subacct_id     => $line->{subacct_id} ? $line->{subacct_id} : undef,
            debit          => $line->{entry} eq 'DEBIT' ? $line->{amount} : 0,
            credit         => $line->{entry} eq 'CREDIT' ? $line->{amount} : 0,
            transaction_id => $transaction->{id},
        );
        &__insert_journal($db, $errors, \%gl_entry);
    }

    return $errors->getErrors if $errors->hasErrors;

    # refresh and return
    return $db->select('transaction', undef, { id => $transaction->{id} })->hash;

}

sub __insert_journal($db, $errors, $record) {
    $db->insert(journal => $record);
    my $id = $db->query(q|SELECT currval('journal_id_seq'::regclass) AS id|)->hash->{id};
    unless ($id) {
        $errors->addError(qq|Error creating Journal Entry in System. Please contact support.|, 'system');
        return 0;
    }
    my $q = $db->query(qq|select id from journal where id=$id|);
    if(!defined($q->hash)) {
        $errors->addError(qq|Error creating Journal Entry in System. Please contact support.|, 'system');
        return 0;
    }
    return $id;
}

sub __marshall_transaction_response($db, $transaction, $include_lines =  1) {

    my %mapped;
    # mandatory
    $mapped{transactionId} = $transaction->{txn_id} if defined $transaction->{txn_id};
    if(defined $transaction->{state_id}){
        $mapped{state} = $db->select('transaction_state', undef, { id => $transaction->{state_id} })->hash->{name};
    }
    $mapped{postDate} = $transaction->{postdate} if defined $transaction->{postdate};

    # optional
    $mapped{reference} = $transaction->{reference} if defined $transaction->{reference};
    $mapped{description} = $transaction->{description} if defined $transaction->{description};
    $mapped{linkedTo} = $transaction->{linked_to} if defined $transaction->{linked_to};
    $mapped{groupTyp} = $transaction->{group_typ} if defined $transaction->{group_typ};
    $mapped{groupRef} = $transaction->{group_ref} if defined $transaction->{group_ref};
    $mapped{groupSta} = $transaction->{group_sta} if defined $transaction->{group_sta};
    $mapped{amount} = toMoney($transaction->{amount}) if defined $transaction->{amount};
    $mapped{meta} = $transaction->{meta} if defined $transaction->{meta};
    $mapped{notes} = $transaction->{notes} if defined $transaction->{notes};
    if(defined $transaction->{entity_id} && $transaction->{entity_id} > 0){
        my $acct_num = $db->select('entity', undef, { id => $transaction->{entity_id} })->hash->{acct_num};
        $mapped{entity} = $acct_num;
    }

    return \%mapped unless $include_lines;

    my @lines = ();
    my $db_fields_lines = undef;
    if(defined $transaction->{id}){
        $db_fields_lines = $db->select('transaction_line', undef, { transaction_id => $transaction->{id} }, { order_by => 'id' });
    }

    return \%mapped unless defined $db_fields_lines;

    while (my $transaction_line = $db_fields_lines->hash) {
        my $account = $db->select('coa', undef, { id => $transaction_line->{coa_id} })->hash->{account};
        my $subaccount = $transaction_line->{subacct_id} ? $db->select('subacct', undef, { id => $transaction_line->{subacct_id} })->hash->{account} : undef;
        my %line = (
            account => $subaccount ? $subaccount : $account,
            amount  => &toMoney($transaction_line->{amount}),
            entry   => $transaction_line->{entry},
        );
        # optional
        $line{reference} = $transaction_line->{reference} if defined $transaction_line->{reference};
        $line{description} = $transaction_line->{description} if defined $transaction_line->{description};
        $line{notes} = $transaction_line->{note} if defined $transaction_line->{note};
        push @lines, \%line;
    }
    $mapped{lines} = \@lines;

    return \%mapped;

}

sub __unmarshall_transaction($db, $marshalled, $errors) {

    my %unmarshalled;

    $unmarshalled{txn_id} = $marshalled->{transactionId} if defined $marshalled->{transactionId};
    if(defined $marshalled->{state}){
        my $state = $db->select('transaction_state', undef, { name => $marshalled->{state} })->hash;
        if(defined $state){
            $unmarshalled{state_id} = $state->{id}
        }
        else{
            $errors->addError(qq|Invalid state: $marshalled->{state}|, '/state');
        }

    }
    if(defined $marshalled->{entity}){
        my $entity = &get_entity_by_account_or_ref($db, $marshalled->{entity});
        if(defined $entity){
            $unmarshalled{entity_id} = $entity->{id};
        }
        else{
            $errors->addError(qq|Entity not found: $marshalled->{entity}|, '/entity');
        }
    }

    return $errors->getErrors if $errors->hasErrors;

    $unmarshalled{postdate} = $marshalled->{postDate} if defined $marshalled->{postDate};
    $unmarshalled{reference} = $marshalled->{reference} if defined $marshalled->{reference};
    $unmarshalled{description} = $marshalled->{description} if defined $marshalled->{description};
    $unmarshalled{linked_to} = $marshalled->{linkedTo} if defined $marshalled->{linkedTo};
    $unmarshalled{group_typ} = $marshalled->{groupTyp} if defined $marshalled->{groupTyp};
    $unmarshalled{group_ref} = $marshalled->{groupRef} if defined $marshalled->{groupRef};
    $unmarshalled{group_sta} = $marshalled->{groupSta} if defined $marshalled->{groupSta};
    $unmarshalled{amount} = $marshalled->{amount} if defined $marshalled->{amount};
    $unmarshalled{meta} = $marshalled->{meta} if defined $marshalled->{meta};
    $unmarshalled{notes} = $marshalled->{notes} if defined $marshalled->{notes};


    # marshalled/unmarshalled lines are the same
    if(defined $marshalled->{lines} && ref $marshalled->{lines} eq 'ARRAY'){
        $unmarshalled{lines} = $marshalled->{lines};
    }

    return \%unmarshalled

}

1;