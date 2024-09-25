SET search_path TO :"nspace", :"auditns", :"apinspace", public;

--==============================================
-- CURRENT SECURITY MODEL FOR RUNTIME DB USER --
--==============================================
-- LATEST REVIEW: 000009-expense_and_index_fix.sql

----------------------------------------
-- AB000_schema.ddl (ORIGINAL SCHEMA) --
----------------------------------------
-- coa: SELECT, INSERT, UPDATE,DELETE + AUDIT
-- entity_subtype: SELECT, INSERT, UPDATE,DELETE + AUDIT
-- entity: SELECT, INSERT, UPDATE,DELETE + AUDIT
-- subacct_type: SELECT, INSERT + AUDIT
-- subacct: SELECT, INSERT, UPDATE, DELETE + AUDIT
-- journal: SELECT, INSERT + AUDITED NO-UPDATE, NO-DELETE RULE
-- transaction_state: SELECT, INSERT + AUDIT
-- transaction: SELECT, INSERT, UPDATE + AUDITED NO-DELETE RULE
-- transaction_line: SELECT, INSERT + AUDITED NO-DELETE RULE
-- transaction_history: SELECT, INSERT + AUDITED NO-UPDATE, NO-DELETE RULE
-- business_api: SELECT, INSERT + AUDIT
-- business_api_run: SELECT, INSERT

-----------------------------------------------
-- AB010_schema-deltas.ddl (ORIGINAL SCHEMA) --
-----------------------------------------------
-- schema_errata: NONE (ONLY FOR SCHEMA ADMIN) + AUDIT

--======================================
-- SECURITY MODEL UPDATES FROM DELTAS --
--======================================

-------------------------------
-- 000006-user-and-roles.sql --
-------------------------------
-- auser: SELECT, INSERT, UPDATE, DELETE
-- arole: SELECT, INSERT, UPDATE, DELETE
-- user_role: SELECT, INSERT, UPDATE, DELETE

------------------------------
-- 000008-balance_cache.sql --
------------------------------
-- balance_cache: SELECT, INSERT, UPDATE, DELETE

---------------------------------
-- 000010-misc_model_fixes.sql --
---------------------------------
-- auser: + AUDIT
-- arole: + AUDIT
-- user_role: + AUDIT


CREATE ROLE :rolename WITH LOGIN PASSWORD 'ONLY_FOR_LOCAL_DEVELOPMENT';
REVOKE ALL ON ALL TABLES IN SCHEMA :nspace FROM :rolename;

ALTER ROLE :rolename SET search_path = :nspace, public;
GRANT USAGE ON SCHEMA :nspace TO :rolename;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA :nspace TO :rolename;
GRANT SELECT,INSERT ON ALL TABLES IN SCHEMA :nspace TO :rolename;
GRANT UPDATE ON TABLE transaction TO :rolename;
GRANT UPDATE,DELETE ON TABLE coa TO :rolename;
GRANT UPDATE,DELETE ON TABLE subacct TO :rolename;
GRANT UPDATE,DELETE ON TABLE entity TO :rolename;
GRANT UPDATE,DELETE ON TABLE entity_subtype TO :rolename;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA :nspace TO :rolename;

-- #########################
--      BLOCK AND LOG
-- DOES NOT AUDIT LOG INSERT
-- #########################

-- These tables are journals by definition so they don't need audit on INSERT

-- JOURNAL
CREATE OR REPLACE RULE no_update_journal AS ON UPDATE TO journal
    DO INSTEAD SELECT log_blocked(:'nspace','journal',OLD.id,'UPDATE');
CREATE OR REPLACE RULE no_delete_journal AS ON DELETE TO journal
    DO INSTEAD SELECT log_blocked(:'nspace','journal',OLD.id,'DELETE');

-- TRANSACTION
CREATE OR REPLACE RULE no_delete_transaction AS ON DELETE TO transaction
    DO INSTEAD SELECT log_blocked(:'nspace','transaction',OLD.id,'DELETE');

-- TRANSACTION_LINE
CREATE OR REPLACE RULE no_delete_transaction_line AS ON DELETE TO transaction_line
    DO INSTEAD SELECT log_blocked(:'nspace','transaction_line',OLD.id,'DELETE');

-- TRANSACTION HISTORY
CREATE OR REPLACE RULE no_update_transaction_history AS ON UPDATE TO transaction_history
    DO INSTEAD SELECT log_blocked(:'nspace','transaction_history',OLD.id,'UPDATE');
CREATE OR REPLACE RULE no_delete_transaction_history AS ON DELETE TO transaction_history
    DO INSTEAD SELECT log_blocked(:'nspace','transaction_history',OLD.id,'DELETE');

-- #############################
--   AUDIT LOG EVERYTHING ELSE
--   DOES NOT BLOCK ANYTHING
-- #############################

-- Note: By the rules above journal and transaction are an audit table by definition,
--       audit is for everything else.

-- Tables below will have full audit trails for INSERT. UPDATE and DELETE
-- CASCADE deletes will be blocked by rules above

SELECT audit_table('coa');
SELECT audit_table('entity_subtype');
SELECT audit_table('entity');
SELECT audit_table('subacct_type');
SELECT audit_table('subacct');
SELECT audit_table('transaction_state');
SELECT audit_table('schema_errata');
SELECT audit_table('business_api');
