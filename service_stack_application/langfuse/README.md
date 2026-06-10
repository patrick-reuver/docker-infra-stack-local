# Langfuse LLM Observability

Langfuse deployment for LLM observability, tracing, and analytics in the docker-infra-stack.

## Services

| Service | Internal Port | External Host | Description |
|---------|--------------|---------------|-------------|
| langfuse-web | 3000 | `langfuse.localhost` | Web UI + API (traces, scores, datasets, prompts) |
| langfuse-worker | 3030 | internal only | Async processing for ingestion, ClickHouse writes, evaluations, exports |

## Quick Start

```bash
# From docker-infra-stack root
cd service_stack_application/langfuse
cp .env.example .env
# Edit .env with the Infisical Machine Identity bootstrap values.
# Provision database first:
# docker compose -f ../infra_stack_application/docker-compose.yml exec postgres psql -U apps_rw_user -d postgres -c "CREATE DATABASE langfuse_db;"
docker compose up -d
```

## Prerequisites

1. **Shared Postgres** must be running with `apps_rw_user` user
2. **Shared Redis** must be running; Langfuse isolates BullMQ/cache keys with `REDIS_KEY_PREFIX=langfuse`
3. **Database provisioning** - Create dedicated database:
   ```bash
   docker compose -f ../infra_stack_application/docker-compose.yml exec postgres psql -U apps_rw_user -d postgres -c "CREATE DATABASE langfuse_db;"
   ```
4. **Infisical secrets** - Configure application secrets at `/langfuse` path and Machine Identity bootstrap values in `.env`

## API Usage

### Health Check
```bash
curl http://langfuse.localhost/api/public/health
```

### Ingest Trace (via SDK recommended)
```python
from langfuse import Langfuse

langfuse = Langfuse(
    public_key="pk_lf_...",
    secret_key="sk_lf_...",
    host="http://langfuse.localhost"
)

trace = langfuse.trace(
    name="llm-call",
    input={"prompt": "Hello"},
    output={"response": "Hi there!"},
    metadata={"model": "gpt-4"}
)
```

### OpenTelemetry Integration
```bash
# Environment variables for OTel exporter
export OTEL_EXPORTER_OTLP_ENDPOINT=http://langfuse.localhost/api/public/otel
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <base64(public_key:secret_key)>"
```

## Configuration

Application environment variables managed via Infisical at `/langfuse`:
| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | PostgreSQL connection to `langfuse_db` |
| `POSTGRES_APP_USER` / `POSTGRES_APP_PASSWORD` | Alternative | Used by the runtime wrapper to derive Langfuse `DATABASE_USERNAME` / `DATABASE_PASSWORD` when `DATABASE_URL` is not stored directly |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_AUTH` | Yes | Shared Redis connection values loaded from Infisical |
| `REDIS_KEY_PREFIX` | Yes | Set in compose as `langfuse` so Langfuse BullMQ queues do not collide with other shared-Redis consumers such as Twenty CRM |
| `LANGFUSE_SALT` | Yes | Encryption salt (32 bytes base64) |
| `LANGFUSE_ENCRYPTION_KEY` / `ENCRYPTION_KEY` | Recommended | Langfuse v3 encryption key (64 hex chars); the runtime wrapper derives `ENCRYPTION_KEY` from `LANGFUSE_ENCRYPTION_KEY` when needed |
| `NEXTAUTH_SECRET` | Yes | NextAuth secret (32 bytes base64) |
| `LANGFUSE_PUBLIC_KEY` | After setup | Project public key |
| `LANGFUSE_SECRET_KEY` | After setup | Project secret key |
| `LANGFUSE_LOG_LEVEL` | No | Log level (default: `info`) |
| `S3_*` | No | MinIO/S3 for file storage |
| `CLICKHOUSE_*` | No | ClickHouse for analytics |
| `CLICKHOUSE_MIGRATION_URL` | Alternative | Derived from `CLICKHOUSE_URL` by the runtime wrapper when not stored directly |

## Database Provisioning

```bash
# Create dedicated database on shared Postgres
docker compose -f ../infra_stack_application/docker-compose.yml exec postgres psql -U apps_rw_user -d postgres -c "CREATE DATABASE langfuse_db;"

