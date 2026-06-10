# Infisical Secret Manager

Infisical deployment for centralized secret management in the docker-infra-stack. Provides UI, API, and MCP bridge for agent integration.

## Services

| Service | Internal Port | External Host | Description |
|---------|--------------|---------------|-------------|
| infisical | 8080 | `infisical.localhost` | Infisical web UI + API |

## Quick Start

```bash
# From docker-infra-stack root
cd service_stack_application/infisical
cp .env.example .env
# Edit .env with secure values (ENCRYPTION_KEY, AUTH_SECRET, DB creds)
docker compose up -d

# First-time setup:
# 1. Open http://infisical.localhost
# 2. Create admin account
# 3. Create project "docker-infra-stack"
# 4. Create Machine Identities for each service (Universal Auth)
# 5. Add secrets to paths: /langfuse, /presidio, /clickhouse, /infisical
```

## Prerequisites

1. **Shared Postgres** must be running with `apps_rw_user`
2. **Shared Redis** must be running
3. **Database provisioning** — Create dedicated database:
   ```bash
   docker compose -f ../infra_stack_application/docker-compose.yml exec postgres psql -U apps_rw_user -d postgres -c "CREATE DATABASE infisical_db;"
   ```
   Or use the init script: `./scripts/init-db.sh`

## Configuration

### Application secrets (in `.env` — NOT Infisical, these bootstrap Infisical itself):

| Variable | Required | Description |
|----------|----------|-------------|
| `SITE_URL` | Yes | Public URL via Traefik (e.g., `http://infisical.localhost`) |
| `POSTGRES_ADMIN_USER` | Yes | `postgres` |
| `POSTGRES_ADMIN_PASSWORD` | Yes | Postgres admin password |
| `DB_HOST` | Yes | `postgres` |
| `DB_PORT` | Yes | `5432` |
| `DB_NAME` | Yes | `infisical_db` |
| `DB_USER` | Yes | `apps_rw_user` |
| `DB_PASSWORD` | Yes | App runtime password |
| `DB_PASSWORD_URLENCODED` | Yes | URL-encoded version of above |
| `REDIS_HOST` | Yes | `redis` |
| `REDIS_PORT` | Yes | `6379` |
| `REDIS_PASSWORD` | Yes | Redis password |
| `ENCRYPTION_KEY` | Yes | 32+ hex chars (generate: `openssl rand -hex 32`) |
| `AUTH_SECRET` | Yes | Base64 secret (generate: `openssl rand -base64 32`) |
| `INFISICAL_IMAGE_TAG` | No | Docker image tag (default: `latest`) |

### Machine Identity Bootstrap (for other services to read from Infisical):

Created in Infisical UI: **Project Settings → Machine Identities → Universal Auth**
- One per service: `clickhouse`, `langfuse`, `presidio`, `infisical-mcp-readonly`, `infisical-mcp-admin`
- Each gets: `Client ID`, `Client Secret`
- Add to respective service's `.env` as:
  - `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`
  - `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET`

## Health Check

```bash
curl http://infisical.localhost/api/status
# Returns: {"status":"ok"}
```

## Infisical MCP Bridge (Codex/Agents)

Located in `infisical-mcp/`. Separate compose stack for MCP server connecting Codex to this Infisical instance.

### Two Profiles

| Profile | Purpose | Machine Identity |
|---------|---------|------------------|
| `codex-readonly` | Discovery, reads (`list-projects`, `list-secrets`, `get-secret`) | Org role: minimal; Project role: read-only |
| `codex-admin` | Writes (`create-secret`, `update-secret`, `create-project`, etc.) | Org role: Admin/custom; Project role: Admin/write |

### Setup

```bash
cd infisical-mcp
cp .env.readonly.example .env.readonly
cp .env.admin.example .env.admin
# Fill in Client ID/Secret for each Machine Identity
```

### Codex Registration

Use `docker compose run --rm` with the appropriate env file. See `codex-mcp-server.example.json` for MCP server config.

### Validated Project Types for `list-projects`

Use concrete types — `all` does not work on self-hosted:
- `secret-manager`, `cert-manager`, `kms`, `ssh`, `secret-scanning`, `pam`, `ai`

## Network

Joins `infra_net` for internal DNS:
- `postgres:5432`, `redis:6379`

## Data Persistence

- Postgres: Shared `infra-postgres` (database `infisical_db`)
- Redis: Shared `infra-redis` (database 0)
- MinIO: Optional, for object storage (not configured by default)

## Troubleshooting

**Zod error for `INFISICAL_TOKEN`**: Remove `INFISICAL_TOKEN` from container env when using `universal-auth`.

**`list-projects` fails with `type="all"`**: Use concrete type (see validated types above).

**Universal Auth returns 401**: Verify Client ID (not Machine Identity ID) and Client Secret match. Restart MCP session to pick up updated `.env`.

## Operational Notes

- Prefer `http://infisical:8080` inside Docker; `http://infisical.localhost` for host tools
- Machine Identity must be added to **specific project** for secret access (org-level alone insufficient)
- Rotate Universal Auth credentials in Infisical if ever exposed
- MCP bridge runs ephemeral (`docker compose run --rm`) — not persistent sidecars
