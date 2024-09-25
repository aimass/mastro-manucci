#!/usr/bin/env bash

echo dbdeploy entry

#set -e
. ./setup.sh

echo -- Creating roles in schema "${PGNAMESPACE}"

ddl=AE000_security.ddl
echo -- "  " "${ddl}"
PSQLRC=psqlrc-quiet ${PSQL_CMD} -f "${ddl}"

exit 0

