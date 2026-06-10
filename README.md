# docker-infra-stack

Self-hosted infrastructure stack for local development and production workloads. Runs on Docker Compose with Traefik routing, shared Postgres/Redis/MinIO, and Infisical for secret management.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        docker-infra-stack                        │
├─────────────────────────────────────────────────────────────────┤
│  infra_stack_application/          service_stack_application/   │
│  ┌─────────────────────────┐      ┌─────────────────────────┐   │
│  │ Single compose stack    │      │ Independent compose     │   │
│  │ • Traefik (reverse proxy)│      │   stacks per service    │   │
│  │ • Postgres (pgvector)   │      │ • ClickHouse            │   │
│  │ • Redis                 │      │ • Langfuse              │   │
│  │ • MinIO (S3)            │      │ • Presidio PII          │   │
│  └─────────────────────────┘      │ • Infisical (+ MCP)     │   │
│                                   └─────────────────────────┘   │
│                                          │                        │
│                              ┌───────────┴───────────┐          │
│                              │   Shared infra_net    │          │
│                              │   (external network)  │          │
│                              └───────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Clone and enter
git clone https://github.com/patrick-reuver/docker-infra-stack-local.git
cd docker-infra-stack

# 2. Create .env files from templates
make env-example

# 3. Edit .env files with your values (Infisical bootstrap credentials, etc.)
#    See each service's .env.example for required variables

# 4. Start infrastructure (Traefik, Postgres, Redis, MinIO)
make infra-up

# 5. Provision databases
make db-provision

# 6. Start services (independent, start what you need)
make clickhouse   # or: make langfuse, make presidio, make infisical

# 7. Verify health
make health
```

## Directory Structure

```
docker-infra-stack/
├── Makefile                          # Unified operations
├── .env.example                      # Root environment template
├── .gitignore                        # Security-hardened
├── infrastructure.md                 # Architecture & network docs
├── tools-and-services.md             # Tool/service inventory
├── databases.md                      # Postgres database inventory
├── infra_stack_application/          # Shared infrastructure (1 compose)
│   ├── docker-compose.yml
│   ├── .env.example
│   └── docker-compose.collation-remediation.yml
└── service_stack_application/        # Independent service stacks
    ├── clickhouse/                   # ClickHouse analytics DB
    │   ├── docker-compose.yml
    │   ├── Dockerfile
    │   ├── .env.example
    │   └── docker-compose.clickhouse.yml
    ├── infisical/                    # Infisical secret manager
    │   ├── docker-compose.yml
    │   ├── .env.example
    │   ├── README.md
    │   ├── scripts/init-db.sh
    │   └── infisical-mcp/            # MCP bridge for Codex/agents
    ├── langfuse/                     # LLM observability
    │   ├── docker-compose.yml
    │   ├── Dockerfile
    │   ├── .env.example
    │   ├── README.md
    │   └── SPEC.md
    └── presidio/                     # PII detection/anonymization
        ├── docker-compose.yml
        ├── Dockerfile
        ├── .env.example
        ├── README.md
        ├── SPEC.md
        └── custom_recognizers/
```

## Secret Management Model

**Production / Standard Local**: All application secrets stored in **Infisical** at paths:
- `/langfuse` — Langfuse keys, DB/Redis/ClickHouse/S3 credentials, salts, encryption keys
- `/presidio` — Presidio config, model settings
- `/clickhouse` — ClickHouse credentials
- `/infisical` — Infisical app encryption/auth keys

Each service container starts with only **Machine Identity bootstrap credentials** in `.env`:
- `INFISICAL_HOST_URL`, `INFISICAL_PROJECT_ID`, `INFISICAL_ENV`
- `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`, `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET`

The runtime wrapper `scripts/infisical-runtime-env.sh` fetches secrets from Infisical at startup and injects them as environment variables.

**Fallback (no Infisical)**: Root `.env.example` documents all application secrets inline for local dev without Infisical. Commented out by default.

## Services

| Service | Port (Internal) | Host (Traefik) | Description |
|---------|----------------|----------------|-------------|
| Traefik | 80 | `traefik.localhost` | Reverse proxy + dashboard |
| Postgres | 5432 | `postgres.localhost` | pgvector/pg16, shared |
| Redis | 6379 | `redis.localhost` | Shared, password-protected |
| MinIO | 9000/9001 | `minio.localhost` / `s3.localhost` | S3-compatible object storage |
| ClickHouse | 8123 | `clickhouse.localhost` | Analytics DB for Langfuse |
| Langfuse | 3000 | `langfuse.localhost` | LLM observability, tracing |
| Presidio Analyzer | 3000 | `presidio.localhost` | PII detection API |
| Presidio Anonymizer | 3000 | `presidio-anonymizer.localhost` | Anonymization API |
| Infisical | 8080 | `infisical.localhost` | Secret management UI + API |

## Makefile Commands

```bash
make help           # Show all commands
make infra-up       # Start infra stack
make infra-down     # Stop infra stack
make infra-ps       # Infra status
make svc-up SVC=langfuse   # Start service
make clickhouse     # Shortcut for clickhouse
make langfuse       # Shortcut for langfuse
make all-up         # Infra + all services
make all-down       # Stop everything
make env-example    # Create all .env from .env.example
make db-provision   # Create required databases
make health         # Check all endpoints
make clean          # Nuclear: remove containers, volumes, network
```

## Network

All services join the external Docker network `infra_net` (created automatically by infra stack). Internal DNS:
- `postgres:5432`, `redis:6379`, `minio:9000`, `infisical:8080`, `clickhouse:8123`

## Documentation

- `infrastructure.md` — Network, volumes, Traefik routing, shared credentials
- `tools-and-services.md` — Complete tool/service inventory with versions
- `databases.md` — Postgres database inventory per application
- Each service has its own `README.md` with API usage, config, and Infisical paths

## Infisical MCP Bridge (Codex/Agents)

Located at `service_stack_application/infisical/infisical-mcp/`. Provides MCP server for Codex to read/write Infisical secrets.

- Two profiles: `codex-readonly` (discovery, reads) and `codex-admin` (writes, project creation)
- Authenticates via Organization Machine Identity + Universal Auth
- See `service_stack_application/infisical/infisical-mcp/README.md` for setup

## Requirements

- Docker Engine + Docker Compose v2
- `infra_net` network (auto-created by `make infra-up`)
- For Infisical mode: Running Infisical instance with Machine Identities configured
- `openssl` for secret generation (`openssl rand -hex 32`)

## License

MIT — Internal use, publish-ready when public.
