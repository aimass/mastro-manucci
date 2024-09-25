package MastroManucci::Model::Ledger::Journal;
use strict;
use warnings FATAL => 'all';

use experimental qw(signatures);
use MastroManucci::Model::Commons;
use MastroManucci::Model::LedgerCommons;

use Exporter qw(import);

our @EXPORT = qw(
    queryJournal
);
our @EXPORT_OK = qw();

sub queryJournal($db, $criteria, $errors){

    $criteria = &cleanupCriteria($criteria);
    my %where = ( );

    ### ACCOUNT ###

    if ($criteria->{account}){
        my $account = $db->select('coa', undef, { account => $criteria->{account} })->hash;
        if (defined $account) {
            $where{coa_id} = $account->{id};
        }
        else{
            $errors->addError(qq|Account not found: $criteria->{account}|, '/account');
        }
    }

    ### SUBACCOUNT ###

    if ($criteria->{subaccount}){
        my $subaccount = $db->select('subacct', undef, { account => $criteria->{subaccount} })->hash;
        if (defined $subaccount) {
            $where{subacct_id} = $subaccount->{id};
        }
        else{
            $errors->addError(qq|Subaccount not found: $criteria->{subaccount}|, '/subaccount');
        }
    }

    ### TRANSACTION ###

    if ($criteria->{transactionId}){
        my $transaction = $db->select('transaction', undef, { txn_id => $criteria->{transactionId} })->hash;
        if (defined $transaction) {
            $where{transaction_id} = $transaction->{id};
        }
        else{
            $errors->addError(qq|Transaction not found: $criteria->{transactionId}|, '/transactionId');
        }
    }

    ### DATES ###

    $where{postdate} = { '>=', $criteria->{from_date} } if $criteria->{from_date};
    if ($criteria->{to_date}) {
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

    ### PRELIMINARY COUNT BEFORE PAGINATION ###

    my $count = $db->select('journal', 'count(*)', \%where)->hash->{count} || 0;


    ### ORDER AND PAGINATION ###

    my $order_clause = undef;
    $criteria->{order} = 'oldest_first' unless $criteria->{order};
    $criteria->{order_by} = 'postdate' unless $criteria->{order_by};
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
        $criteria->{limit} ? $criteria->{limit} + 1 : undef,
        $criteria->{starting_after} ? $criteria->{starting_after} : undef,
    );

    return $errors->getErrors if $errors->hasErrors;

    ### EXECUTE QUERY ###

    my $results = $db->select('journal', undef, \%where, $order_by);
    #&debugQueryFromResults($results);

    my @data = ( );
    while (my $entry = $results->hash ){
        push @data, &mapJournalLine($db, $entry);
    }

    my $has_more = JSON::false;
    if(defined $data[$order_by->{limit}-1] ) {
        $has_more = JSON::true;
        pop(@data);
    }


    my $offset = $order{offset};
    # note the -1 is because we added 1 in doPagination above
    my $starting_after = $has_more ? $order{offset} + $order{limit} - 1 : 0;
    warn "THIS ROW: $offset, NEXT_ROW: $starting_after, HAS_MORE: $has_more";
    return {
        has_more       => $has_more,
        offset         => $offset,
        starting_after => $starting_after,
        total_rows     => $count,
        data           => \@data,
        criteria       => $criteria,
    };

}

sub mapJournalLine($db, $entry) {

    my %mapped;

    $mapped{postdate} = $entry->{postdate};
    $mapped{debit} = &toMoney($entry->{debit});
    $mapped{credit} = &toMoney($entry->{credit});

    my $account = $db->select('coa', undef, { id => $entry->{coa_id} })->hash;
    $mapped{account} = $account->{account};
    $mapped{acctdesc} = $account->{description};

    if(defined $entry->{subacct_id} && $entry->{subacct_id} > 0){
        my $subacct = $db->select('subacct', undef, { id => $entry->{subacct_id} })->hash;
        $mapped{subaccount} = $subacct->{account};
        $mapped{subaccountdesc} = $subacct->{description};
    }

    if(defined $entry->{transaction_id} && $entry->{transaction_id} > 0){
        my $transaction = $db->select('transaction', undef, { id => $entry->{transaction_id} })->hash;
        $mapped{transactionId} = $transaction->{txn_id};
    }

    return \%mapped;

}

1;