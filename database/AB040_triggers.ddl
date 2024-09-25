-- Use this script to define TRIGGERs

SET search_path TO :"nspace", :"apinspace", public;

CREATE OR REPLACE FUNCTION generate_txn_id() RETURNS TRIGGER AS $body$
DECLARE
    txn_id bigint;
BEGIN
    SELECT account_number(NEW.id) INTO txn_id;
    NEW.txn_id = txn_id;
    return NEW;
END;
$body$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION generate_acct_num() RETURNS TRIGGER AS $body$
DECLARE
    acct_num bigint;
BEGIN
    SELECT account_number(NEW.id) INTO acct_num;
    NEW.acct_num = acct_num;
    return NEW;
END;
$body$
LANGUAGE 'plpgsql';

CREATE TRIGGER entity_acct_num
    BEFORE INSERT
    ON entity
    FOR EACH ROW
EXECUTE PROCEDURE generate_acct_num();

-- just for reference. transaction table is partitioned so these triggers are created in the actual partitions
-- see C010_partitioning where it adds this trigger is the parent table is 'transaction'
-- CREATE TRIGGER transaction_txn_id
--     BEFORE INSERT
--     ON transaction
--     FOR EACH ROW
-- EXECUTE PROCEDURE generate_txn_id();
