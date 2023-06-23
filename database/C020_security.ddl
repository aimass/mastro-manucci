SET search_path TO :"nspace", :"apinspace", public;

CREATE ROLE :nspace WITH LOGIN PASSWORD 'ONLY_FOR_LOCAL_DEVELOPMENT';
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM :nspace, :nspaceadmin;
REVOKE ALL ON ALL TABLES IN SCHEMA :nspace FROM :nspace, :nspaceadmin;

ALTER ROLE :nspace SET search_path = :nspace, public;
GRANT USAGE ON SCHEMA :nspace TO :nspace;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA :nspace TO :nspace;
GRANT SELECT,INSERT ON ALL TABLES IN SCHEMA :nspace TO :nspace;
GRANT UPDATE ON TABLE transaction TO :nspace;
GRANT UPDATE,DELETE ON TABLE coa TO :nspace;
GRANT UPDATE,DELETE ON TABLE subacct TO :nspace;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA :nspace TO :nspace;

-- #########################
--      BLOCK AND LOG
-- DOES NOT AUDIT LOG INSERT
-- #########################

-- These tables are journals by definition so they don't need audit on INSERT

-- JOURNAL
CREATE OR REPLACE RULE no_update_journal AS ON UPDATE TO journal
    DO INSTEAD SELECT audit.log_blocked(:'nspace','journal',OLD.id,'UPDATE');
CREATE OR REPLACE RULE no_delete_journal AS ON DELETE TO journal
    DO INSTEAD SELECT audit.log_blocked(:'nspace','journal',OLD.id,'DELETE');

-- DOCUMENT
CREATE OR REPLACE RULE no_delete_transaction AS ON DELETE TO transaction
    DO INSTEAD SELECT audit.log_blocked(:'nspace','transaction',OLD.id,'DELETE');

-- DOCUMENT HISTORY
CREATE OR REPLACE RULE no_update_transaction_history AS ON UPDATE TO transaction_history
    DO INSTEAD SELECT audit.log_blocked(:'nspace','transaction_history',OLD.id,'UPDATE');
CREATE OR REPLACE RULE no_delete_transaction_history AS ON DELETE TO transaction_history
    DO INSTEAD SELECT audit.log_blocked(:'nspace','transaction_history',OLD.id,'DELETE');

-- #########################
--   AUDIT LOG EVERYTHING
--  DOES NOT BLOCK ANYTHING
-- #########################

-- These tables have full audit trails for INSERT. UPDATE and DELETE
-- CASCADE deletes will be blocked by rules above

SELECT audit.audit_table('coa');
SELECT audit.audit_table('subacct');
SELECT audit.audit_table('subacct_type');
SELECT audit.audit_table('entity');
SELECT audit.audit_table('entity_subtype');
SELECT audit.audit_table('transaction_state');
SELECT audit.audit_table('schema_errata');

