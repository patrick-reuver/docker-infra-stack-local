# Step 16: Twenty CRM Cutover to Shared Infra

This runbook documents the executed cutover of Twenty CRM to the shared infra stack.

## Scope

- App repository path moved to `/Users/patrickreuver/_workspace/02_coding/twenty-crm`.
- Twenty runtime now uses shared infra services on `infra_net`:
  - Postgres: `postgres:5432` (`twenty_db`)
  - Redis: `redis:6379`
  - MinIO S3 API: `minio:9000` (bucket `twenty`)
- Browser access now routes through Traefik host routing:
  - `http://twentycrm.localhost`

## Application Changes (in Twenty repo)

File: `twenty-crm-application/docker-compose.yml`

- Removed app-local services: `db`, `redis`, `minio`, `create-buckets`.
- Kept only `server` and `worker`.
- Added external network `infra_net`.
- Added Traefik labels for `twentycrm.localhost` on `server`.
- Removed direct host port publishing for `server`.

File: `twenty-crm-application/.env`

- Mapped runtime credentials to shared infra values.
- Updated `SERVER_URL` to `http://twentycrm.localhost`.
- Updated `DATA_PATH` to `/Users/patrickreuver/_workspace/04_docker/twenty-crm`.
- Added URL-safe DSN (`PG_DATABASE_URL`) to handle special characters in DB password.

## Data Migration (executed)

### 1) Bind mount base path migration

- Source: `/Users/patrickreuver/_docker-bind-mounts-volumes/twenty-crm`
- Target: `/Users/patrickreuver/_workspace/04_docker/twenty-crm`
- Method: `rsync -a`

### 2) Postgres migration

- Started temporary legacy DB container mounted to migrated legacy data.
- Dumped legacy DB with neutral ownership flags:
  - `pg_dump --no-owner --no-acl -U postgres -d default`
- Recreated `twenty_db` in infra Postgres (owner `apps_rw_user`).
- Restored dump into infra `twenty_db` as `apps_rw_user`.

### 3) MinIO bucket migration

- Mirrored `src/twenty` to `dst/twenty` using `minio/mc`.
- Verified with `mc diff src/twenty dst/twenty`.
- Diff output showed only one extra destination object:
  - `infra-check.txt` (pre-existing infra validation artifact)

## Verification Results

- `docker compose ... ps` in Twenty project shows:
  - `twenty-server-1` healthy
  - `twenty-worker-1` running
- `curl -H "Host: twentycrm.localhost" http://localhost/healthz` returns `200`.
- `curl -I -H "Host: twentycrm.localhost" http://localhost` returns `200 OK`.
- Server and worker logs show successful startup and active job processing.

## Important Boundary Confirmation

- No runtime stack changes were made to `infra_stack_application/docker-compose.yml`.
- Shared infra services remained unchanged and were reused as-is.
