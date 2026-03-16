# Step 13: Treat MinIO Storage Config as Global

The S3/MinIO storage variables were moved into the shared MinIO runtime section.

## Decision

- Keep MinIO/S3 connection settings global for all apps.
- Only the bucket name is app-specific.

## What Changed

In `infra_stack_application/.env.example`:

- `STORAGE_TYPE`
- `STORAGE_S3_REGION`
- `STORAGE_S3_ENDPOINT`
- `STORAGE_S3_ACCESS_KEY_ID`
- `STORAGE_S3_SECRET_ACCESS_KEY`

are now grouped directly under:

- `MINIO_APPS_USER`
- `MINIO_APPS_PASSWORD`

`STORAGE_S3_NAME` remains in the same global block but is explicitly documented as the per-app bucket value.

## App Mapping

Per app, only these values should change:

- `*_POSTGRES_DB`
- `*_MINIO_BUCKET`
- `STORAGE_S3_NAME` (set to that app's bucket)
