-- only used by docker-compose to bootstrap the local db
-- normally, this is done by a DBA, ops or some other admin role

--NOTE: CREATE ROLE is done by Docker compose using env vars
ALTER ROLE manucci_admin SET search_path TO manucci, apimanucci, public;
ALTER DATABASE local SET constraint_exclusion = on;


