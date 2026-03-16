# Step 4: Bind Mounts

To align with the centralized storage strategy, the infrastructure stack has been reconfigured to use bind mounts instead of named volumes.

## Action Taken

Modified `infra_stack_application/docker-compose.yml` to map service data to the host directory `/Users/patrickreuver/_workspace/04_docker/infra-stack/`.

## Volume Mapping Detail

- **Postgres**: `/Users/patrickreuver/_workspace/04_docker/infra-stack/postgres`
- **Redis**: `/Users/patrickreuver/_workspace/04_docker/infra-stack/redis`
- **MinIO**: `/Users/patrickreuver/_workspace/04_docker/infra-stack/minio`
- **Monitoring (Loki, Prometheus, Grafana)**: Corresponding subdirectories in the same base path.

## Commands Executed

```bash
mkdir -p /Users/patrickreuver/_workspace/04_docker/infra-stack/{postgres,redis,minio,prometheus,loki,grafana}
```

## Benefits

- Easier backup of raw data files from the host.
- Explicit control over data location.
- Consistent with the application stack setup.
