# Langfuse LLM Observability

Langfuse deployment for LLM observability, tracing, and analytics in the docker-infra-stack.

## Services

| Service | Internal Port | External Host | Description |
|---------|--------------|---------------|-------------|
| langfuse-web | 3000 | `langfuse.localhost` | Web UI + API (traces, scores, datasets, prompts) |

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
2. **Shared Redis** must be running
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
| `REDIS_URL` | Yes | Redis connection (DB 1) |
| `LANGFUSE_SALT` | Yes | Encryption salt (32 bytes base64) |
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

Langfuse uses Redis database 1 on the shared Redis instance:
- Cache for API responses
- Queue for background jobs (ingestion, scoring, etc.)
- Session storage

## Network

Service joins `infra_net` for internal DNS resolution:
- `postgres:5432` (shared Postgres)
- `redis:6379` (shared Redis)
- `minio:9000` (shared MinIO, optional for file storage)

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
- Health check: `curl http://langfuse.localhost/api/public/health` → `{"status":"OK","version":"3.180.0"}`
- Test trace verified: `cdbc2a9a881cd674fb6472f1f5a42569`
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
