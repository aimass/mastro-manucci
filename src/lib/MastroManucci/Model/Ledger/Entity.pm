package MastroManucci::Model::Ledger::Entity;
use strict;
use warnings FATAL => 'all';
use experimental qw(signatures);
use MastroManucci::Model::LedgerCommons;
use JSON;

use Exporter qw(import);

our @EXPORT = qw(
    createEntity
    mapEntityResponse
);
our @EXPORT_OK = qw();


sub createEntity ($db, $data, $errors){

    ### validations

    my $subtype = $db->select('entity_subtype', undef, { name => $data->{subtype} })->hash;
    $errors->addError("Subtype does not exist in DB", 'subtype:' . $data->{subtype}) unless $subtype;

    if ($data->{meta}) {
        eval {decode_json($data->{meta})};
        $errors->addError(qq|meta is not valid JSON: $@|, 'meta') if ($@);
    }

    my %new_entity = (
        name              => $data->{name},
        reference         => $data->{reference},
        type              => $data->{type},
        entity_subtype_id => $subtype->{id},
        notes             => $data->{notes}
    );

    my $entity = $db->select('entity', undef, [ { name => $new_entity{name} }, { reference => $new_entity{reference} } ])->hash;
    $errors->addError("Entity with same name of reference already exists", 'name:' . $data->{name}) if $entity;

    return $errors->getErrors if $errors->hasErrors;

    $new_entity{meta} = $data->{meta} if $data->{meta};

    # insert the entity and re-fetch
    my $id = $db->insert(entity => \%new_entity, { returning => 'id' })->hash->{id};
    return $db->select('entity', undef, { id => $id })->hash;

}

sub mapEntityResponse($entity, $subtype) {

    my %mapped = (
        accountNumber => $entity->{acct_num},
        name          => $entity->{name},
        reference     => $entity->{reference},
        type          => $entity->{type},
    );
    $mapped{meta} = $entity->{meta} if defined $entity->{meta};
    $mapped{notes} = $entity->{notes} if defined $entity->{notes};
    $mapped{subtype} = $subtype if defined $subtype;

    return \%mapped;
}


1;