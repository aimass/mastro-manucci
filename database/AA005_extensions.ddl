-- Use this script to enable the database extensions that your database
-- application will require.

-- make sure all extensions are in the public schema
SET search_path TO public;

-- Frequent candidates include pgcrypto, pgjwt, etc.

-- CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;
-- CREATE EXTENSION IF NOT EXISTS address_standardizer;
-- CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
-- CREATE EXTENSION IF NOT EXISTS hstore;
-- CREATE EXTENSION IF NOT EXISTS ip4r;
-- CREATE EXTENSION IF NOT EXISTS pg_hint_plan;
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- CREATE EXTENSION IF NOT EXISTS pgjwt;
CREATE EXTENSION IF NOT EXISTS pgtap;
CREATE EXTENSION IF NOT EXISTS hstore;

