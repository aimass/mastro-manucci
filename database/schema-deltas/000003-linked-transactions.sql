
-- This patch provides transaction linking and grouping capabilities, where a business can model
-- multiple transactions as a logical group, with generic semantics to accommodate various models.
-- This patch also brings back transaction total, although purely referential (not mandatory), so it's
-- use is implementation dependent and currently not tied to any accounting logic

BEGIN;

SET search_path TO :"nspace", :"apinspace", public;

INSERT INTO :"nspace".schema_errata ( delta )
VALUES ( '000003-linked-transactions' );


ALTER TABLE transaction ADD COLUMN linked_to bigint;
ALTER TABLE transaction ADD COLUMN group_ref text;
ALTER TABLE transaction ADD COLUMN group_typ text;
ALTER TABLE transaction ADD COLUMN group_sta text;
ALTER TABLE transaction ADD COLUMN amount numeric(20, 4);

CREATE INDEX transaction_group_ref ON transaction (group_ref);

COMMENT ON COLUMN transaction.linked_to IS 'Links this transaction to the previous transaction in the group';
COMMENT ON COLUMN transaction.group_ref IS 'A reference or ID for the complete transaction group';
COMMENT ON COLUMN transaction.group_typ IS 'Group type, used to filter groups and Stage/Status/State by type';
COMMENT ON COLUMN transaction.group_sta IS 'Stage/Status/State that this transaction represents in the group';
COMMENT ON COLUMN transaction.amount IS 'Referential amount for transaction or transaction group';

COMMIT;