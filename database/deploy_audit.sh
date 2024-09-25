#!/usr/bin/env bash

echo auditdeploy entry

#set -e
. ./setup.sh

echo -- Running database schema "${PGNAMESPACE}"

for ddl in AA006_audit_schema.ddl \
           ;
do
    echo -- "  " "${ddl}"
    PSQLRC=psqlrc-quiet ${PSQL_CMD} -f "${ddl}"
done

exit 0

