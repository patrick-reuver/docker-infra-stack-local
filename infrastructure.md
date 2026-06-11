# Infrastructure Overview

This repository contains the shared Docker infrastructure stack that other local application repositories can connect to when they need central routing or shared runtime services. It is the entry document for the stack shape, connected consumers, and where to find the deeper runbooks.

## Repository Scope

The stack is defined in `infra_stack_application/docker-compose.yml` and currently provides these central services:

- `traefik` for HTTP routing via Docker labels
- `postgres` as the shared relational database instance
- `redis` as the shared runtime cache / broker
- `minio` as the shared S3-compatible object storage

The repository also contains additional shared service compose projects:

- `infisical` as the shared secret management service for local tools and agents, defined in `infisical/docker-compose.yml`
- `infisical-mcp` as the dedicated MCP bridge for Codex and other MCP clients, defined in `infisical-mcp/docker-compose.yml`
- `presidio` as the PII detection and anonymization service, defined in `presidio/docker-compose.yml`
- `langfuse` as the LLM observability and tracing platform, defined in `langfuse/docker-compose.yml`

The compose file also contains optional observability services that are currently present but commented out:

- `prometheus`
- `loki`
- `promtail`
- `grafana`

## Network Model

`infra_net` is the central external Docker network for this environment. Shared infra services join this network permanently. Other application stacks stay isolated in their own services and networks by default and should only join `infra_net` when they actually need shared infrastructure, for example:

- access to the central Postgres instance
- access to shared Redis
- access to shared MinIO / S3
- access to shared secret management
- exposure through shared Traefik routing

Within Docker, connected application containers should use internal DNS names:

- `postgres:5432`
- `redis:6379`
- `minio:9000`
- `infisical:8080`
- `infisical-mcp` for the dedicated MCP bridge container

## Routing via Traefik

Traefik is the shared HTTP entrypoint and currently routes these infra endpoints:

- `http://traefik.localhost` -> Traefik dashboard
- `http://minio.localhost` -> MinIO console
- `http://s3.localhost` -> MinIO S3 API
- `http://infisical.localhost` -> Infisical UI and API
- `http://presidio.localhost` -> Presidio Analyzer API (PII detection)
- `http://presidio-anonymizer.localhost` -> Presidio Anonymizer API (anonymization/de-anonymization)
- `http://langfuse.localhost` -> Langfuse UI and API (LLM observability)
- `http://honcho.localhost` -> Honcho API (Second Brain Memory Layer)

Consumer routes that are currently live or configured in the local workspace:

- `http://twentycrm.localhost`
- `http://omi-api.localhost`
- `http://a2k.localhost`
- `http://api.a2k.localhost`
- `http://flower.a2k.localhost`
- `http://excalidraw.localhost`
- `http://drawio.localhost`
- `http://fossflow.localhost`

## Shared Data Services

### Postgres

Postgres is operated as one central instance with multiple application databases. The credential model separates provisioning from normal application writes:

- admin user: `POSTGRES_USER`
  - used for provisioning and maintenance only
- shared runtime write user: `POSTGRES_APP_USER`
  - current value in the env template: `apps_rw_user`

The shared runtime model is one writable runtime user with separate databases per application. The current template already includes:

- default admin database: `POSTGRES_DEFAULT_DB=postgres`
- Twenty CRM database mapping: `TWENTY_POSTGRES_DB=twenty_db`
- Infisical database mapping: `INFISICAL_POSTGRES_DB=infisical_db`

The central Postgres container now uses a Postgres 16 image with `pgvector` included. This makes the extension reproducibly available after container rebuilds or recreates without changing ports, credentials, or the shared data volume layout.

`pgvector` availability does not auto-enable it inside every database. Applications or operators must still activate it per database with `CREATE EXTENSION vector;` where vector storage and similarity search are needed.

The first live cutover to the pgvector-enabled image kept all databases reachable, but it also exposed a collation-version drift between the historical data directory and the current container runtime. That drift has now been remediated in the live shared database volume through a maintenance workflow that was first exercised against an isolated copy of PGDATA.

The validated remediation path is:

