# Infrastructure Overview

This repository contains the shared Docker infrastructure stack that other local application repositories can connect to when they need central routing or shared runtime services. It is the entry document for the stack shape, connected consumers, and where to find the deeper runbooks.

## Repository Scope

The stack is defined in `infra_stack_application/docker-compose.yml` and currently provides these central services:

- `traefik` for HTTP routing via Docker labels
- `postgres` as the shared relational database instance
- `redis` as the shared runtime cache / broker
- `minio` as the shared S3-compatible object storage

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
- exposure through shared Traefik routing

Within Docker, connected application containers should use internal DNS names:

- `postgres:5432`
- `redis:6379`
- `minio:9000`

## Routing via Traefik

Traefik is the shared HTTP entrypoint and currently routes these infra endpoints:

- `http://traefik.localhost` -> Traefik dashboard
- `http://minio.localhost` -> MinIO console
- `http://s3.localhost` -> MinIO S3 API

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

Twenty CRM is the documented consumer for `twenty_db`. Existing runbooks also describe provisioning and cutover for this database.

### Redis

Redis is provided as a shared runtime service on `redis:6379`. Connected applications reuse the same central instance instead of bringing their own Redis container unless there is a specific reason to isolate it.

### MinIO

MinIO is the shared S3-compatible object storage service. The env template separates:

- admin credentials for provisioning
- shared runtime credentials for application access

Per-app storage should be separated by bucket. The current template already includes the Twenty CRM bucket mapping:

- `TWENTY_MINIO_BUCKET=twenty`

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
- Twenty CRM shared infra cutover: `16-twenty-crm-shared-infra-cutover.md`

When infrastructure changes, update this overview together with the underlying runbooks where necessary.
