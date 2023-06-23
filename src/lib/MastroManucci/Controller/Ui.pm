package MastroManucci::Controller::Ui;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
    my @menu = (
        {
            text => 'Chart of Accounts',
            link => '/coa'
            },
        {
            text => 'Account Balances',
            link => '/accbal'
        }
    );
    $self->respond_to(
        html => { menu => \@menu }
    );
}

1;