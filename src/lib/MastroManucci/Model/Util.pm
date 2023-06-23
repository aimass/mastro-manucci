package MastroManucci::Model::Util;
use strict;
use warnings;
no warnings qw(experimental);
use experimental qw(signatures);

require Exporter;
our @ISA = qw(Exporter);
our $VERSION = 0.01;
our @EXPORT_OK = ( );
our @EXPORT = qw( dateFromTS getDRCR isMessageInErrors);

sub getDRCR($type){
  my %drcr = (
    ASSET     => 'DR',
    LIABILITY => 'CR',
    EQUITY    => 'DR',
    INCOME    => 'CR',
    EXPENSE   => 'DR',
  );
  return $drcr{$type};
}

sub dateFromTS($date){
  $date =~ /(\d+)-(\d+)-(\d+)/;
  return "$1-$2-$3";
}

sub isMessageInErrors($errors,$message){
  foreach my $error (@$errors){
    return 1 if $error->{message} =~ /$message/ig;
  }
  return 0;
}

1;