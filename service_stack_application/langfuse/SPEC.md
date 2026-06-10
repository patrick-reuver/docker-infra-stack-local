# Langfuse Observability — Specification

## Overview
Langfuse provides LLM observability: tracing, metrics, evaluations, and prompt management. Runs as central infrastructure in `docker-infra-stack`, accessible via `infra_net` to all consumers (LiteLLM Router, Hermes, Second Brain, Twenty CRM, etc.).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        infra_net                                │
├─────────────┬─────────────┬─────────────┬─────────────────────┤
│  Traefik    │  Postgres   │   Redis     │    Langfuse         │
│  (routing)  │  (shared)   │  (shared)   │  (Observability)    │
└─────────────┴─────────────┴─────────────┴─────────────────────┘
                                              │
                                              ▼
                                    ┌─────────────────────┐
                                    │  Consumers via      │
                                    │  langfuse.localhost │
                                    │  or internal DNS:   │
                                    │  langfuse:3000      │
                                    └─────────────────────┘
```

Langfuse uses:
- **Postgres** (shared `infra-postgres`) for persistent data (traces, scores, users, projects)
- **Redis** (shared `infra-redis`) for queue, cache, and session storage, isolated with `REDIS_KEY_PREFIX=langfuse`
- **ClickHouse** (dedicated `infra-clickhouse`) for analytics and trace/observation storage
- **MinIO** (shared `infra-minio`) for file and event upload storage

## Requirements

### Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-01 | Run Langfuse Web UI (port 3000) | P0 |
| FR-02 | Run Langfuse API (port 3000) for ingestion | P0 |
| FR-03 | Run Langfuse Worker for async processing (clickhouse, scoring) | P0 |
| FR-04 | Use shared Postgres (`infra-postgres`) with dedicated DB `langfuse_db` | P0 |
| FR-05 | Use shared Redis (`infra-redis`) for queue/cache with a Langfuse-specific key prefix | P0 |
| FR-06 | Expose via Traefik at `langfuse.localhost` | P0 |
| FR-07 | Store secrets (API keys, encryption keys, DB passwords) in Infisical | P0 |
| FR-08 | Support OpenTelemetry ingestion | P1 |
| FR-09 | Support LiteLLM callback integration | P1 |

### Non-Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-01 | Container startup < 60 seconds (includes DB migrations) | P1 |
| NFR-02 | Memory usage < 2GB total (web + worker) | P1 |
| NFR-03 | Ingestion latency < 200ms | P1 |
| NFR-04 | Support graceful shutdown with queue drain | P1 |
| NFR-05 | Structured logging (JSON) | P2 |
| NFR-06 | Data retention configurable | P2 |

## Services (Langfuse v3)

### langfuse-web
- Web UI + API server
- Port: 3000
- Runs DB migrations on startup
- Handles: UI, API ingestion, authentication, project management

### langfuse-worker
- Background job processor
- Handles: ClickHouse sync, scoring, evaluations, export jobs
- No external port

## Configuration

### Environment Variables (from Infisical)
```bash
# Database (shared Postgres)
DATABASE_URL=postgresql://apps_rw_user:${POSTGRES_APP_PASSWORD}@postgres:5432/langfuse_db
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=langfuse_db
POSTGRES_USER=apps_rw_user
POSTGRES_PASSWORD=${POSTGRES_APP_PASSWORD}

# Redis (shared)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_AUTH=${REDIS_PASSWORD}
REDIS_KEY_PREFIX=langfuse

# MinIO/S3 (shared)
LANGFUSE_S3_EVENT_UPLOAD_BUCKET=langfuse
LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT=http://minio:9000
LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE=true
LANGFUSE_S3_MEDIA_UPLOAD_BUCKET=langfuse
LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT=http://minio:9000
LANGFUSE_S3_MEDIA_UPLOAD_FORCE_PATH_STYLE=true

# Auth & Security
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}  # 32+ chars, generate with openssl
NEXTAUTH_URL=http://langfuse.localhost
LANGFUSE_SALT=${LANGFUSE_SALT}  # For encryption, 32+ chars
LANGFUSE_ENCRYPTION_KEY=${LANGFUSE_ENCRYPTION_KEY}  # 64 hex chars, mapped to ENCRYPTION_KEY by wrapper
LANGFUSE_PUBLIC_KEY=${LANGFUSE_PUBLIC_KEY}  # For API auth
LANGFUSE_SECRET_KEY=${LANGFUSE_SECRET_KEY}  # For API auth

