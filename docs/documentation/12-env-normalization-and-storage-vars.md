# Step 12: Env Normalization and S3 Storage Variables

The env model was normalized to reflect one shared runtime user for Postgres and MinIO across all apps.

## Goal

- Keep credentials simple and reusable across app stacks.
- Keep app isolation at resource level (database and bucket per app).
- Make `.env` and `.env.example` structurally identical and reproducible.

## Changes Applied

- Replaced app-specific DB user/password keys with shared runtime keys:
  - `POSTGRES_APP_USER`
  - `POSTGRES_APP_PASSWORD`
- Normalized app-specific resource keys for Twenty:
  - `TWENTY_POSTGRES_DB`
  - `TWENTY_MINIO_BUCKET`
- Added storage variables expected by Twenty server/worker:
  - `STORAGE_TYPE=s3`
  - `STORAGE_S3_REGION=eu-central-1`
  - `STORAGE_S3_NAME=twenty`
  - `STORAGE_S3_ENDPOINT=http://minio:9000`
  - `STORAGE_S3_ACCESS_KEY_ID=apps_s3_user`
  - `STORAGE_S3_SECRET_ACCESS_KEY=<shared MinIO runtime secret>`

## Notes

- Region default is `eu-central-1` (Frankfurt) for EU-oriented configuration.
- For local MinIO, endpoint remains internal Docker DNS: `http://minio:9000` in app stacks.
- Inline comments were removed from value lines to avoid parser issues.
