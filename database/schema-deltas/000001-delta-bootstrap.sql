BEGIN;

SET search_path TO :"nspace", :"apinspace", public;

INSERT INTO :"nspace".schema_errata ( delta )
VALUES ( '000001-delta-bootstrap' );

-- NOP: this file is just to make sure the delta logic is working

COMMIT;