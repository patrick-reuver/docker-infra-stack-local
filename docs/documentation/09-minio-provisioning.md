# Step 9: MinIO Provisioning for Shared App Runtime

MinIO was provisioned with one shared app user and one app bucket for Twenty CRM.

## Provisioning Model

- One shared app user: `apps_s3_user`
- One bucket per application: `twenty`
- Root credentials reserved for administrative provisioning only

This matches the low-complexity approach while keeping app data separated by bucket.

## Commands Executed

```bash
# Generate strong password
openssl rand -base64 32

# Provision via MinIO client on the shared Docker network
docker run --rm --network infra_net minio/mc
```

Actions applied:

- Created bucket `twenty` (idempotent).
- Created user `apps_s3_user`.
- Attached `readwrite` policy to `apps_s3_user`.

## Validation

Validation was executed with the app user credentials (not root):

```bash
docker run --rm --network infra_net minio/mc \
  mc ls app/twenty
```

Validation result:

- The app user can read/list bucket contents.
- Object write test succeeded (`infra-check.txt` uploaded).

## Secret Handling

- Credentials were stored locally in `infra_stack_application/.env` for onboarding use.
- No generated secret was added to version-controlled documentation.

## Optional Hardening

If you want to scope the user to selected buckets only, use a custom policy template in `docs/config_templates/minio/01-shared-app-user-policy.json` instead of the global `readwrite` policy.
