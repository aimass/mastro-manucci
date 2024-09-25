package MastroManucci::Model::Commons;

use strict;
use warnings FATAL => 'all';
no warnings qw(experimental);
use experimental qw(signatures);
use Exporter qw(import);


our @EXPORT = qw(
    doPagination
    debugQueryFromResults
    debugCaller
    cleanupCriteria
);
our @EXPORT_OK = qw();

#TODO: 5.35 does not support //= so these defaults are useless :-( leaving for 5.36
sub doPagination($order, $errors, $limit, $offset){
    if(defined $limit && ($limit > 1001 || $limit < 1)) {
        $errors->addError(qq|Limit must be between 1 and 1001.|, 'system');
    } elsif(!defined($limit)) {
        $limit = 11;
    }
    if(defined $offset && $offset < 0) {
        $errors->addError(qq|Starting_after must be greater than or equal to 0.|, 'system');
    }elsif(!defined($offset)){
        $offset = 0;
    }
    return undef if $errors->hasErrors;
    $order->{limit} = $limit;
    $order->{offset} = $offset;
    return $order
}

# cleans up query criteria that comes without a value (e.g. from forms)
sub cleanupCriteria ($criteria) {
    return undef unless ref $criteria eq 'HASH';
    my %clean = ( );
    for my $key (keys %{$criteria}){
        $clean{$key} = $criteria->{$key} if $criteria->{$key};
    }
    return \%clean;
}

sub debugQueryFromResults($results){
    print "\n**** QUERY:\n".$results->sth->{Statement};
    print "\nPARAMS: ".join(", ", map {$results->sth->{ParamValues}->{$_}} sort keys %{$results->sth->{ParamValues}})."\n\n";
}

# to quickly debug callers
# my ($package, $filename, $line) = caller;
# warn "**** CALLED BY: $package, $filename, $line";




1;