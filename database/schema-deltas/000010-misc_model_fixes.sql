BEGIN;

SET search_path TO :"nspace", :"auditns", :"apinspace", public;

INSERT INTO schema_errata ( delta ) VALUES ( '000010-misc_model_fixes' );

-- drop this schema's user and role tables
DROP TABLE IF EXISTS user_role CASCADE ;
DROP TABLE IF EXISTS arole CASCADE ;
DROP TABLE IF EXISTS auser CASCADE ;

CREATE TABLE IF NOT EXISTS public.ledger_user
(
    id                    bigserial,
    username              text                                             not null unique,
    name                  text,
    given_name            text,
    family_name           text,
    sub                   text,
    aud                   text,
    accountid             text,
    iss                   text,
    email                 text,
    email_verified        boolean,
    zoneinfo              text,
    locale                text,
    phone_number          text,
    phone_number_verified boolean,
    created               timestamp without time zone default now()        not null,
    primary key (id)
);

comment on table public.ledger_user is 'System Users';
comment on column public.ledger_user.username is 'The unique username in our system';
comment on column public.ledger_user.name is 'name claim';
comment on column public.ledger_user.given_name is 'given_name claim';
comment on column public.ledger_user.family_name is 'family_name claim';
comment on column public.ledger_user.sub is 'sub claim';
comment on column public.ledger_user.aud is 'aud claim';
comment on column public.ledger_user.accountid is 'accountId claim';
comment on column public.ledger_user.iss is 'iss claim';
comment on column public.ledger_user.email is 'email claim';
comment on column public.ledger_user.email_verified is 'email_verified claim';
comment on column public.ledger_user.zoneinfo is 'zoneinfo claim';
comment on column public.ledger_user.locale is 'locale claim';
comment on column public.ledger_user.phone_number is 'phone_number claim';
comment on column public.ledger_user.phone_number_verified is 'phone_number_verified claim';
comment on column public.ledger_user.created is 'created claim';

CREATE TABLE IF NOT EXISTS public.ledger_role
(
    id                    serial,
    name                  text                                             not null unique,
    description           text                                             not null,
    primary key (id)
);

comment on table public.ledger_role is 'System Roles';
comment on column public.ledger_role.name is 'Name of role';
comment on column public.ledger_role.description is 'Description of role';

insert into public.ledger_role (name, description) values ('viewer','View only user')
on conflict (name) do nothing ;

CREATE TABLE IF NOT EXISTS public.ledger_user_role
(
    ledger_user_id              bigint      not null references public.ledger_user(id),
    ledger_role_id              bigint      not null references public.ledger_role(id),
    primary key (ledger_user_id,ledger_role_id)
);

comment on table public.ledger_user_role is 'User Roles';
comment on column public.ledger_user_role.ledger_user_id is 'User id';
comment on column public.ledger_user_role.ledger_role_id is 'Role id';

GRANT SELECT,INSERT,UPDATE,DELETE ON public.ledger_user TO :rolename;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.ledger_role TO :rolename;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.ledger_user_role TO :rolename;
GRANT SELECT,UPDATE ON public.ledger_user_id_seq TO :rolename;
GRANT SELECT,UPDATE ON public.ledger_role_id_seq TO :rolename;

-- add AUDIT users and roles
SELECT audit_table('public.ledger_user');
SELECT audit_table('public.ledger_role');
SELECT audit_table('public.ledger_user_role');

-- fix view for balance check API, adding hard-coded "AND subacct.account LIKE '%.090'"
create or replace view balance_check as
with realtime_balance as (
    select
        coa.id as account_id, coa.account as account, coa.drcr as drcr, coa.description as acctdesc,
        subacct.id as subacct_id, subacct.account as subacct, subacct.description as subacctdesc,
        sum(debit) as actual_debits, sum(credit) as actual_credits
    from
        journal join coa on journal.coa_id = coa.id left outer join subacct on subacct_id = subacct.id
    where
        subacct_id is not null AND subacct.account LIKE '%.090'
    group by
        coa.id, coa.account, coa.drcr, coa.description, subacct.id, subacct.account, subacct.description
    order by
        account, subacct
), joined_balances as (
    select account, drcr, acctdesc, subacct, subacctdesc,
           balance_cache.total_debits as cache_debits, actual_debits,
           balance_cache.total_credits as cache_credits, actual_credits,
           case
               when drcr = 'DR' then (actual_debits - actual_credits)
               when drcr = 'CR' then (actual_credits - actual_debits)
               end as actual_balance,
           case
               when drcr = 'DR' then (total_debits - total_credits)
               when drcr = 'CR' then (total_credits - total_debits)
               end as cache_balance,
           case
               when
                   actual_debits = balance_cache.total_debits
                       and actual_credits = balance_cache.total_credits
                   then 'OK'
               else 'NOK'
               end as balance_check
    from realtime_balance left join balance_cache
                                    on (balance_cache.coa_id = account_id and realtime_balance.subacct_id is null)
                                        or (balance_cache.coa_id = account_id and balance_cache.subacct_id = realtime_balance.subacct_id)
)
select * from joined_balances;

GRANT SELECT ON balance_check TO :rolename;

-- this function was erroneously created in the application schema and belongs in the audit schema
-- new schemas will not have this function in their DDL so they need to find this one in the right place
-- existing schemas will continue to use their existing function which is identical

SET search_path TO :"auditns";

CREATE OR REPLACE FUNCTION log_blocked(p_schema_name text, p_table_name text, p_relid oid, p_operation text) RETURNS text AS $body$
DECLARE
    audit_schema text;
BEGIN
    INSERT INTO logged_actions (
        event_id,
        schema_name,
        table_name,
        relid,
        session_user_name,
        action_tstamp_tx,
        action_tstamp_stm,
        action_tstamp_clk,
        transaction_id,
        application_name,
        client_addr,
        client_port,
        client_query,
        action,
        row_data,
        changed_fields,
        statement_only
    ) VALUES (
                 nextval('logged_actions_event_id_seq'),
                 p_schema_name,
                 p_table_name,
                 p_relid,
                 session_user::text,
                 current_timestamp,
                 statement_timestamp(),
                 clock_timestamp(),
                 txid_current(),
                 current_setting('application_name'),
                 inet_client_addr(),
                 inet_client_port(),
                 current_query(),
                 substring(p_operation,1,1),
                 NULL, NULL,
                 't'
             );
    RETURN 'SECURITY ALERT:'||p_operation||' ON THIS TABLE BLOCKED. YOUR ACTION HAS BEEN LOGGED!';
END;
$body$ LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = :"auditns", pg_catalog, public;

-- log_blocked fix (eliminate from base schema and use the one in the audit schema)

-- make sure we drop the right one !

SET search_path TO :"nspace";

-- this will also drop the 4 security rules
DROP FUNCTION IF EXISTS log_blocked CASCADE ;

-- make sure we can find the new fucntion in auditns
SET search_path TO :"nspace", :"auditns";

-- re-apply security rules (re-running these on new schemas is harmless)

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

COMMIT;
