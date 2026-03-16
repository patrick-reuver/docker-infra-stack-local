# Step 7: Infra Stack Bring-Up

The shared infrastructure stack was started with monitoring intentionally disabled.

## Scope

- Active services: `traefik`, `postgres`, `redis`, `minio`
- Inactive services: `prometheus`, `loki`, `promtail`, `grafana` (commented out by design)

## Preflight Checks

```bash
docker compose -f infra_stack_application/docker-compose.yml config
ls -la /Users/patrickreuver/_workspace/04_docker/infra-stack
```

Result:

- Compose config valid.
- Bind mount directories available under `/Users/patrickreuver/_workspace/04_docker/infra-stack`.

## Startup

```bash
docker compose -f infra_stack_application/docker-compose.yml up -d
docker compose -f infra_stack_application/docker-compose.yml ps
```

## Validation

```bash
curl -sSf -H "Host: traefik.localhost" http://localhost/ping
curl -sSf -H "Host: s3.localhost" http://localhost/minio/health/live
docker exec infra-postgres pg_isready -U postgres -d postgres
```

Observed status after startup:

- `infra-traefik`: running
- `infra-postgres`: healthy
- `infra-redis`: healthy
- `infra-minio`: healthy

## Current Runtime Ports

- `80` -> Traefik web entrypoint
- `5432` -> Postgres
- `6379` -> Redis

## Note (current routing model)

After introducing host-based routing through Traefik, direct host ports for MinIO and Traefik API are no longer required.

- MinIO Console: `http://minio.localhost`
- MinIO S3 API: `http://s3.localhost`
- Traefik dashboard: `http://traefik.localhost`
