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
- `gitnexus`
  - status: initialized in this repository
  - purpose: supports code understanding, impact analysis, and change detection for safe edits and reviews
- `beads`
  - status: initialized in this repository
  - purpose: tracks and manages open tasks directly in the repo so work can be captured, claimed, and completed through `bd`

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
- `redis`
  - status: active
  - purpose: shared cache and broker service for application stacks that connect to `infra_net`
- `minio`
  - status: active
  - purpose: shared S3-compatible object storage for application buckets and storage integrations

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
- If tooling, service inventory, or service activation state changes, update this file together with the relevant operational documentation.
