-- This script should remove all objects created by the provisioning process.

-- It might be a good idea to employ a transaction and verifying that this is
-- not being run on sensitive instances, such as production.

SET search_path TO :"nspace", :"apinspace", public;

SET SESSION app.ephemeral_dbs = 'dev,qa,local';

BEGIN;

DO $$
BEGIN
  PERFORM TRUE
  WHERE NOT string_to_array(current_setting('app.ephemeral_dbs'), ',')
            @> ARRAY[CURRENT_DATABASE()::TEXT];
  IF FOUND THEN
    RAISE EXCEPTION
    USING message = 'cannot destroy this database',
          hint = FORMAT('only database %s can be destroyed',
                        current_setting('app.ephemeral_dbs'));
  END IF;
END;
$$
LANGUAGE plpgsql;

DROP TABLE IF EXISTS :"nspace".schema_errata;
DROP TABLE IF EXISTS :"nspace".example;

DROP SCHEMA :"nspace" CASCADE;
DROP SCHEMA :"apinspace" CASCADE;
DROP SCHEMA audit CASCADE;
DROP ROLE :"nspace";

COMMIT;
