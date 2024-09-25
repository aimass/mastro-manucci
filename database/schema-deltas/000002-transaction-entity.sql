BEGIN;

SET search_path TO :"nspace", :"apinspace", public;

INSERT INTO :"nspace".schema_errata ( delta )
VALUES ( '000002-transaction-entity' );

ALTER TABLE transaction ADD COLUMN entity_id bigint;

ALTER TABLE transaction ADD CONSTRAINT fk_transaction_transaction_entity_id FOREIGN KEY (entity_id) REFERENCES entity (id);
CREATE INDEX fkidx_transaction_transaction_entity_id ON transaction (entity_id);

COMMENT ON COLUMN transaction.entity_id IS 'Main entity associated to this transaction, if any';

COMMIT;