# Application
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
NEXT_TELEMETRY_DISABLED=1

# Features
LANGFUSE_ENABLE_OAUTH=false
LANGFUSE_DISABLE_SIGNUP=true  # Only invited users
LANGFUSE_TRUST_PROXY=true  # Behind Traefik

# ClickHouse
CLICKHOUSE_URL=http://clickhouse:8123
CLICKHOUSE_MIGRATION_URL=clickhouse://clickhouse:9000
CLICKHOUSE_USER=langfuse
CLICKHOUSE_DB=langfuse
CLICKHOUSE_CLUSTER_ENABLED=false
```

### Docker Compose Structure
```yaml
services:
  langfuse-web:
    image: infra-langfuse:local  # wraps langfuse/langfuse:3
    environment: *langfuse-env
    healthcheck: [...]
    networks: [infra_net]
    labels: [traefik routing]

  langfuse-worker:
    image: infra-langfuse-worker:local  # wraps langfuse/langfuse-worker:3
    command: ["node", "worker/dist/index.js"]
    environment: *langfuse-env
    networks: [infra_net]
```

## Traefik Routing
- `langfuse.localhost` → Web UI + API (port 3000)
- WebSocket support for real-time updates
- Path-based: `/api/*` for ingestion, `/` for UI

## Infisical Secrets Structure
```
Project: docker-infra-stack
Environment: development
Path: /langfuse
Secrets:
  - NEXTAUTH_SECRET (openssl rand -base64 32)
  - LANGFUSE_SALT (openssl rand -hex 32)
  - LANGFUSE_ENCRYPTION_KEY (openssl rand -hex 32)
  - LANGFUSE_PUBLIC_KEY (langfuse generates, or custom)
  - LANGFUSE_SECRET_KEY (langfuse generates, or custom)
  - POSTGRES_APP_PASSWORD (from shared infra)
  - REDIS_PASSWORD (from shared infra)
  - CLICKHOUSE_PASSWORD (from ClickHouse setup)
  - LANGFUSE_S3_EVENT_UPLOAD_* (shared MinIO access)
```

## Database Provisioning
- Database `langfuse_db` must exist in shared Postgres
- User `apps_rw_user` must have CREATE/CONNECT privileges
- Langfuse runs migrations automatically on web startup
- No separate migration container needed

## Testing Strategy (TDD)

### Unit Tests
- [ ] Environment variable validation
- [ ] Database connection string construction
- [ ] Redis connection string construction
- [ ] Redis key prefix prevents BullMQ queue collisions with other shared-Redis consumers
- [ ] MinIO/S3 config construction

### Integration Tests
- [ ] Docker compose starts web + worker healthy
- [ ] Postgres migrations run successfully
- [ ] Traefik routes `langfuse.localhost` → web
- [ ] Web UI accessible at `langfuse.localhost`
- [ ] API ingestion endpoint accepts traces
- [ ] Worker processes background jobs
- [ ] Infisical secrets injected correctly
- [ ] Shared Postgres/Redis/MinIO accessible

### E2E Tests (with LiteLLM later)
- [ ] LiteLLM callback sends trace to Langfuse
- [ ] Trace visible in Langfuse UI
- [ ] Cost/latency metrics recorded
- [ ] User feedback scores recorded

## Acceptance Criteria
1. `docker compose -f langfuse/docker-compose.yml up -d` starts web + worker
2. `curl langfuse.localhost/api/public/health` returns 200
3. Web UI loads at `langfuse.localhost`
4. Postgres migrations complete without errors
5. Worker processes jobs (check logs)
6. Services accessible via `infra_net` internal DNS (`langfuse-web:3000`)
7. Secrets managed via Infisical (no hardcoded values)
8. Infrastructure.md and tools-and-services.md updated
9. Database `langfuse_db` provisioned in shared Postgres
10. A trace ingested through `/api/public/ingestion` is readable through `/api/public/traces/{traceId}`
