#!/usr/bin/env bash

echo dbdeploy entry

#set -e
. ./setup.sh

echo -- Running database schema "${PGNAMESPACE}"

for ddl in A010_prerequisites.ddl \
           A020_types.ddl \
           A030_functions.ddl \
           B000_schema.ddl \
           B010_schema-deltas.ddl \
           B020_views.ddl \
           B030_indexes.ddl \
           B040_triggers.ddl \
           C000_audit.ddl \
           C010_partitioning.ddl \
           C020_security.ddl \
           C030_integrity.ddl \
           D000_seed-data.sql \
           ;
do
    echo -- "  " "${ddl}"
    PSQLRC=psqlrc-quiet ${PSQL_CMD} -f "${ddl}"
done

exit 0

