#!/usr/bin/env bash

#set -e

PGNAMESPACE=${PGNAMESPACE:=skel}
AUDITNS="audit_manucci" # audit is one per ledger cluster
NSPACEADMIN="${PGNAMESPACE}_admin"
PGAPINAMESPACE=${PGAPINAMESPACE:=api${PGNAMESPACE}}
ROLENAME=${ROLENAME:=${PGNAMESPACE}}
SCHEMA_ERRATA_CSV=${SCHEMA_ERRATA_CSV:=/tmp/${PGNAMESPACE}-schema_errata.csv}

PSQL=${PSQL:=$(which psql)}
PSQL_CMD=${PSQL_CMD:=${PSQL} --set=nspace="${PGNAMESPACE}" --set=auditns="${AUDITNS}" --set=apinspace="${PGAPINAMESPACE}" --set=nspaceadmin="${NSPACEADMIN}" --set=rolename="${ROLENAME}"}

PGPROVE=${PGPROVE:=$(which pg_prove)}
PGPROVE_CMD=${PGPROVE_CMD:=${PGPROVE}  --set=nspace="${PGNAMESPACE}" --set=auditns="${AUDITNS}" --set=apinspace="${PGAPINAMESPACE}" --set=nspaceadmin="${NSPACEADMIN}" --set=rolename="${ROLENAME}"}
PGPROVE_OPTS="-v"