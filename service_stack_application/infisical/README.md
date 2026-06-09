# Infisical on Shared Infra

This folder contains the self-hosted Infisical setup for the local shared infrastructure stack.

## Architecture

- Runs as a dedicated container in the external `infra_net` Docker network.
- Reuses the shared `postgres` and `redis` services from `infra_stack_application/docker-compose.yml`.
- Is exposed through the existing Traefik instance at `http://infisical.localhost`.

## Files

- `docker-compose.yml`: Infisical runtime plus the one-shot DB initialization service.
- `.env.example`: local configuration template for the Infisical stack.
- `scripts/init-db.sh`: idempotent database creation step for `infisical_db`.

## Setup

1. Copy `.env.example` to `.env`.
2. Replace placeholder secrets and runtime passwords.
3. Keep both credential scopes separate:
   - `POSTGRES_ADMIN_*` only for the one-shot DB provisioning step
   - `DB_*` for the Infisical runtime connection
4. URI-encode the runtime password into `DB_PASSWORD_URLENCODED` if the shared Postgres password contains special characters such as `+`, `/`, `:` or `@`.
5. Ensure the shared infra stack is already running.
6. Create the database:
   `docker compose --env-file .env --profile setup up infisical-db-init`
7. Start Infisical:
   `docker compose --env-file .env up -d infisical`

## Validation

- DB init should report that the database is ready for the runtime user.
- `docker compose ps` should show `infra-infisical` as running.
- `http://infisical.localhost` should be reachable through Traefik.

## MCP Follow-Up

The MCP follow-up is implemented in this repository as a separate service under `../infisical-mcp/`.

Key decisions:

- the MCP bridge is a dedicated container, not part of the main `infisical` container
- the preferred runtime target from inside Docker is `http://infisical:8080`
- authentication uses an Infisical Organization Machine Identity with Universal Auth
- rollout is phased: read-oriented pilot first, explicit write enablement later

Current local state:

- Codex is configured locally as an MCP client against the dedicated `infisical-mcp` service
- Codex reaches Infisical through the MCP bridge, not by storing a user login in Codex itself
- authentication is backed by the Organization Machine Identity credentials supplied to the MCP container
- the preferred operational model is two separate Organization Machine Identities: `codex-readonly` and `codex-admin`

This split keeps the core secrets platform and the AI-facing MCP surface independently operable and easier to reason about from a security perspective.
