# Step 17: Postgres pgvector Cutover and Collation Follow-up

This run documents the live cutover of the shared `infra-postgres` service from `postgres:16` to `pgvector/pgvector:pg16`, the validation steps that were executed afterwards, and the follow-up work that remains because the new container image uses a different collation library version.

## What Was Changed

- The shared Postgres service in `infra_stack_application/docker-compose.yml` was switched from `postgres:16` to `pgvector/pgvector:pg16`.
- The live container `infra-postgres` was recreated against the existing bind-mounted data directory.
- No credentials, ports, container names, networks, or volume paths were changed.
- No application database schema changes were performed.
- `pgvector` was not auto-enabled inside any database as part of the cutover.

## Validation Performed

The following checks were run after the recreate:

```bash
docker compose -f infra_stack_application/docker-compose.yml config
docker inspect infra-postgres --format '{{.Config.Image}} {{.State.Health.Status}}'
docker exec infra-postgres psql -U postgres -d postgres -Atc "SELECT current_setting('server_version');"
docker exec infra-postgres psql -U postgres -d postgres -Atc "SELECT name FROM pg_available_extensions WHERE name = 'vector';"
```

Validated outcome:

- `infra-postgres` is healthy after recreate.
- The live image is now `pgvector/pgvector:pg16`.
- The server is reachable and reports PostgreSQL `16.14`.
- `pgvector` is available through `pg_available_extensions`.

All known live databases remained reachable after the cutover:

- `audio2knowledge`
- `hoppscotch_db`
- `infisical_db`
- `omi_db`
- `postgres`
- `second_brain`
- `twenty_db`

Schema spot-checks matched the documented inventory in `databases.md`:

- all databases except `twenty_db` still expose `public`
- `twenty_db` still exposes `core`, `public`, `workspace_8vlg4mwbhz75ivvkmky2lrjle`

Known live consumers were also checked after the cutover:

- `infra-infisical` responded on `http://infisical.localhost`
- `omi-api-local` remained healthy
- `twenty-server-1` remained healthy
- `infra-hoppscotch` remained healthy

## Important Operational Finding

The cutover introduced a persistent warning on every application database:

```text
database "<name>" has a collation version mismatch
DETAIL:  The database was created using collation version 2.41, but the operating system provides version 2.36.
```

Live inspection showed:

- all databases currently store `datcollversion = 2.41`
- the active runtime now reports `pg_database_collation_actual_version(...) = 2.36`
- the affected default collation is `en_US.utf8`
- the current runtime OS inside the container is Debian 12 (`bookworm`)

This means the shared Postgres data directory is currently running on a different libc/locale baseline than the one that originally created the databases.

## Current Risk Assessment

The stack is currently operational, but the warning is not cosmetic. PostgreSQL indicates that objects depending on the changed collation might need rebuilding before the catalog version is refreshed.

Examples from the live assessment:

- `infisical_db` has a large number of collatable user columns and many indexes on collatable columns
- `hoppscotch_db`, `twenty_db`, `omi_db`, and `audio2knowledge` also contain collatable user objects
- `postgres` and `second_brain` showed no user indexes on collatable columns in the initial triage

As long as no remediation has been run yet:

- do not silence the warning by running `ALTER DATABASE ... REFRESH COLLATION VERSION` alone
- treat text sort order, text comparisons, and indexes on text-like columns as the main risk area
- prefer planned follow-up work over ad-hoc changes in the live container

## Recommended Follow-up Direction

The remaining work is intentionally tracked separately in Beads so the stack can keep running while follow-up is planned safely.

The likely remediation paths are:

1. move to a pgvector image that matches the old collation runtime closely enough to eliminate the mismatch
2. stay on the current pgvector image and perform a planned database remediation:
   - identify affected indexes and objects per database
   - rebuild required objects
   - only then run `ALTER DATABASE ... REFRESH COLLATION VERSION`

Do not choose between these two paths ad hoc during normal app operation; treat it as planned database maintenance.