1. clone the current PGDATA directory into an isolated temporary location
2. start the dedicated remediation compose file against that clone
3. inventory collatable objects per database
4. run `REINDEX DATABASE` for every database except `template0`
5. run `ALTER DATABASE ... REFRESH COLLATION VERSION` for every remediated database, including `template1`
6. verify that `datcollversion` matches `pg_database_collation_actual_version(...)` everywhere and that no collation mismatch warnings remain

The same sequence has now been applied successfully to the live `infra-postgres` instance. The shared databases `audio2knowledge`, `hoppscotch_db`, `infisical_db`, `omi_db`, `postgres`, `second_brain`, `template1`, and `twenty_db` now report matching collation versions again, and a live `pgvector` smoke test succeeds without reintroducing warnings.

The repository now contains the supporting toolkit for this flow:

- isolated test compose file: `infra_stack_application/docker-compose.collation-remediation.yml`
- PGDATA clone helper: `scripts/postgres-clone-pgdata.sh`
- inventory helper: `scripts/postgres-collation-inventory.sh`
- remediation helper: `scripts/postgres-collation-remediate.sh`
- validation helper: `scripts/postgres-collation-validate.sh`

Twenty CRM is the documented consumer for `twenty_db`. Existing runbooks also describe provisioning and cutover for this database.

### Redis

Redis is provided as a shared runtime service on `redis:6379`. Connected applications reuse the same central instance instead of bringing their own Redis container unless there is a specific reason to isolate it.

Infisical also uses the shared Redis instance for its runtime cache and background coordination.

### MinIO

MinIO is the shared S3-compatible object storage service. The env template separates:

- admin credentials for provisioning
- shared runtime credentials for application access

Per-app storage should be separated by bucket. The current template already includes the Twenty CRM bucket mapping:

- `TWENTY_MINIO_BUCKET=twenty`

## Shared Secret Management

### Infisical

Infisical is the shared secret management layer for this local environment. Its purpose is to give tools, agents, and application stacks a central place to retrieve API credentials and other secrets without hard-exposing them in repository files or ad-hoc local environment files.

The local deployment model is intentionally small and reuses the existing infra primitives:

- compose file: `infisical/docker-compose.yml`
- route: `http://infisical.localhost`
- network: `infra_net`
- dependencies: shared `postgres` and shared `redis`
- dedicated database: `infisical_db`

The `infisical/` folder also contains an idempotent one-shot database initialization step so the dedicated database can be created reproducibly against the shared Postgres instance by the existing runtime DB user.

The initial rollout covers the Infisical application only. The later MCP integration should use the official Infisical MCP server as a separate process or container pointed at the local Infisical host URL.

### Infisical MCP Bridge

The Infisical MCP integration for Codex is designed as a separate Docker service rather than being embedded into the main Infisical container. This keeps the trust boundary explicit: the application service continues to host the secrets platform, while the MCP bridge exposes AI-facing tools through a dedicated runtime.

- compose file: `infisical-mcp/docker-compose.yml`
- network: `infra_net`
- runtime target: `http://infisical:8080` from inside Docker
- client target: Codex or another MCP client connects to the dedicated MCP bridge process
- authentication model: Infisical Organization Machine Identity via Universal Auth

The local Codex desktop setup is now configured as one of these MCP clients. Codex reaches the self-hosted Infisical instance through the dedicated `infisical-mcp` bridge and authenticates there with a machine identity rather than with an interactive user account.

The preferred operating model is now a two-identity setup:

- `codex-readonly` for day-to-day discovery and read operations
- `codex-admin` for deliberate write operations such as project creation and secret changes

Operationally, the persistent base layer is the shared `infisical-mcp` service definition. The readonly and admin Codex profiles are expected to run on demand as short-lived `docker compose run --rm ...` MCP processes rather than as always-on dedicated containers.

Both are Organization Machine Identities. The admin identity needs organization-level permission to create projects and project-level membership in any project where it should create or edit secrets, folders, or environments.

The preferred network path is internal Docker DNS (`infisical:8080`) instead of the Traefik hostname because the MCP container lives on the same shared network and does not need to hairpin through the external HTTP route.

The intended rollout is phased:

- Phase 1: read-only or limited pilot validation for `list-projects`, `list-secrets`, and `get-secret`
- Phase 2: explicit write enablement for operations such as secret CRUD, environment creation, folder creation, and project creation

