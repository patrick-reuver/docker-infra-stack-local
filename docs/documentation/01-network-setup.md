# Step 1: Network Setup

To allow communication between the central infrastructure stack and separate application stacks, a shared external Docker network is required.

## Action Taken

Created the external Docker network named `infra_net`.

## Commands Executed

```bash
docker network create infra_net
```

## Verification

```bash
docker network ls | grep infra_net
```

The network is now available for all services defined in `infra_stack_application/docker-compose.yml`.
