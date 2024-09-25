package MastroManucci::Model::LedgerCommons;

use strict;
use warnings FATAL => 'all';

use Scalar::Util qw(looks_like_number);
use Const::Fast;
use Exporter qw(import);

our @EXPORT = qw(
    $STATUS_DRAFT
    $STATUS_APPROVED
    $STATUS_IN_PROGRESS
    $STATUS_COMPLETE
    $STATUS_CANCELED
    $STATUS_REVERSED
    $STATUS_DRAFT_STR
    $STATUS_APPROVED_STR
    $STATUS_IN_PROGRESS_STR
    $STATUS_COMPLETE_STR
    $STATUS_CANCELED_STR
    $STATUS_REVERSED_STR

    getDRCR
    dateFromTS
    toMoney
    toCents
    toMoneyString
    equal
    isMessageInErrors
    getQueryParams
    get_entity_by_account_or_ref
);
our @EXPORT_OK = qw();

const our $STATUS_DRAFT       => 1;
const our $STATUS_APPROVED    => 2;
const our $STATUS_IN_PROGRESS => 3;
const our $STATUS_COMPLETE    => 4;
const our $STATUS_CANCELED    => 5;
const our $STATUS_REVERSED    => 6;

const our $STATUS_DRAFT_STR       => 'DRAFT';
const our $STATUS_APPROVED_STR    => 'APPROVED';
const our $STATUS_IN_PROGRESS_STR => 'IN_PROGRESS';
const our $STATUS_COMPLETE_STR    => 'COMPLETE';
const our $STATUS_CANCELED_STR    => 'CANCELED';
const our $STATUS_REVERSED_STR    => 'REVERSED';

sub getDRCR {
    my $type = shift;
    my %drcr = (
        ASSET     => 'DR',
        LIABILITY => 'CR',
        EQUITY    => 'DR',
        INCOME    => 'CR',
        EXPENSE   => 'DR',
    );
    return $drcr{$type};
}

sub dateFromTS {
    my $date = shift;
    $date =~ /(\d+)-(\d+)-(\d+)/;
    return "$1-$2-$3";
}

sub toMoney {
    my $amount = shift;
    return (&toMoneyString($amount)) * 1;
}

sub toCents {
    my $amount = shift;
    return (&toMoneyString($amount)) * 100;
}

sub toMoneyString {
    my $amount = shift;
    return sprintf('%.2f', $amount);
}

sub equal {
    my ($A, $B, $dp) = @_;
    return sprintf("%.${dp}g", $A) eq sprintf("%.${dp}g", $B);
}

sub isMessageInErrors {
    my $errors = shift;
    my $message = shift;
    foreach my $error (@$errors){
        return 1 if $error->{message} =~ /$message/ig;
    }
    return 0;
}

sub getQueryParams {
    my $app = shift; #TODO: validate mojo controller
    my $wanted = shift;

    my $data = $app->req->json;
    my %result = ( );
    if(ref $wanted eq 'ARRAY' && scalar(@{$wanted}) > 0){
        foreach my $param (@{$wanted}) {
            # check query param first
            if(defined $app->param($param)){
                $result{$param} = $app->param($param);
            }
            # body param overrides query param
            if(defined $data->{$param}){
                $result{$param} = $data->{$param};
            }
        }
    }
    return \%result;
}

sub get_entity_by_account_or_ref {
    my $db = shift;
    my $entityString = shift;

    my $entity = undef;

    if(looks_like_number($entityString)){
        $entity = $db->select('entity', undef, { acct_num => $entityString })->hash;
    }
    unless(defined $entity){
        $entity = $db->select('entity', undef, { reference => $entityString })->hash;
    }
    return $entity;
}


__PACKAGE__;
__END__
