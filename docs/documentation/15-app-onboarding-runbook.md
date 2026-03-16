# Step 15: App Onboarding Runbook (Shared Infra)

This runbook defines the standard process for connecting any new app to the shared infrastructure.

## Default Process

1. Create app database in Postgres.
2. Create app bucket in MinIO (if object storage is needed).
3. Connect app services to `infra_net`.
4. Add Traefik hostname routing labels.
5. Remove direct host ports from the app when possible.

## Connection Rules

- Container-to-container traffic in Docker uses internal DNS names:
  - Postgres: `postgres:5432`
  - Redis: `redis:6379`
  - MinIO S3 API: `minio:9000`
- Host/browser traffic uses Traefik hostnames:
  - `http://traefik.localhost`
  - `http://minio.localhost`
  - `http://s3.localhost`

## Environment Mapping Pattern

- Shared runtime credentials (global):
  - `POSTGRES_APP_USER`, `POSTGRES_APP_PASSWORD`
  - `MINIO_APPS_USER`, `MINIO_APPS_PASSWORD`
  - `STORAGE_TYPE`, `STORAGE_S3_REGION`, `STORAGE_S3_ENDPOINT`, `STORAGE_S3_ACCESS_KEY_ID`, `STORAGE_S3_SECRET_ACCESS_KEY`
- Per-app resources:
  - `<APP>_POSTGRES_DB`
  - `<APP>_MINIO_BUCKET`
  - `STORAGE_S3_NAME` (set to the app bucket)

## Readiness Checklist Before Start

- App database exists and is owned or writable by `POSTGRES_APP_USER`.
- App bucket exists in MinIO.
- App compose joins `infra_net`.
- App has Traefik labels and a dedicated hostname.
- App does not publish unnecessary host ports.
