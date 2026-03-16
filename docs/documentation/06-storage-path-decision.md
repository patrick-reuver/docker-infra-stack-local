# Step 6: Storage Path Decision

For this project, bind mounts remain under `/Users/patrickreuver/_workspace/04_docker`.

## Decision

- Keep the current bind mount base path in `infra_stack_application/docker-compose.yml`.
- Do not switch to `/Users/patrickreuver/_docker-bind-mounts-volumes` for this stack.
- Use this stack as the clean baseline for the ongoing migration strategy.

## Rationale

- The `_workspace/04_docker` path is the target structure for future projects.
- This repository has no hard dependency that forces usage of the old path.
- Keeping one stable target path reduces drift in upcoming onboarding steps.

## Active Paths

- Postgres: `/Users/patrickreuver/_workspace/04_docker/infra-stack/postgres`
- Redis: `/Users/patrickreuver/_workspace/04_docker/infra-stack/redis`
- MinIO: `/Users/patrickreuver/_workspace/04_docker/infra-stack/minio`
- Prometheus: `/Users/patrickreuver/_workspace/04_docker/infra-stack/prometheus`
- Loki: `/Users/patrickreuver/_workspace/04_docker/infra-stack/loki`
- Grafana: `/Users/patrickreuver/_workspace/04_docker/infra-stack/grafana`
