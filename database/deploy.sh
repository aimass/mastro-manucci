#!/usr/bin/env bash

echo dbdeploy entry

#set -e
. ./setup.sh

echo -- Running database schema "${PGNAMESPACE}"

for ddl in AA010_prerequisites.ddl \
           AA020_types.ddl \
           AA030_functions.ddl \
           AB000_schema.ddl \
           AB010_schema-deltas.ddl \
           AB020_views.ddl \
           AB030_indexes.ddl \
           AB040_triggers.ddl \
           AC010_partitioning.ddl \
           AC020_integrity.ddl \
           AD000_seed-data.sql \
           AE000_security.ddl \
           ;
do
    echo -- "  " "${ddl}"
    PSQLRC=psqlrc-quiet ${PSQL_CMD} -f "${ddl}"
done

exit 0

