-- Provides a Expense accounts for fees and other operating costs
-- Fixes the index inheritance problem
-- Fixes trigger inheritance so that it will support multi-schema

-------------------------------------------
-- Revised trigger existance query logic --
-------------------------------------------
-- Revised logic to consider triggers as per table, not per schema, as pg_trigger's tgname
-- can recur for different table OIDs.
-- This addresses a latent issue where for multi-schema setups, trigger existence checks could
-- erroneously report a trigger as existing on a new schema's table.

BEGIN;

SET search_path TO :"nspace", :"apinspace", public;

INSERT INTO schema_errata ( delta ) VALUES ( '000009-expense_and_index_fix' );

INSERT INTO coa (account, description, type, drcr, heading)
VALUES

-- EXPENSE headers
('5','Expenses','EXPENSE','DR',TRUE),
('5.1', 'Expenses by Nature','EXPENSE','DR',TRUE),
('5.1.3', 'Services','EXPENSE','DR',TRUE),
-- EXPENSE real
('5.1.3.110','Wire Fees','EXPENSE','DR',false),

-- OTHER real
('6.1.2.10','Interest Payouts Bank 1','EXPENSE','DR',false)
;

-- replace partitioning function to fix missing indexes on child tables
CREATE OR REPLACE FUNCTION create_monthly_table(table_schema TEXT, parent_table TEXT, timestamp_col TEXT, year INT, month INT) RETURNS VOID AS $$
DECLARE
    statement TEXT;
    next_date_year INT;
    next_date_month INT;
    two_digit_month TEXT := lpad(month::TEXT, 2, '0');
    trigger_exists TEXT;
    trigger_name TEXT;
    table_name TEXT;
    schema_table_name TEXT;
    index_exists TEXT;
    index_name TEXT;
    element TEXT;
    index_data hstore;

    -- transaction indexes
    transaction_btree_indexes TEXT[] := ARRAY[
        '"name"=>"pk", "column"=>"id"',
        '"name"=>"reference", "column"=>"reference"',
        '"name"=>"txn_id", "column"=>"txn_id"',
        '"name"=>"fk_entity_id", "column"=>"entity_id"',
        '"name"=>"fk_state_id", "column"=>"state_id"',
        '"name"=>"group_ref", "column"=>"group_ref"'
    ];
    transaction_gin_indexes TEXT[] := ARRAY[
        '"name"=>"meta", "column"=>"meta"'
    ];

    -- journal indexes
    journal_btree_indexes TEXT[] := ARRAY [
        '"name"=>"pk", "column"=>"id"',
        '"name"=>"fk_coa_id", "column"=>"coa_id"',
        '"name"=>"fk_subacct_id", "column"=>"subacct_id"'
    ];

    -- transaction_history indexes
    transaction_history_btree_indexes TEXT[] := ARRAY[
        '"name"=>"pk", "column"=>"id"',
        '"name"=>"fk_state_from_id", "column"=>"state_from_id"',
        '"name"=>"fk_state_to_id", "column"=>"state_to_id"',
        '"name"=>"fk_transaction_id", "column"=>"transaction_id"'
    ];
    transaction_history_gin_indexes TEXT[] := ARRAY[
        '"name"=>"data_in", "column"=>"data_in jsonb_path_ops"',
        '"name"=>"data_out", "column"=>"data_out jsonb_path_ops"'
    ];

    -- transaction_line indexes
    transaction_line_btree_indexes TEXT[] := ARRAY[
        '"name"=>"pk", "column"=>"id"',
        '"name"=>"fk_transaction_id", "column"=>"transaction_id"',
        '"name"=>"fk_coa_id", "column"=>"coa_id"',
        '"name"=>"fk_subacct_id", "column"=>"subacct_id"'
    ];

