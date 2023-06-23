-- Use this script to enable the database extensions that your database
-- application will require. Also conditionally generate any schemas or
-- namespaces that will be needed by your appllication.

-- make sure all extensions are in the public schema
SET search_path TO public;

-- Namespaces that will be used in this project. You can pass this namespace via
-- the environment.

CREATE SCHEMA IF NOT EXISTS :"nspace";
CREATE SCHEMA IF NOT EXISTS :"apinspace";

-- Frequent candidates include pgcrypto, pgjwt, etc.

-- CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;
-- CREATE EXTENSION IF NOT EXISTS address_standardizer;
-- CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
-- CREATE EXTENSION IF NOT EXISTS ip4r;
-- CREATE EXTENSION IF NOT EXISTS pg_hint_plan;
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- CREATE EXTENSION IF NOT EXISTS pgjwt;
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgtap;
CREATE EXTENSION IF NOT EXISTS hstore;

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


