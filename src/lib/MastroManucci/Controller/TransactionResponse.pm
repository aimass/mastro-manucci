package MastroManucci::Controller::TransactionResponse;

use strict;
use warnings;
no warnings qw(experimental);
use experimental qw(signatures);
use feature 'switch';

require Exporter;
our @ISA = qw(Exporter);
our $VERSION = '0.01';
our @EXPORT_OK = ( );
our @EXPORT = qw( mapTransactionResponse );

sub mapTransactionResponse($headerInfo, $rows) {
    my %transactionResponse = (
        uuid => $headerInfo->{uuid},
        startDate => $headerInfo->{from} || '',
        endDate => $headerInfo->{to} || '',
    );
    my @mappedRows = ( );
    foreach my $row (@{$rows}){
        my $txnType = &mapTxnType($row->{req_message_type_code});
        my $status = &mapStatus($row->{tenant_total_amount_approved},$row->{transaction_amount});
        my %mappedRow = (
            txnDate  => $row->{created},
            txnCode  => $row->{req_message_type_code},
            txnType  => $txnType,
            cardId   => $row->{card},
            status   => $status,
            merchant => $row->{merchant_name},
            amount   => $row->{transaction_amount},
            amountApproved => $row->{tenant_total_amount_approved},
            authCode => $row->{req_auth_code},
        );
        push @mappedRows, \%mappedRow;
    }
    $transactionResponse{data} = \@mappedRows;
    return \%transactionResponse;
}

sub mapTxnType($mtc){
    given($mtc){
        when(1100..1199) { return 'approval' }
        when(1200..1299) { return 'settlement'; }
        when(1400..1499) { return 'reversal'; }
        default { return 'unknown'; }
    }
}

sub mapStatus($approved,$requested){
    given($approved){
        when(undef) { return 'DECLINED'}
        when($approved < $requested) { return 'PARTIAL'}
        when($approved >= $requested) { return 'APPROVED'}
    }
}

1;