BEGIN
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
                            ') INHERITS (%7$s.%1$I)', parent_table, year, two_digit_month,
                        timestamp_col, next_date_year, lpad(next_date_month::TEXT, 2, '0'), table_schema);

    EXECUTE statement;

    -- Add txn_id trigger and indexes for transaction children
    IF (parent_table = 'transaction') THEN

        table_name := format('%1$I_%2$s_%3$s',parent_table, year, two_digit_month);

        ----------------------------
        -- TRANSACTION ID TRIGGER --
        ----------------------------
        trigger_name := format('%1$s_txn_id',table_name);
        schema_table_name := format('%1$s.%2$s',table_schema, table_name);

        EXECUTE format('SELECT tgname FROM pg_trigger where not tgisinternal AND tgname = %1$L AND tgrelid = %2$L::regclass', trigger_name, schema_table_name)
            INTO trigger_exists;

        IF trigger_exists IS NULL THEN
            statement := format('CREATE TRIGGER %1$I_%2$s_%3$s_txn_id '
                                    ' BEFORE INSERT ON %7$s.%1$I_%2$s_%3$s FOR EACH ROW '
                                    ' EXECUTE PROCEDURE generate_txn_id() ', parent_table, year,
                                two_digit_month, timestamp_col, next_date_year,
                                lpad(next_date_month::TEXT, 2, '0'), table_schema);
            EXECUTE statement;
        END IF;

        ----------------------------
        --     BTREE INDEXES      --
        ----------------------------
        FOREACH element IN ARRAY transaction_btree_indexes LOOP
            index_data := element::hstore;
            index_name := format('%1$I_%2$s_%3$s_%4$s_idx',parent_table, year, two_digit_month,index_data->'name');
            EXECUTE format('SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = %L AND n.nspname = %L', index_name, table_schema)
                INTO index_exists;
            IF index_exists IS NULL THEN
                EXECUTE format('CREATE INDEX %1$s ON %2$s.%3$s (%4$I)',index_name, table_schema, table_name, index_data->'column');
            END IF;
        END LOOP;

        ----------------------------
        --       GIN INDEXES      --
        ----------------------------
        FOREACH element IN ARRAY transaction_gin_indexes LOOP
            index_data := element::hstore;
            index_name := format('%1$I_%2$s_%3$s_%4$s_idx',parent_table, year, two_digit_month,index_data->'name');
            EXECUTE format('SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = %L AND n.nspname = %L', index_name, table_schema)
                INTO index_exists;
            IF index_exists IS NULL THEN
                EXECUTE format('CREATE INDEX %1$s ON %2$s.%3$s USING GIN (%4$s)',index_name, table_schema, table_name, index_data->'column');
            END IF;
        END LOOP;

    END IF;

    -- Add balance_cache trigger and indexes for journal children
    IF (parent_table = 'journal') THEN

        table_name := format('%1$I_%2$s_%3$s',parent_table, year, two_digit_month);

        -- see "Revised trigger existance query logic"above
        trigger_name := format('%1$s_balance_cache',table_name);
        schema_table_name := format('%1$s.%2$s',table_schema, table_name);
        EXECUTE format('SELECT tgname FROM pg_trigger where not tgisinternal AND tgname = %1$L AND tgrelid = %2$L::regclass', trigger_name, schema_table_name)
            INTO trigger_exists;

        IF trigger_exists IS NULL THEN
            statement := format('CREATE TRIGGER %1$I_%2$s_%3$s_balance_cache '
                                    ' BEFORE INSERT ON %7$s.%1$I_%2$s_%3$s FOR EACH ROW '
                                    ' EXECUTE PROCEDURE insert_update_cache() ', parent_table, year,
                                lpad(month::TEXT, 2, '0'), timestamp_col, next_date_year,
                                lpad(next_date_month::TEXT, 2, '0'), table_schema);
            EXECUTE statement;
        END IF;

        ----------------------------
        --     BTREE INDEXES      --
        ----------------------------
        FOREACH element IN ARRAY journal_btree_indexes LOOP
                index_data := element::hstore;
                index_name := format('%1$I_%2$s_%3$s_%4$s_idx',parent_table, year, two_digit_month,index_data->'name');
                EXECUTE format('SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = %L AND n.nspname = %L', index_name, table_schema)
                    INTO index_exists;
                IF index_exists IS NULL THEN
                    EXECUTE format('CREATE INDEX %1$s ON %2$s.%3$s (%4$I)',index_name, table_schema, table_name, index_data->'column');
                END IF;
        END LOOP;


    END IF;

    -- Add indexes for transaction_history
    IF (parent_table = 'transaction_history') THEN

        table_name := format('%1$I_%2$s_%3$s',parent_table, year, two_digit_month);

        ----------------------------
        --     BTREE INDEXES      --
        ----------------------------
        FOREACH element IN ARRAY transaction_history_btree_indexes LOOP
                index_data := element::hstore;
                index_name := format('%1$I_%2$s_%3$s_%4$s_idx',parent_table, year, two_digit_month,index_data->'name');
                EXECUTE format('SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = %L AND n.nspname = %L', index_name, table_schema)
                    INTO index_exists;
                IF index_exists IS NULL THEN
                    EXECUTE format('CREATE INDEX %1$s ON %2$s.%3$s (%4$I)',index_name, table_schema, table_name, index_data->'column');
                END IF;
        END LOOP;

        ----------------------------
        --       GIN INDEXES      --
        ----------------------------
        FOREACH element IN ARRAY transaction_history_gin_indexes LOOP
                index_data := element::hstore;
                index_name := format('%1$I_%2$s_%3$s_%4$s_idx',parent_table, year, two_digit_month,index_data->'name');
                EXECUTE format('SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = %L AND n.nspname = %L', index_name, table_schema)
                    INTO index_exists;
                IF index_exists IS NULL THEN
                    EXECUTE format('CREATE INDEX %1$s ON %2$s.%3$s USING GIN (%4$s)',index_name, table_schema, table_name, index_data->'column');
                END IF;
        END LOOP;


    END IF;

    -- Add indexes for transaction_line
    IF (parent_table = 'transaction_line') THEN

        table_name := format('%1$I_%2$s_%3$s',parent_table, year, two_digit_month);

        ----------------------------
        --     BTREE INDEXES      --
        ----------------------------
        FOREACH element IN ARRAY transaction_line_btree_indexes LOOP
                index_data := element::hstore;
                index_name := format('%1$I_%2$s_%3$s_%4$s_idx',parent_table, year, two_digit_month,index_data->'name');
                EXECUTE format('SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = %L AND n.nspname = %L', index_name, table_schema)
                    INTO index_exists;
                IF index_exists IS NULL THEN
                    EXECUTE format('CREATE INDEX %1$s ON %2$s.%3$s (%4$I)',index_name, table_schema, table_name, index_data->'column');
                END IF;
        END LOOP;

    END IF;

END
$$ LANGUAGE 'plpgsql'
    SECURITY DEFINER
    -- Set a secure search_path: trusted schema(s), then 'pg_temp'.
    SET search_path TO :"nspace", pg_temp, public;

COMMIT;
