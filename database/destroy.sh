#!/usr/bin/env bash

echo dbdestroy entry

#set -e
. ./setup.sh

PGNAMESPACE=${PGNAMESPACE:=skel}
AUDITNS="audit_${PGNAMESPACE}"
PGAPINAMESPACE=${PGAPINAMESPACE:=api${PGNAMESPACE}}
ROLENAME=${ROLENAME:=${PGNAMESPACE}}
PSQL=${PSQL:=psql}
PSQL_CMD=${PSQL_CMD:=${PSQL} --set=nspace="${PGNAMESPACE}" --set=apinspace="${PGAPINAMESPACE}" --set=rolename="${ROLENAME}"}

echo -- Destroying schema on namespace "${PGNAMESPACE}"

for ddl in destroy.ddl \
           ;
do
    echo -- "  " "${ddl}"
    PSQLRC=psqlrc-quiet ${PSQL_CMD} -f "${ddl}"
done

exit 0

