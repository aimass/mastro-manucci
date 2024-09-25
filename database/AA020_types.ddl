-- Use this script to define PostgreSQL domains / types that your application
-- will require.

SET search_path TO :"nspace", :"apinspace", public;

CREATE TYPE entity_type AS ENUM ('PERSON','ORGANIZATION','OTHER');
CREATE TYPE account_type AS ENUM ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE');
CREATE TYPE account_drcr AS ENUM ('DR','CR');
CREATE TYPE entry_type AS ENUM ('DEBIT','CREDIT');
CREATE TYPE audit_event AS ENUM ('INSERT', 'UPDATE', 'DELETE', 'INCOME', 'EXPENSE');

