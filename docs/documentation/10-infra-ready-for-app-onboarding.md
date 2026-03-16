# Step 10: Infra Ready for App Onboarding

The base infrastructure is running cleanly and is ready for onboarding the first application.

## Final Runtime Status

Services currently active:

- `infra-traefik`
- `infra-postgres`
- `infra-redis`
- `infra-minio`

Monitoring services remain intentionally disabled in Compose.

## Verification Commands

```bash
docker compose -f infra_stack_application/docker-compose.yml ps
curl -sSf http://localhost:8080/ping
curl -sSf http://localhost:9000/minio/health/live
docker exec infra-redis redis-cli -a "$REDIS_PASSWORD" ping
docker exec infra-postgres psql -U postgres -d postgres -c "SELECT datname FROM pg_database WHERE datname IN ('postgres','twenty_db');"
```

## Verification Results

- Postgres: healthy and contains `twenty_db`.
- Redis: authenticated ping returns `PONG`.
- MinIO: health endpoint is reachable.
- MinIO app user (`apps_s3_user`) can access bucket `twenty`.
- Traefik ping endpoint returns `OK`.

## Provisioned Runtime Inputs for First App

- Database user: `apps_rw_user`
- Database name: `twenty_db`
- MinIO app user: `apps_s3_user`
- MinIO bucket: `twenty`

These values are stored locally in `infra_stack_application/.env` and are intentionally not committed.

## Next Phase (Not Executed Yet)

Onboard `twenty-crm-application` to this shared infra by:

- removing app-local `db`, `redis`, and `minio` dependencies,
- connecting app services to `infra_net`,
- and mapping app env values to the provisioned shared resources.