Because the official `@infisical/mcp` server supports write operations, any production-like enablement of this bridge must treat machine identity scope and role assignment as part of the infrastructure change itself.

## PII Detection & Anonymization (Presidio)

Presidio provides centralized PII detection and anonymization for all consumers in the infrastructure stack. It runs as two services on `infra_net`:

- **Analyzer** (`presidio-analyzer:3000`, routed via `presidio.localhost`) — Detects PII entities in text
- **Anonymizer** (`presidio-anonymizer:3000`, routed via `presidio-anonymizer.localhost`) — Anonymizes and de-anonymizes text

### Features
- Built-in recognizers for PERSON, LOCATION, EMAIL, PHONE_NUMBER, CREDIT_CARD, etc.
- Custom German recognizers: `DE_IBAN`, `DE_STEUER_ID`, `DE_POSTAL_CODE`, `DE_PHONE_NUMBER`, `DE_ADDRESS`
- spaCy NLP models (German `de_core_news_lg`, English `en_core_web_lg`)
- Transformers-based NER (configurable)
- REST API with health endpoints
- Structured JSON logging

### Consumer Integration
Consumers (LiteLLM Router, Hermes, Second Brain, etc.) should:
1. Send text to Analyzer `/analyze` to detect PII
2. Send text + analyzer results to Anonymizer `/anonymize` to replace PII
3. Send LLM response to Anonymizer `/deanonymize` to restore original values

### Configuration
Secrets are managed via Infisical at path `/presidio` and injected at container startup by the local runtime wrapper image. The service `.env` file contains only the Universal Auth bootstrap values for the Machine Identity.

The Infisical environment slug is currently `local`; keep the `.env` value aligned with the actual Infisical environment. The runtime wrapper accepts `INFISICAL_WORKSPACE_ID` or `INFISICAL_PROJECT_SLUG`; the existing `INFISICAL_PROJECT_ID` variable is retained as the workspace ID fallback for local compatibility. The Machine Identity must be added to the project with read access to `/presidio`; organization-level identity access alone is not enough for secret reads.

Secrets expected at `/presidio`:
- `SPACY_MODEL` (default: `de_core_news_lg`)
- `TRANSFORMERS_MODEL` (default: `dslim/bert-base-NER`)
- `PRESIDIO_LOG_LEVEL` (default: `INFO`)
- `PRESIDIO_CUSTOM_RECOGNIZERS_ENABLED` (default: `true`)

### Compose File
`presidio/docker-compose.yml`

## LLM Observability (Langfuse)

Langfuse provides open-source LLM observability, tracing, and analytics. It runs on `infra_net` and reuses shared infrastructure with explicit per-service isolation where needed.

- **Web UI** (`langfuse-web:3000`, routed via `langfuse.localhost`) — Dashboard for traces, scores, datasets
- **API** (`langfuse-web:3000`) — Ingestion and query API
- **Worker** (`langfuse-worker:3030`, internal only) — Async ingestion, ClickHouse writes, scoring/evaluation/export jobs
- **Database** — Dedicated PostgreSQL database `langfuse_db` on shared Postgres
- **Cache/Queue** — Shared Redis with `REDIS_KEY_PREFIX=langfuse` to isolate Langfuse BullMQ keys from other services such as Twenty CRM
- **Analytics store** — ClickHouse runs as a dedicated local compose project for Langfuse analytics and loads `/clickhouse` secrets through the same Infisical runtime wrapper model

### Features
- LLM call tracing (inputs, outputs, latency, tokens, costs)
- User feedback collection (scores, comments)
- Dataset management for evaluation
- Prompt management and versioning
- OpenTelemetry compatible
- Self-hosted, privacy-first

### Consumer Integration
Consumers (LiteLLM Router, Hermes, etc.) integrate via:
- Langfuse SDK (Python, TypeScript, etc.)
- OpenTelemetry exporter
- Direct REST API

### Configuration
Secrets are managed via Infisical at path `/langfuse` and injected at container startup by the local runtime wrapper image. The service `.env` file contains only the Universal Auth bootstrap values for the Machine Identity.

