package MastroManucci::Model::Ledger::Balance;
use strict;
use warnings FATAL => 'all';
use experimental qw(signatures);
use MastroManucci::Model::LedgerCommons;

use Exporter qw(import);

our @EXPORT = qw(
    calculateBalance
    balanceCheck
);
our @EXPORT_OK = qw();

# Without parameters returns all accounts that have movement
# Summary: /balance
#          balance + account
#          balance + accout AND (entity OR subaccount)
#
# If an account is defined it will filter by account
# you can further filter by all subaccounts that belong to an entity
# OR you can filter a specific subaccount
# Both options (filter by entity and subaccount) require an account first
# By passing all == 1 you also get accounts that have had no movements

#FUTURE: this is a good candidate to move to DB either partially or wholly
sub calculateBalance ($db, $criteria, $errors) {

    my $account_id = undef;
    my $entity_id = undef;
    my $subacct_id = undef;
    my $all = undef;
    my $to_postdate = $criteria->{to_date} || undef;
    my $to_created = $criteria->{to_datec} || undef;

    my $include_subacct = defined $criteria->{inc_subaccount} ? 1 : 0;
    my $include_entity = defined $criteria->{inc_entity} ? 1 : 0;

    if($criteria->{account}){
        my $account = $db->select('coa', undef, { account => $criteria->{account} })->hash;
        if (defined $account) {
            $account_id = $account->{id};
        }
        else {
            $errors->addError(qq|Account $criteria->{account} not found |, 'account');
        }

    }
    if($criteria->{entity}) {
        $include_subacct = 1;
        my $entity = &get_entity_by_account_or_ref($db,$criteria->{entity});
        if(defined $entity){
            $entity_id = $entity->{id};
        }
        else{
            $errors->addError(qq|Entity $criteria->{entity} not found |, 'entity');
        }
    }
    if($criteria->{subaccount}) {
        $include_subacct = 1;
        my $subacct = $db->select('subacct', undef, { account => $criteria->{subaccount} })->hash;
        if (defined $subacct) {
            $subacct_id = $subacct->{id};
        }
        else {
            $errors->addError(qq|Subaccount $criteria->{subaccount} not found |, 'subacct');
        }
    }
    if(defined $criteria->{all} && ($criteria->{all} eq 'true' || $criteria->{all} == 1)) {
        $all = 1;
    }

    # additional switch rules and logic

    # entity and subacct are EITHER OR; subacct wins
    if (defined $entity_id && defined $subacct_id) {
        $entity_id = undef;
    }

    # account and subacct are EITHER OR; subacct wins
    if (defined $account_id && defined $subacct_id) {
        $account_id = undef;
    }

    # including subacct info is implied if entity is included
    $include_subacct = undef if $include_entity;

    return $errors->getErrors if (defined $errors && $errors->hasErrors);

    my $where = 'WHERE 1=1 ';

    # filter by account
    if(defined $account_id){
        $where .= qq| AND coa.id = $account_id | ;
    }

    # filter by EITHER sub-accounts belonging to a given entity...
    if(defined $entity_id){
        my $res;
        if(defined( $account_id)){
            $res = $db->select('subacct', undef, { entity_id => $entity_id, coa_id => $account_id });
        }
        else{
            $res = $db->select('subacct', undef, { entity_id => $entity_id });
        }
        my $in_clause = '';
        while(my $subacct = $res->hash){
            $in_clause .= qq|$subacct->{id},|;
        }
        chop $in_clause;
        $where .= qq| AND subacct.id IN ($in_clause) |;
    }
    # ... OR filter by a single sub-account id
    elsif(defined $subacct_id){
        $where .= qq| AND subacct.id = $subacct_id |;
    }

    # where for zero balance accounts stops here
    my $wherez = $where;

    my $use_balance_cache = (defined ($criteria->{no_cache}) ||
                             !defined($criteria->{subaccount}) ||
                             $criteria->{subaccount}!~/\.090\Z/ ||
                             !defined($criteria->{use_balance_cache}) ||
                             lc($criteria->{use_balance_cache}) ne 'true') ? 0 : 1;
    if(defined $to_postdate){
        $where .= qq| AND journal.postdate <= '$to_postdate' |;
        $use_balance_cache = 0;
    }

    if(defined $to_created){
        $where .= qq| AND journal.created <= '$to_created' |;
        $use_balance_cache = 0;
    }

    my $query;

    unless($use_balance_cache) {
        # only accounts with balances/movements
        if($include_entity){
            $query = qq|
        select coa.account as account, coa.drcr, coa.description as acctdesc, subacct.account as subacct,
        subacct.description as subacctdesc, entity.acct_num as entity, entity.name entity_name,
        entity.reference as entity_ref, sum(debit) as debits, sum(credit) as credits
        from journal join coa on journal.coa_id = coa.id left outer join subacct on subacct_id = subacct.id
        left outer join entity on subacct.entity_id = entity.id $where
        group by coa.account, coa.drcr, coa.description, subacct.account, subacct.description,
        entity, entity_name, entity_ref
        order by account, subacct
        |;
        }
        elsif($include_subacct) {
            $query = qq|
        select coa.account as account, coa.drcr, coa.description as acctdesc, subacct.account as subacct,
        subacct.description as subacctdesc, sum(debit) as debits, sum(credit) as credits
        from journal join coa on journal.coa_id = coa.id left outer join subacct on subacct_id = subacct.id $where
        group by coa.account, coa.drcr, coa.description, subacct.account, subacct.description
        order by account, subacct
        |;
        }
        else {
            $query = qq|
        select coa.account as account, coa.drcr, coa.description as acctdesc, sum(debit) as debits, sum(credit) as credits
        from journal join coa on journal.coa_id = coa.id $where
        group by coa.account, coa.drcr, coa.description
        order by coa.account
        |;
        }
    }
    else {
            $query = qq|
        select coa.account as account, coa.drcr, coa.description as acctdesc, subacct.account as subacct,
        subacct.description as subacctdesc, balance_cache.total_debits as debits, balance_cache.total_credits as credits
        from balance_cache join coa on balance_cache.coa_id = coa.id join subacct on subacct_id = subacct.id $where
        order by account, subacct
        |;
    }

    my @accounts = ( );
    my $total_debit = 0;
    my $total_credit = 0;

    my $balance_accounts = $db->query($query);
    while (my $row = $balance_accounts->hash) {
        my $act = {
            account     => $row->{account},
            accountDesc => $row->{acctdesc},
        };
        if($include_subacct || $include_entity) {
            $act->{subaccount} = $row->{subacct};
            $act->{subaccountDesc} = $row->{subacctdesc};
        }
        if($include_entity){
            $act->{entity} = $row->{entity};
            $act->{entityName} = $row->{entity_name};
            $act->{entityRef} = $row->{entity_ref};
        }
        my $balance;
        if ($row->{drcr} eq 'DR') {
            $balance = $row->{debits} - $row->{credits};
        }
        else {
            $balance = $row->{credits} - $row->{debits};
        }
        $act->{debits} =  &toMoney($row->{debits});
        $act->{credits} = &toMoney($row->{credits});
        $act->{balance} = &toMoney($balance);
        push @accounts, $act;
        $total_debit += $row->{debits};
        $total_credit += $row->{credits};
    }



    # this appends all the sub-accounts that don't have any movements
    if ($all) {
        # select all accounts with almost identical query
        my $q;
        if($include_entity){
            $q = qq|
            select coa.account as account, coa.drcr, coa.description as acctdesc,
            subacct.account as subacct, subacct.description as subacctdesc,
            entity.acct_num as entity, entity.name entity_name,
            entity.reference as entity_ref
            from subacct left outer join coa on subacct.coa_id = coa.id
            left outer join entity on subacct.entity_id = entity.id $wherez
            order by coa.account;
            |;
        }
        elsif($include_subacct) {
            $q = qq|
            select coa.account as account, coa.drcr, coa.description as acctdesc,
            subacct.account as subacct, subacct.description as subacctdesc
            from subacct left outer join coa on subacct.coa_id = coa.id $wherez
            order by coa.account;
            |;
        }
        else{
            $q = qq|
            select coa.account as account, coa.drcr, coa.description as acctdesc
            from coa $wherez and heading is false order by coa.account;
            |;
        }

        #TODO: add heading accounts as a separate option, or always ?
        my $all_accounts = $db->query($q);
        while (my $row = $all_accounts->hash) {
            my $found = 0;
            foreach my $account (@accounts) {
                # account
                if (!defined $account->{subaccount} && $account->{account} eq $row->{account}) {
                    $found = 1;
                }
                # is subacct
                elsif($account->{account} eq $row->{account} && $account->{subaccount} eq $row->{subacct}) {
                    $found = 1;
                }
            }
            # append zero movement account or subaccount to balance
            my $act = {
                account     => $row->{account},
                accountDesc => $row->{acctdesc},
                debits      => 0,
                credits     => 0,
                balance     => 0,
            };
            if($include_subacct || $include_entity) {
                $act->{subaccount} = $row->{subacct};
                $act->{subaccountDesc} = $row->{subacctdesc};
            }
            if($include_entity){
                $act->{entity} = $row->{entity};
                $act->{entityName} = $row->{entity_name};
                $act->{entityRef} = $row->{entity_ref};
            }
            push @accounts, $act unless $found;
        }
    }

    @accounts = sort {
        $a->{account} cmp $b->{account};
    } @accounts;

    return {
        accounts    => \@accounts,
        totalDebit  => &toMoney($total_debit),
        totalCredit => &toMoney($total_credit),
        filter      => $criteria,
    };

}


sub balanceCheck($db, $criteria, $errors) {

    my $what;
    if($criteria->{method}){
        if(uc($criteria->{method}) eq 'OK'){
            $what = { balance_check => 'OK' };
        }
        elsif(uc($criteria->{method}) eq 'NOK'){
            $what = { balance_check => 'NOK' };
        }
        elsif(uc($criteria->{method}) eq 'ALL'){
            $what= {  };
        }
        else{
            $errors->addError(qq|Invalid balance check criteria: $criteria->{method} |, 'method');
            return $errors->getErrors;
        }
    }

    my @accounts = @{$db->select('balance_check', undef, $what)->hashes->to_array};

    my $idx = 0;
    foreach my $account (@accounts){
        $accounts[$idx]->{subacct} = '' unless defined $account->{subacct};
        $accounts[$idx]->{subacctdesc} = '' unless defined $account->{subacctdesc};
        $idx++;
    }

    return {
        accounts => \@accounts
    }

}

1;