
BEGIN;

SET search_path TO :"nspace", :"apinspace", public;

INSERT INTO :"nspace".schema_errata ( delta )
VALUES ( '000008-balance_cache' );

create table balance_cache
(
    id                        bigserial,
    subacct_id                bigint,
    coa_id                    bigint,
    total_debits              numeric(20,4) not null default 0,
    total_credits             numeric(20,4) not null default 0,
    unique_key                text unique not null,
    primary key (id)
);

comment on table balance_cache is 'table for storing a cached balance';
comment on column balance_cache.id is 'bigserial unique id';
comment on column balance_cache.subacct_id is 'subacct';
comment on column balance_cache.coa_id is 'coa';
comment on column balance_cache.total_debits is 'total debits';
comment on column balance_cache.total_credits is 'total credits';

create index balance_cache_subacct_id_idx on balance_cache (subacct_id);
create index balance_cache_coa_id_idx on balance_cache (coa_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON balance_cache TO :rolename;

INSERT INTO balance_cache (subacct_id, coa_id, total_debits, total_credits, unique_key)
SELECT subacct.id, subacct.coa_id, COALESCE(sum(journal.debit),0), COALESCE(sum(journal.credit),0), CONCAT(CONCAT(subacct.coa_id::text,':'),subacct.id::text)
FROM coa, subacct JOIN journal ON journal.subacct_id=subacct.id AND journal.coa_id=subacct.coa_id
WHERE coa.id=subacct.coa_id AND subacct.account LIKE '%.090'
GROUP BY coa.drcr, subacct.id, subacct.coa_id, journal.subacct_id, journal.coa_id;

--INSERT INTO balance_cache (coa_id, total_debits, total_credits, unique_key)
--SELECT coa.id, COALESCE(sum(journal.debit),0), COALESCE(sum(journal.credit),0), CONCAT(coa.id::text,':')
--FROM coa JOIN journal ON journal.subacct_id IS NULL AND journal.coa_id=coa.id
--GROUP BY coa.id, coa.drcr, journal.subacct_id, journal.coa_id;

CREATE OR REPLACE FUNCTION insert_update_cache()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.subacct_id IS NOT NULL AND (SELECT id FROM subacct WHERE id = NEW.subacct_id AND account LIKE '%.090') IS NOT NULL
    THEN
        IF (SELECT id FROM balance_cache WHERE unique_key = CONCAT(CONCAT(NEW.coa_id::text,':'),NEW.subacct_id::text)) IS NOT NULL
        THEN
            IF (SELECT id FROM balance_cache WHERE unique_key = CONCAT(CONCAT(NEW.coa_id::text,':'),NEW.subacct_id::text) AND (total_credits-total_debits)>=NEW.debit FOR NO KEY UPDATE) IS NOT NULL
            THEN
                --INSERT INTO balance_cache(subacct_id, coa_id, total_debits, total_credits, unique_key)
                --VALUES(NEW.subacct_id, NEW.coa_id, NEW.debit, NEW.credit, CONCAT(CONCAT(NEW.coa_id::text,':'),NEW.subacct_id::text))
                --ON CONFLICT (unique_key)
                --    DO UPDATE SET total_debits = (balance_cache.total_debits+NEW.debit), total_credits = (balance_cache.total_credits+NEW.credit);
                UPDATE balance_cache SET total_debits = (balance_cache.total_debits+NEW.debit), total_credits = (balance_cache.total_credits+NEW.credit) WHERE unique_key = CONCAT(CONCAT(NEW.coa_id::text,':'),NEW.subacct_id::text);
            ELSE
                RETURN NULL;
            END IF;
        ELSE
            INSERT INTO balance_cache(subacct_id, coa_id, total_debits, total_credits, unique_key)
            VALUES(NEW.subacct_id, NEW.coa_id, NEW.debit, NEW.credit, CONCAT(CONCAT(NEW.coa_id::text,':'),NEW.subacct_id::text));
        END IF;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';


-- Install trigger on current journal partition (if it exists)
DO $$
DECLARE
    tablename text;
    triggername text;
BEGIN
    SELECT 'journal_' || to_char(now(), 'YYYY_MM') INTO tablename;
    IF EXISTS(SELECT FROM information_schema.tables WHERE  table_schema = 'SCHEMA_NAME' AND table_name = tablename) THEN
        SELECT tablename || '_balance_cache' INTO triggername;
        EXECUTE 'CREATE TRIGGER ' || triggername || ' BEFORE INSERT ON ' || tablename || ' FOR EACH ROW ' ||
                ' EXECUTE PROCEDURE insert_update_cache() ';
    END IF;
END $$;


-- replace partitioning function to add trigger to journal children
CREATE OR REPLACE FUNCTION create_monthly_table(table_schema TEXT, parent_table TEXT, timestamp_col TEXT, year INT, month INT) RETURNS VOID AS $$
DECLARE
    statement TEXT;
    next_date_year INT;
    next_date_month INT;
    trigger_exists TEXT;
    tgname TEXT;
BEGIN
    -- changed after the fact for new schemas
    SET search_path TO SCHEMA_NAME, manucci_audit, public;
    SET CLIENT_MIN_MESSAGES = ERROR;

    IF month = 12 THEN
        next_date_month := 1;
        next_date_year := year + 1;
    ELSE
        next_date_month := month + 1;
        next_date_year := year;
    END IF;

    statement := format('CREATE TABLE IF NOT EXISTS %7$s.%1$I_%2$s_%3$s ('
                            '    CHECK ( %4$I >= DATE ''%2$s-%3$s-01'' AND %4$I < DATE ''%5$s-%6$s-01'' )'
                            ') INHERITS (%7$s.%1$I)', parent_table, year, lpad(month::TEXT, 2, '0'),
                        timestamp_col, next_date_year, lpad(next_date_month::TEXT, 2, '0'), table_schema);

    EXECUTE statement;

    -- add txn_id trigger for transaction children
    IF (parent_table = 'transaction') THEN

        tgname := format('%1$I_%2$s_%3$s_txn_id',parent_table, year, lpad(month::TEXT, 2, '0'));

        EXECUTE format('SELECT tgname FROM pg_trigger where not tgisinternal AND tgname = %L', tgname)
            INTO trigger_exists;

        IF trigger_exists IS NULL THEN
            statement := format('CREATE TRIGGER %1$I_%2$s_%3$s_txn_id '
                                    ' BEFORE INSERT ON %7$s.%1$I_%2$s_%3$s FOR EACH ROW '
                                    ' EXECUTE PROCEDURE generate_txn_id() ', parent_table, year,
                                lpad(month::TEXT, 2, '0'), timestamp_col, next_date_year,
                                lpad(next_date_month::TEXT, 2, '0'), table_schema);
            EXECUTE statement;
        END IF;
    END IF;

    -- add balance_cache trigger for journal children
    IF (parent_table = 'journal') THEN

        tgname := format('%1$I_%2$s_%3$s_balance_cache',parent_table, year, lpad(month::TEXT, 2, '0'));

        EXECUTE format('SELECT tgname FROM pg_trigger where not tgisinternal AND tgname = %L', tgname)
            INTO trigger_exists;

        IF trigger_exists IS NULL THEN
            statement := format('CREATE TRIGGER %1$I_%2$s_%3$s_balance_cache '
                                    ' BEFORE INSERT ON %7$s.%1$I_%2$s_%3$s FOR EACH ROW '
                                    ' EXECUTE PROCEDURE insert_update_cache() ', parent_table, year,
                                lpad(month::TEXT, 2, '0'), timestamp_col, next_date_year,
                                lpad(next_date_month::TEXT, 2, '0'), table_schema);
            EXECUTE statement;
        END IF;
    END IF;


END;
$$ LANGUAGE 'plpgsql'
    SECURITY DEFINER
    -- Set a secure search_path: trusted schema(s), then 'pg_temp'.
    SET search_path TO SCHEMA_NAME, pg_temp;

-- view for balance check API
create or replace view balance_check as
with realtime_balance as (
    select
        coa.id as account_id, coa.account as account, coa.drcr as drcr, coa.description as acctdesc,
        subacct.id as subacct_id, subacct.account as subacct, subacct.description as subacctdesc,
        sum(debit) as actual_debits, sum(credit) as actual_credits
    from
        journal join coa on journal.coa_id = coa.id left outer join subacct on subacct_id = subacct.id
    where
        subacct_id is not null
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

GRANT USAGE ON ALL SEQUENCES IN SCHEMA :nspace TO :rolename;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA :nspace TO :rolename;


COMMIT;
