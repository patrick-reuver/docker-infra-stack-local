# OmniRoute Service

## Service

| Service | Internal Port | External Host | Description |
|---|---:|---|---|
| omniroute | 20128 / 20129 | `omniroute.localhost` | AI gateway dashboard and OpenAI-compatible API bridge |

## Quick Start

```bash
cd /Users/patrickreuver/_workspace/02_coding/docker-infra-stack
docker compose --env-file infra_stack_application/.env -f service_stack_application/omniroute/omniroute.yml up -d
open http://omniroute.localhost/dashboard/
```

## Shared Infrastructure

- Traefik routes `omniroute.localhost` to container port `20128`.
- Redis reuses shared `infra-redis` with database index `/2`.
- Persistent SQLite/data files live on the host at `/Users/patrickreuver/_workspace/04_docker/infra-stack/omniroute` and are mounted to `/app/data`.
- No separate OmniRoute source checkout is required for runtime; the compose file uses the published Docker image.

## Health Check

The upstream `healthcheck.mjs` timed out against the current image. The compose healthcheck therefore checks the dashboard route inside the container:

```bash
docker inspect infra-omniroute --format '{{.State.Health.Status}}'
curl -L -H 'Host: omniroute.localhost' http://localhost/dashboard/
```
