#!/bin/bash

sed -i 's/#port = 5432/port = 40032/g' /var/lib/postgresql/data/postgresql.conf
pg_ctl reload -D /var/lib/postgresql/data