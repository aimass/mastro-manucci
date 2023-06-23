package MastroManucci;
use Mojo::Base 'Mojolicious', -signatures;
use Mojo::Pg;
use MastroManucci::Model::Admin;
use MastroManucci::Model::Ledger;

sub startup ($self) {

  my $the_secret = <<'THE_SECRET';

The murder of their beloved ones shall they see
and over supplication unto eternity,
but mercy and peace shall ye not attain

THE_SECRET

  my $dsn = qq|dbi:Pg:dbname=$ENV{PGDATABASE};host=$ENV{PGHOST};port=$ENV{PGPORT};|;

  $self->secrets([$the_secret]);
  $self->plugin('DefaultHelpers');
  $self->plugin( OpenAPI => { url => $self->home->rel_file('openapi/openapi.yaml') } );
  $self->plugin(
    SwaggerUI => {
      route   => $self->routes()->any('api'),
      url     => "/api",
      title   => "Mastro Manucci Ledger",
      #favicon => "TODO"
    }
  );
  $self->plugin('NotYAMLConfig');
  $self->helper(admin => sub { state $admin = MastroManucci::Model::Admin->new });
  $self->helper(ledger => sub { state $ledger = MastroManucci::Model::Ledger->new });
  $self->helper(pg => sub { state $pg = Mojo::Pg->new->dsn($dsn)});
  $self->pg->username($ENV{POSTGRES_DB_USERNAME});
  $self->pg->password($ENV{POSTGRES_DB_PASSWORD});
  $self->renderer->default_format('json');

  $self->routes->get('/ui')->to('ui#index');

  my $r = $self->routes;

}

1;
