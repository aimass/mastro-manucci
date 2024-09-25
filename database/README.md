# Database schema generation scripts

The `.ddl` files in this directory contains the DDL that defines the required objects in the database. The general idea
is to split your database schema creation in sensible sections that can be applied in sequence by the helper shell
scripts.

In general terms, the `.ddl` files are meant to deploy your database schema to a plain, blank database.

## Helper Scripts

| Script         |  Purpose |
| :------------- |  :------- |
| `./deploy.sh`  |  Deploys a pristine database schema _without_ any additional schema deltas. |
| `./deltas.sh`  |  Applies all pending deltas. |
| `./destroy.sh` |  Destroys the schema and its data using your provided scripts. |
| `./test.sh`    |  Run database test suite with `pg_prove`. |

## Namespace support

The provided scripts create two namespaces to help keep the different components of a project logically separated. One
namespace is meant to keep the _private_ parts of your schema, while the other is meant to be used in combination with
[PostgREST](https://postgrest.org/) for managing a separate REST API.

To set the desired namespace names you can use the environment variables `$PGNAMESPACE` and `$PGNAMESPACEAPI`. Note that
these environment variables are folded into `psql` variables `:nspace` and `:apinspace` that can be used across the rest
of the provisioning scripts.

The design assumes that there will be at least one namespace per application sharing the database.

By default, the scripts attempt a conditional namespace creation, as depicted below.

```sql
CREATE SCHEMA IF NOT EXISTS :"nspace";
CREATE SCHEMA IF NOT EXISTS :"apinspace";
```

The helper shell scripts default to `skel` and `apiskel` as the namespaces.

## Configuring database coordinates

Scripts are executed via the `psql` tool, so any of the methods supported by that tool work for deployment. See the
[psql Environment section](https://www.postgresql.org/docs/current/static/app-psql.html#APP-PSQL-ENVIRONMENT) for more
information on the variables to use to point your deployment as desired. Specially the `PGDATABASE`, `PGHOST`, `PGPORT`
and `PGUSER` variables.

## Updating other database instances

Other database instances such as QA and Production will normally operate without the most recent _deltas_. As the time
to deploy those _deltas_ come, it can be as simple as doing this.

## Destroying database schemas

You will need to tweak the definition of `app.ephemeral_dbs` to include the databases that you wish to be able to
`destroy`.

## Credit and source of DB Schema Skel

This schema and methodology is based on: https://github.com/nerdlem/schema-skel 