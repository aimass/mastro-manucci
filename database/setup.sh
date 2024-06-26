#!/usr/bin/env bash

#set -e

PGNAMESPACE=${PGNAMESPACE:=skel}
NSPACEADMIN="${PGNAMESPACE}_admin"
PGAPINAMESPACE=${PGAPINAMESPACE:=api${PGNAMESPACE}}
SCHEMA_ERRATA_CSV=${SCHEMA_ERRATA_CSV:=/tmp/${PGNAMESPACE}-schema_errata.csv}

PSQL=${PSQL:=$(which psql)}
PSQL_CMD=${PSQL_CMD:=${PSQL} --set=nspace="${PGNAMESPACE}" --set=apinspace="${PGAPINAMESPACE}" --set=nspaceadmin="${NSPACEADMIN}"}

PGPROVE=${PGPROVE:=$(which pg_prove)}
PGPROVE_CMD=${PGPROVE_CMD:=${PGPROVE}  --set=nspace="${PGNAMESPACE}" --set=apinspace="${PGAPINAMESPACE}" --set=nspaceadmin="${NSPACEADMIN}"}
