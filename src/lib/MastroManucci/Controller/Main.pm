package MastroManucci::Controller::Main;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use MastroManucci::Model::LedgerCommons;

no warnings qw(experimental);

sub getBuild ($self){
  return unless($self->openapi->valid_input);
  #setMdc($self);
  my $response;
  $response->{version} = MastroManucci::BUILD_VERSION;
  $response->{revision} = MastroManucci::BUILD_REVISION;
  $response->{built} = MastroManucci::BUILD_TIMESTAMP;
  $response->{project} = MastroManucci::BUILD_PROJECT;
  my $status = defined $response->{errors} ? (defined $response->{code} ? $response->{code} : 400) : 200;
  $self->defaultResponse($response,$status)
}

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

sub postEntity ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->postEntity($self);
  my $status = defined $response->{errors} ? 400 : 201;
  $self->defaultResponse($response,$status)
}

sub postSubacct ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->postSubacct($self);
  my $status = defined $response->{errors} ? 400 : 201;
  $self->defaultResponse($response,$status)
}

sub postTransaction ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->postTransaction($self);
  my $status = defined $response->{errors} ? 400 : 201;
  $self->defaultResponse($response,$status)
}

sub putTransaction ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->putTransaction($self);
  my $status = defined $response->{errors} ? (defined $response->{code} ? $response->{code} : 400) : 200;
  $self->defaultResponse($response,$status)
}

sub getTransactions ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->getTransactions($self);
  if(ref $response eq 'ARRAY'){
    $self->defaultResponse($response,200)
  }
  else {
    my $status = defined $response->{errors} ? (defined $response->{code} ? $response->{code} : 404) : 200;
    $self->defaultResponse($response, $status);
  }
}

sub getTransaction ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->getTransaction($self);
  my $status = defined $response->{errors} ? (defined $response->{code} ? $response->{code} : 400) : 200;
  $self->defaultResponse($response,$status)
}


sub getBalance ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->getBalance($self);
  my $status = defined $response->{errors} ? 401 : 200;
  $self->defaultResponse($response,$status)
}

sub getBalanceCheck ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->getBalanceCheck($self);
  my $status = defined $response->{errors} ? 401 : 200;
  $self->defaultResponse($response,$status)
}

sub getJournal ($self){
  return unless($self->openapi->valid_input);
  my $response = $self->ledger->getJournal($self);
  if(ref $response eq 'ARRAY'){
    $self->defaultResponse($response,200)
  }
  else {
    my $status = defined $response->{errors} ? (defined $response->{code} ? $response->{code} : 404) : 200;
    $self->defaultResponse($response, $status);
  }
}


sub defaultResponse($self,$response,$status){
  #FIXME: Location and other headers ?
  $self->respond_to(
    json => sub{$self->render(openapi => $response, status => $status)},
    html => {html => undef}
  );
}

1;