# Run migrations (handled automatically by Langfuse on first start)
```

## Redis Configuration

Langfuse uses the shared Redis instance with a dedicated key prefix:
- `REDIS_KEY_PREFIX=langfuse` is set in `docker-compose.yml`
- BullMQ queues are written under the Langfuse prefix instead of unprefixed names like `webhook-queue`
- This prevents collisions with other shared-Redis consumers, especially Twenty CRM, while keeping the central Redis service
- Cache, queue, and session data should be treated as Langfuse-owned only when the key carries this prefix

## Network

Service joins `infra_net` for internal DNS resolution:
- `postgres:5432` (shared Postgres)
- `redis:6379` (shared Redis)
- `minio:9000` (shared MinIO, optional for file storage)
- `clickhouse:8123` / `clickhouse:9000` (Langfuse analytics store)

## Health Checks

```bash
curl http://langfuse.localhost/api/public/health
# Returns: {"status":"ok"}
```

## First-Time Setup

1. Start Langfuse: `docker compose up -d`
2. Open `http://langfuse.localhost`
3. Create admin account
4. Create organization (e.g., "Digi-Pal")
5. Create project (e.g., "default") → Get `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY`
6. Add keys to Infisical at `/langfuse`
7. Restart Langfuse: `docker compose restart`

**Current Setup (as of 2026-06-10):**
- Organization: Digi-Pal
- Project: default
- Images: `langfuse/langfuse:3` and `langfuse/langfuse-worker:3`, wrapped only to load Infisical secrets at runtime
- Health check: `curl http://langfuse.localhost/api/public/health` -> `{"status":"OK","version":"3.182.0"}`
- Redis isolation: `REDIS_KEY_PREFIX=langfuse`
- Test trace verified after Redis-prefix rollout: `7399662c7342ef979d152215e6ecc43a`
- Langfuse skill installed (repo-backed from github.com/langfuse/skills)

## Consumer Integration

### LiteLLM Router
```yaml
# litellm config
callbacks: ["langfuse"]
langfuse_public_key: "pk_lf_..."
langfuse_secret_key: "sk_lf_..."
langfuse_host: "http://langfuse.localhost"
```

### Python SDK
```python
from langfuse import Langfuse
langfuse = Langfuse(host="http://langfuse.localhost", public_key=..., secret_key=...)
```

### OpenTelemetry
```python
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
exporter = OTLPSpanExporter(
    endpoint="http://langfuse.localhost/api/public/otel/v1/traces",
    headers={"Authorization": "Basic <base64(pk:sk)>"}
)
```

## Infisical Secrets

Project: `docker-infra-stack`
Environment slug: match `INFISICAL_ENV` in `.env` (currently `local`)
Path: `/langfuse`

Secrets are injected at container startup by the local runtime wrapper image. The `.env` file only contains the Universal Auth Machine Identity bootstrap values; Langfuse application secrets stay in Infisical. The wrapper accepts `INFISICAL_WORKSPACE_ID` or `INFISICAL_PROJECT_SLUG`; for the current local setup it also treats `INFISICAL_PROJECT_ID` as the workspace ID fallback.

The Machine Identity must be added to the Infisical project with read access to `/langfuse`. Organization-level identity access alone is not enough for project secret reads.

## Operational Notes

- Keep Web and Worker on the same `REDIS_KEY_PREFIX`; otherwise ingestion may enqueue jobs that the worker never sees.
- Do not remove `REDIS_KEY_PREFIX=langfuse` while Twenty CRM or other BullMQ services share `infra-redis`; unprefixed queue names can collide.
- The healthcheck intentionally targets `http://$(hostname):3000/api/public/health` because the upstream image binds to the container hostname in this setup.
