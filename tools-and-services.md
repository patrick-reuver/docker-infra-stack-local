# Tools and Services Overview

This document complements `infrastructure.md`. `infrastructure.md` explains the architecture, networks, routing, and connected consumers of the shared infra stack. This file explains which tools and services are used in this repository and what they are used for.

The entries below explicitly distinguish between:

- actively used now
- initialized, but with setup caveats
- present in compose or documentation, but currently disabled

## Tools

### Actively Used

- `git`
  - status: locally initialized
  - remote state: currently no `origin` or other Git remote is configured
  - purpose: local version control for the infra stack repository
- `docker`
  - status: actively used
  - purpose: runs the shared infrastructure containers and provides runtime inspection for the local stack
- `docker compose`
  - status: actively used
  - purpose: defines and starts the shared infra stack from `infra_stack_application/docker-compose.yml`
  - note: also used for service-specific compose projects such as `infisical/docker-compose.yml` and the isolated Postgres collation remediation compose file
- `gitnexus`
  - status: initialized in this repository
  - purpose: supports code understanding, impact analysis, and change detection for safe edits and reviews
- `postgres collation remediation toolkit`
  - status: active operational helper set in this repository
  - purpose: clones live PGDATA into an isolated test location, inventories collatable objects, runs database-wide reindex plus collation refresh, and validates the result before the same steps are used against the live shared Postgres volume
- `beads`
  - status: initialized in this repository
  - purpose: tracks and manages open tasks directly in the repo so work can be captured, claimed, and completed through `bd`
- `infisical` ecosystem
  - status: active local service plus planned MCP bridge rollout
  - purpose: provides the secrets control plane for local tools and agents and the future authenticated MCP path for Codex
- `@infisical/mcp`
  - status: active for local Codex access through the dedicated MCP bridge
  - purpose: exposes Infisical project and secret operations to Codex or other MCP-capable clients through a dedicated MCP server authenticated with separate readonly and admin Organization Machine Identities

### Initialized, but With Setup Caveats

- `beads`
  - local database state: active embedded Dolt database under `.beads/`
  - setup note: `bd init` completed successfully, but warned that writing Git config for hook installation failed because `.git/config` could not be locked during setup
  - operational impact: issue tracking works, but Git-hook-related automation may need a follow-up check if hook behavior is required
  - sync note: this repository currently has no Git remote configured, so any remote-based beads sync or push-oriented workflow is not applicable in the current local-only setup

## Services

### Actively Used Runtime Services

- `traefik`
  - status: active
  - purpose: reverse proxy and routing layer for `*.localhost` endpoints based on Docker labels
- `postgres`
  - status: active
  - purpose: central relational database instance with separate application databases on a shared server
  - note: the shared Postgres 16 runtime now includes the `pgvector` extension so it remains available across container rebuilds and recreates
  - note: collation maintenance is now handled through an isolated-clone remediation workflow rather than ad-hoc operations against the live bind mount
- `redis`
  - status: active
  - purpose: shared cache and broker service for application stacks that connect to `infra_net`
- `minio`
  - status: active
  - purpose: shared S3-compatible object storage for application buckets and storage integrations
- `infisical`
  - status: configured as a dedicated local compose project
  - purpose: shared secret management service for local tools, agents, and application stacks that need API credentials or other secrets without hard-exposing them in repository files
  - dependencies: shared `postgres`, shared `redis`, shared `traefik`, external `infra_net`
- `infisical-mcp`
  - status: active as a separate local compose project
  - purpose: dedicated MCP bridge between AI clients and the self-hosted Infisical instance, with readonly/admin MCP profiles typically executed on demand as short-lived containers
  - dependencies: external `infra_net`, local Infisical host, Organization Machine Identity credentials
- `presidio`
  - status: configured as a dedicated local compose project
  - purpose: PII detection and anonymization service for privacy-safe LLM interactions
  - dependencies: external `infra_net`, shared `traefik`, Infisical for runtime-injected secrets
  - components: `presidio-analyzer` (detection), `presidio-anonymizer` (anonymization/de-anonymization)
  - secret model: wrapper images authenticate to local Infisical with Universal Auth and load `/presidio` before starting the upstream Presidio commands
  - custom: German PII recognizers (IBAN, Steuer-ID, postal codes, phone, addresses)
- `langfuse`
  - status: configured as a dedicated local compose project
  - purpose: LLM observability, tracing, and analytics platform
  - dependencies: external `infra_net`, shared `postgres` (dedicated `langfuse_db`), shared `redis` (dedicated DB 1), shared `traefik`, Infisical for runtime-injected secrets
  - components: `langfuse-web` (UI + API)
  - secret model: wrapper image authenticates to local Infisical with Universal Auth and loads `/langfuse` before starting the upstream Langfuse entrypoint and server command
- `clickhouse`
  - status: configured as a dedicated local compose project
  - purpose: ClickHouse analytics database used by Langfuse
  - dependencies: external `infra_net`, shared `traefik`, Infisical for runtime-injected secrets
  - secret model: wrapper image authenticates to local Infisical with Universal Auth and loads `/clickhouse` before starting the upstream ClickHouse entrypoint

### Present in Compose but Currently Disabled

- `prometheus`
  - status: defined in compose, currently commented out
  - purpose: metrics collection for the infra environment
- `loki`
  - status: defined in compose, currently commented out
  - purpose: centralized log storage
- `promtail`
  - status: defined in compose, currently commented out
  - purpose: log shipping from host and containers into Loki
- `grafana`
  - status: defined in compose, currently commented out
  - purpose: dashboards and operational visibility for metrics and logs

## Notes and References

- For architecture, routing, networks, and connected consumer repositories, use `infrastructure.md`.
- For operating procedures and onboarding details, use the runbooks in `docs/documentation`.
- The repository now prepares the official `@infisical/mcp` server as a separate service under `infisical-mcp/`. The preferred runtime target from the container is `http://infisical:8080` across `infra_net`; desktop MCP clients can still reference the local user-facing route `http://infisical.localhost` when needed outside Docker.
- Codex is now locally registered as an MCP client for this bridge and accesses Infisical through the dedicated machine-identity-backed MCP path rather than direct user login.
- The preferred security model is a phased rollout with two identities: a default readonly profile and a separate admin profile for write-capable tools such as secret CRUD and project creation.
- If tooling, service inventory, or service activation state changes, update this file together with the relevant operational documentation.
