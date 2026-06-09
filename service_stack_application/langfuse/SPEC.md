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
- **Redis** (shared `infra-redis`) for queue, cache, session storage
- **MinIO** (shared `infra-minio`) for file storage (optional, for attachments)

## Requirements

### Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-01 | Run Langfuse Web UI (port 3000) | P0 |
| FR-02 | Run Langfuse API (port 3000) for ingestion | P0 |
| FR-03 | Run Langfuse Worker for async processing (clickhouse, scoring) | P0 |
| FR-04 | Use shared Postgres (`infra-postgres`) with dedicated DB `langfuse_db` | P0 |
| FR-05 | Use shared Redis (`infra-redis`) for queue/cache | P0 |
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

## Services (Langfuse v2.x)

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
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

# MinIO (shared, optional for file storage)
S3_ACCESS_KEY_ID=${MINIO_APPS_USER}
S3_SECRET_ACCESS_KEY=${MINIO_APPS_PASSWORD}
S3_ENDPOINT=http://minio:9000
S3_REGION=eu-central-1
S3_BUCKET=langfuse
S3_USE_SSL=false

# Auth & Security
NEXTAUTH_SECRET=${LANGFUSE_NEXTAUTH_SECRET}  # 32+ chars, generate with openssl
NEXTAUTH_URL=http://langfuse.localhost
LANGFUSE_SALT=${LANGFUSE_SALT}  # For encryption, 32+ chars
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

# ClickHouse (optional, for analytics)
CLICKHOUSE_ENABLED=false  # Disable for now, use Postgres only
```

### Docker Compose Structure
```yaml
services:
  langfuse-web:
    image: langfuse/langfuse:latest
    ports: ["3000:3000"]
    environment: [...]
    healthcheck: [...]
    networks: [infra_net]
    depends_on: [postgres, redis]
    labels: [traefik routing]

  langfuse-worker:
    image: langfuse/langfuse:latest
    command: worker
    environment: [...]
    networks: [infra_net]
    depends_on: [postgres, redis]
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
  - LANGFUSE_NEXTAUTH_SECRET (openssl rand -hex 32)
  - LANGFUSE_SALT (openssl rand -hex 32)
  - LANGFUSE_PUBLIC_KEY (langfuse generates, or custom)
  - LANGFUSE_SECRET_KEY (langfuse generates, or custom)
  - POSTGRES_APP_PASSWORD (from shared infra)
  - REDIS_PASSWORD (from shared infra)
  - MINIO_APPS_PASSWORD (from shared infra)
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