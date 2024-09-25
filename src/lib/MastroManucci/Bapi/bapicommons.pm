package MastroManucci::Bapi::bapicommons;
use strict;
use warnings FATAL => 'all';
use Const::Fast;

use Exporter qw( import );
use Const::Fast;

our @EXPORT = qw(
    $CUST_TXN_REVN
    $CUST_ACCRU_AR
    $AR_ACCOUNT
    $REVENUE_ACCT
);
our @EXPORT_OK = qw( );

# account suffixes

# revenue and ar
const our $CUST_TXN_REVN => '010';
const our $CUST_ACCRU_AR => '030';

# Customer accounts
const our $AR_ACCOUNT   => '1.2.1.1';
const our $REVENUE_ACCT => '4.1.2.10';


1;
