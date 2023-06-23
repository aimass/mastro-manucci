package MastroManucci::Controller::Main;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use MastroManucci::Controller::TransactionResponse;
use MastroManucci::Model::Util;

no warnings qw(experimental);
use feature 'switch';

sub postCOA ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->admin->postCOA($self);
  my $status = defined $response->{errors} ? 400 : 201;
  $self->defaultResponse($response,$status)
}

sub getCOA ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->admin->getCOA($self);
  my $status = defined $response->{errors} ? 404 : 200;
  $self->defaultResponse($response,$status)
}

sub deleteCOA ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->admin->deleteCOA($self);
  my $status = 204;
  if(defined $response->{errors}){
    if(&isMessageInErrors($response->{errors},'not found')){
      $status = 404;
    }
    else {
      $status = 400;
    }
  }

  $self->defaultResponse($response,$status)
}


sub postBook ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->postSubaccount($self);
  my $status = defined $response->{errors} ? 400 : 201;
  $self->defaultResponse($response,$status)
}

sub postTransaction ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->postTransaction($self);
  my $status = defined $response->{errors} ? 400 : 201;
  $self->defaultResponse($response,$status)
}

sub postInvoice ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->postInvoice($self);
  my $status = defined $response->{errors} ? (defined $response->{code} ? $response->{code} : 400) : 201;
  $self->defaultResponse($response,$status)
}

sub defaultResponse($self,$response,$status){
  #FIXME: Location and other headers ?
  $self->respond_to(
    json => sub{$self->render(openapi => $response, status => $status)},
    html => {html => undef}
  );
}

1;