The Infisical environment slug is currently `local`; keep the `.env` value aligned with the actual Infisical environment. The runtime wrapper accepts `INFISICAL_WORKSPACE_ID` or `INFISICAL_PROJECT_SLUG`; the existing `INFISICAL_PROJECT_ID` variable is retained as the workspace ID fallback for local compatibility. The Machine Identity must be added to the project with read access to `/langfuse`; organization-level identity access alone is not enough for secret reads.

Secrets expected at `/langfuse`:
- `LANGFUSE_SALT` — Encryption salt (generate with `openssl rand -base64 32`)
- `LANGFUSE_ENCRYPTION_KEY` — v3 encryption key (generate with `openssl rand -hex 32`; runtime wrapper exports it as `ENCRYPTION_KEY`)
- `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` — API keys for projects
- `DATABASE_URL` — PostgreSQL connection (shared Postgres)
- `REDIS_AUTH` or `REDIS_PASSWORD` — Redis authentication for shared Redis; compose sets `REDIS_KEY_PREFIX=langfuse`
- `NEXTAUTH_SECRET` — NextAuth secret (generate with `openssl rand -base64 32`)

Operational note: do not run Langfuse on unprefixed shared Redis keys. Twenty CRM also uses BullMQ queue names such as `webhook-queue`; `REDIS_KEY_PREFIX=langfuse` prevents Langfuse workers from consuming foreign jobs.

### Compose File
`langfuse/docker-compose.yml`

## Infisical MCP Bridge — Write-Capable Operation

For write-capable operation, role assignment has two layers:

- organization-level permission for `project:create` to allow `create-project`
- project-level membership with write-capable project permissions for `secrets`, `secret-folders`, and `environments`

During local validation, `list-projects` also proved to be stricter than some tool descriptions suggest: `type="all"` did not work against the local self-hosted Infisical instance. Use a concrete project type instead, for example `secret-manager`, `cert-manager`, `kms`, `ssh`, `secret-scanning`, `pam`, or `ai`.

## Consumers of This Stack

The consumer view should be read in two categories: what is confirmed live right now, and what is prepared in the workspace but not currently live-confirmed.

### Currently Live on `infra_net`

Based on live Docker inspection, these containers are currently attached to `infra_net` in addition to the core infra services:

- `twenty-crm`
  - containers: `twenty-server-1`, `twenty-worker-1`
  - shared route: `http://twentycrm.localhost`
  - shared dependencies: Postgres, Redis, MinIO
- `omi.me`
  - container: `omi-api-local`
  - shared route: `http://omi-api.localhost`
- `infra-hoppscotch`
  - live on `infra_net`
  - mentioned here as a running consumer even though no matching repo-local source was identified during this documentation pass
- `second_brain` / Honcho
  - containers: `second-brain-honcho-api`, `second-brain-honcho-deriver`
  - shared route: `http://honcho.localhost`
  - dependencies: Postgres (`second_brain` database, `honcho` schema), Redis (DB index `/2`)

### Configured in the Workspace, Not Currently Live-Confirmed

These repositories are configured to use `infra_net` and/or Traefik host routing in their own compose files, but they were not confirmed as currently attached to the live network during this pass:

- `audio2knowledge`
  - routes: `http://a2k.localhost`, `http://api.a2k.localhost`, `http://flower.a2k.localhost`
- `diagrams_and_drawings`
  - routes: `http://excalidraw.localhost`, `http://drawio.localhost`, `http://fossflow.localhost`

This split matters: `infra_net` is a central integration network, not a requirement for every repository all the time.

## Tooling Initialization Status

- `beads`
  - initialized in this repository
  - `.beads/` exists and `bd status` reports an active local database
  - used here to track and work on open tasks directly in the repository
- `gitnexus`
  - initialized
  - `.gitnexus/meta.json` exists and currently reports a small index for this repository

## Source Runbooks

This document is the overview, not the step-by-step operating manual. For detailed procedures, use the existing runbooks in `docs/documentation`:

- Traefik routing: `14-traefik-host-routing.md`
- app onboarding: `15-app-onboarding-runbook.md`
- Postgres provisioning: `08-postgres-provisioning.md`
- Postgres pgvector cutover and collation follow-up: `17-postgres-pgvector-cutover-and-collation-followup.md`
- Twenty CRM shared infra cutover: `16-twenty-crm-shared-infra-cutover.md`

When infrastructure changes, update this overview together with the underlying runbooks where necessary.
