package MastroManucci::Model::Error;

use strict;
use warnings;
no warnings qw(experimental);
use experimental qw(signatures);

# This class constructs errors in the same fashion that the OpenAPI Plugin does:
# Example: '{"errors":[{"message":"Missing property.","path":"\/body\/errors\/0\/message"}],"status":500}'

sub new ($class) {
  my $self = {
    errors => [],
  };
  bless $self, $class;
}

sub addError($self, $message, $path){
  $message = defined $message ? $message : 'none';
  $path = defined $path ? $path : 'none';
  push @{$self->{errors}}, {message => $message, path => $path};
}

sub setCode($self, $code){
  $self->{code} = $code;
}

sub hasErrors($self){
  return 1 if scalar @{$self->{errors}};
  return 0;
}

sub getErrors($self){
  return {
    errors => $self->{errors},
  }
}





1;