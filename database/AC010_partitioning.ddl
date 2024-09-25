-- table partitioning logic

SET search_path TO :"nspace", :"apinspace", public;

CREATE OR REPLACE FUNCTION create_monthly_table(table_schema TEXT, parent_table TEXT, timestamp_col TEXT, year INT, month INT) RETURNS VOID AS $$
  DECLARE
    statement TEXT;
    next_date_year INT;
    next_date_month INT;
    trigger_exists TEXT;
    tgname TEXT;
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

  END;
$$ LANGUAGE 'plpgsql'
    SECURITY DEFINER
    SET search_path TO :"nspace", pg_temp, public;

CREATE OR REPLACE FUNCTION child_insert() RETURNS TRIGGER AS $$
  DECLARE
    timestamp_col TEXT;
    log_timestamp TIMESTAMP WITHOUT TIME ZONE;
    log_year INT;
    log_month INT;
  BEGIN
    timestamp_col := TG_ARGV[0];
    EXECUTE format('SELECT ($1).%I::TIMESTAMP WITHOUT TIME ZONE', timestamp_col) USING NEW INTO log_timestamp;
    log_year := extract(YEAR FROM log_timestamp);
    log_month := extract(MONTH FROM log_timestamp);

    PERFORM create_monthly_table(TG_TABLE_SCHEMA, TG_TABLE_NAME, timestamp_col, log_year, log_month);
    EXECUTE format('INSERT INTO %4$s.%1$I_%2$s_%3$s SELECT $1.*', TG_TABLE_NAME, log_year, lpad(log_month::TEXT, 2, '0'),TG_TABLE_SCHEMA) USING NEW;

    RETURN NULL;
  END;
$$ LANGUAGE  'plpgsql'
    SECURITY DEFINER
    SET search_path TO :"nspace", pg_temp, public;

CREATE TRIGGER journal_insert_trigger
  BEFORE INSERT ON journal
  FOR EACH ROW EXECUTE PROCEDURE child_insert('created');

CREATE TRIGGER transaction_insert_trigger
  BEFORE INSERT ON transaction
  FOR EACH ROW EXECUTE PROCEDURE child_insert('created');

CREATE TRIGGER transaction_line_insert_trigger
  BEFORE INSERT ON transaction_line
  FOR EACH ROW EXECUTE PROCEDURE child_insert('created');

CREATE TRIGGER transaction_history_trigger
  BEFORE INSERT ON transaction_history
  FOR EACH ROW EXECUTE PROCEDURE child_insert('created');



