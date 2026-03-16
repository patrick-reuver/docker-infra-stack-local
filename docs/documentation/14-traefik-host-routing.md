# Step 14: Traefik Host Routing Without Extra Host Ports

Traefik-based host routing is now active with `*.localhost` domains.

## Goal

- Use speaking hostnames instead of direct service ports.
- Avoid local `/etc/hosts` changes.
- Reduce port collision risk by exposing only port `80` for HTTP routing.

## Implemented Changes

- Updated Traefik to a Docker-compatible image tag for the current Docker version.
- Enabled routing via:
  - `http://traefik.localhost` -> Traefik dashboard (`api@internal`)
  - `http://minio.localhost` -> MinIO console (`9001`)
  - `http://s3.localhost` -> MinIO S3 API (`9000`)
- Removed direct host port publishing for MinIO (`9000`, `9001`).
- Removed direct host port publishing for Traefik API (`8080`).
- Kept only `80:80` as shared entrypoint for routed HTTP access.

## Validation

```bash
curl -H "Host: traefik.localhost" http://localhost -I
curl -H "Host: minio.localhost" http://localhost -I
curl -H "Host: s3.localhost" http://localhost/minio/health/live -I
```

Observed status codes:

- `traefik.localhost` -> `302` (dashboard redirect)
- `minio.localhost` -> `200`
- `s3.localhost/minio/health/live` -> `200`

## Notes

- `*.localhost` resolves locally by default, so no hosts file entries are required.
- App containers in `infra_net` should still use internal DNS names (`minio`, `postgres`, `redis`) for backend traffic.
