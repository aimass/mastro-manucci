package MastroManucci::Controller::Bapi;

use Mojo::Base 'Mojolicious::Controller', -signatures;

no warnings qw(experimental);

sub postBapi ($self) {
    my $errors = MastroManucci::Model::Error->new();
    return unless($self->openapi->valid_input);

    my $response = { };
    my $bapi = $self->__load_bapi($self->param('name'), $errors);

    if (defined $bapi) {
        $response = $bapi->post($self,$errors);
    }
    else{
        $response = $errors->getErrors;
    }

    my $status = defined $response->{errors} ? 400 : 200;
    $self->defaultResponse($response,$status)
}

sub getBapi ($self) {
    my $errors = MastroManucci::Model::Error->new();
    return unless($self->openapi->valid_input);

    my $response = { };
    my $bapi = $self->__load_bapi($self->param('name'), $errors);

    if (defined $bapi) {
        $response = $bapi->get($self,$errors);
    }
    else{
        $response = $errors->getErrors;
    }

    my $status = defined $response->{errors} ? 400 : 200;
    $self->defaultResponse($response,$status)
}

sub __load_bapi ($self, $bapi_name, $errors) {
    $bapi_name = 'MastroManucci::Bapi::'.$bapi_name;
    eval "require $bapi_name";
    if( $@ ){
        $self->app->log->error("Error loading BAPI: $@");
        $errors->addError("Cannot load BAPI $bapi_name : $@", 'name');
    }
    my $bapi = $bapi_name->new();
    return $bapi  if defined $bapi_name;
    return undef;
}

sub defaultResponse($self,$response,$status){
    #FIXME: Location and other headers ?
    $self->respond_to(
        json => sub{$self->render(openapi => $response, status => $status)},
        html => {html => undef}
    );
}


1;