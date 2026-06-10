# ClickHouse Analytics Database

ClickHouse deployment for analytical workloads in the docker-infra-stack. Primary consumer: Langfuse analytics.

## Services

| Service | Internal Port | External Host | Description |
|---------|--------------|---------------|-------------|
| clickhouse | 8123 (HTTP), 9000 (Native) | `clickhouse.localhost` | ClickHouse server |

## Quick Start

```bash
# From docker-infra-stack root
cd service_stack_application/clickhouse
cp .env.example .env
# Edit .env with Infisical Machine Identity bootstrap values
docker compose up -d
```

## Prerequisites

1. **Shared infra** must be running (`make infra-up`)
2. **Infisical** must be running with Machine Identity for `/clickhouse` path
3. **Database** `langfuse` created on ClickHouse (handled automatically)

## Configuration

Environment variables (Infisical bootstrap only — secrets fetched from Infisical at `/clickhouse`):

| Variable | Required | Description |
|----------|----------|-------------|
| `INFISICAL_AUTH_METHOD` | Yes | `universal-auth` |
| `INFISICAL_HOST_URL` | Yes | `http://infisical:8080` |
| `INFISICAL_PROJECT_ID` | Yes | Infisical project ID |
| `INFISICAL_ENV` | Yes | `local` |
| `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID` | Yes | Machine Identity Client ID |
| `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET` | Yes | Machine Identity Client Secret |
| `INFISICAL_SECRET_PATH` | No | Default: `/clickhouse` |

Secrets managed in Infisical at `/clickhouse`:
- `CLICKHOUSE_DB` — Database name (default: `langfuse`)
- `CLICKHOUSE_USER` — User (default: `langfuse`)
- `CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT` — `1` to enable

## Health Check

```bash
curl http://clickhouse.localhost/ping
# Returns: Ok.
```

## Data Persistence

Named volume `clickhouse_data` → `/var/lib/clickhouse`

## Network

Joins `infra_net` for internal DNS:
- `infisical:8080` (secret fetching at startup)

## Custom Build

Uses local `Dockerfile` with `clickhouse/clickhouse-server:24.8` base. Entry point wraps with `infisical-runtime-env.sh` for secret injection.

## Troubleshooting

**Container restarts immediately**: Check Infisical bootstrap credentials in `.env` — Machine Identity must have read access to `/clickhouse` in Infisical project.

**Cannot connect**: Verify `infra_net` exists (`docker network ls`) and ClickHouse container is healthy (`docker compose ps`).
