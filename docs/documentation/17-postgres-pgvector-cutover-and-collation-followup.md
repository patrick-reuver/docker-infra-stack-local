# Step 17: Postgres pgvector Cutover and Collation Follow-up

This run documents the live cutover of the shared `infra-postgres` service from `postgres:16` to `pgvector/pgvector:pg16`, the validation steps that were executed afterwards, and the now-validated remediation workflow for the collation drift introduced by the new container image.

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

## Validated Remediation Direction

The validated path is to stay on `pgvector/pgvector:pg16` and repair the databases rather than trying to find a pgvector image with the old locale baseline.

The repository now contains a dedicated isolation toolkit for this maintenance:

- `infra_stack_application/docker-compose.collation-remediation.yml`
- `scripts/postgres-clone-pgdata.sh`
- `scripts/postgres-collation-inventory.sh`
- `scripts/postgres-collation-remediate.sh`
- `scripts/postgres-collation-validate.sh`

## Isolated Validation Run

The remediation workflow was executed first against a cloned copy of the live PGDATA directory in `/private/tmp/infra-postgres-collation-remediation`, not against the live bind mount.

Commands used:

```bash
scripts/postgres-clone-pgdata.sh \
  /Users/patrickreuver/_workspace/04_docker/infra-stack/postgres \
  /private/tmp/infra-postgres-collation-remediation

PGDATA_CLONE_PATH=/private/tmp/infra-postgres-collation-remediation \
  docker compose -f infra_stack_application/docker-compose.collation-remediation.yml up -d

scripts/postgres-collation-inventory.sh infra-postgres-collation-test
scripts/postgres-collation-remediate.sh infra-postgres-collation-test
scripts/postgres-collation-validate.sh infra-postgres-collation-test
```

Before remediation, the isolated copy reproduced the same mismatch on all relevant databases:

- `audio2knowledge`
- `hoppscotch_db`
- `infisical_db`
- `omi_db`
- `postgres`
- `second_brain`
- `template1`
- `twenty_db`

Inventory highlights from the isolated run:

- `infisical_db`: `5531` collatable columns, `1369` collatable indexes
- `hoppscotch_db`: `95` collatable columns, `48` collatable indexes
- `twenty_db`: `356` collatable columns, `32` collatable indexes
- `omi_db`: `27` collatable columns, `12` collatable indexes
- `audio2knowledge`: `22` collatable columns, `1` collatable index
- `postgres`: `0` collatable columns, `0` collatable indexes
- `second_brain`: `1` collatable column, `0` collatable indexes
- `template1`: `0` collatable columns, `0` collatable indexes

## Verified Remediation Sequence

The successful isolated run used this sequence for every database except `template0`:

1. connect to the target database
2. run `REINDEX DATABASE "<db>"`
3. connect through `postgres`
4. run `ALTER DATABASE "<db>" REFRESH COLLATION VERSION`

`template1` was included intentionally so future databases do not inherit the stale collation version.

## Verified Outcome

After remediation on the isolated copy:

- every affected database reported `datcollversion = 2.36`
- `pg_database_collation_actual_version(...)` also reported `2.36`
- `psql` connections no longer emitted collation mismatch warnings

Validated final state:

```text
audio2knowledge  2.36  2.36
hoppscotch_db    2.36  2.36
infisical_db     2.36  2.36
omi_db           2.36  2.36
postgres         2.36  2.36
second_brain     2.36  2.36
template1        2.36  2.36
twenty_db        2.36  2.36
```

Additional smoke checks against the remediated isolated container succeeded for:

- `infisical_db` index metadata queries
- `twenty_db` table metadata queries

## Live Run Guidance

When applying the same fix to the live shared Postgres volume:

1. stop or isolate application writers as needed for the maintenance window
2. create a fresh backup or filesystem snapshot of the live PGDATA directory
3. run the same inventory, remediation, and validation sequence against the live `infra-postgres`
4. only return consumers to normal write traffic after the validation script completes without warnings

This should be treated as planned maintenance, but the isolated validation confirms that a database-wide reindex followed by collation version refresh is the correct repair path for the current shared stack.

## Live Execution Result

After the isolated test environment was re-verified as healthy, warning-free, and `pgvector`-capable, the same remediation sequence was executed successfully against the live `infra-postgres` instance.

Live post-checks confirmed:

- all remediated databases now report `2.36` as both `datcollversion` and `pg_database_collation_actual_version(...)`
- `scripts/postgres-collation-validate.sh infra-postgres` completed without mismatch warnings
- `pgvector` is available on the live instance and a simple vector distance operation succeeded after `CREATE EXTENSION IF NOT EXISTS vector`
- no new `infra-postgres` log output appeared after the post-remediation checks
- the known consumers `twenty-server-1`, `infra-infisical`, `omi-api-local`, and `infra-hoppscotch` remained running after the maintenance

This follow-up item is therefore complete: the shared databases now run without the collation mismatch warning on the live stack as well as in the isolated validation environment.
