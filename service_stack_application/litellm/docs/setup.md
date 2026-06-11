# LiteLLM Setup

## Current Status

This folder contains the planning and documentation baseline for the LiteLLM MVP. The initial implementation should add Docker Compose, configuration files, and the Hermes Privacy Gateway adapter incrementally.

## Expected Location

```text
service_stack_application/litellm/
```

## Runtime Dependencies

The MVP assumes these existing infra services are available:

- Traefik on `infra_net`
- Postgres service `postgres`
- Infisical service `infisical:8080`
- Presidio analyzer at `presidio-analyzer:3000`
- Presidio anonymizer at `presidio-anonymizer:3000`
- optional Langfuse at `langfuse-web:3000`

## Bootstrap Environment

The `.env` file for this service should contain only Infisical bootstrap values:

- `INFISICAL_AUTH_METHOD`
- `INFISICAL_HOST_URL`
- `INFISICAL_PROJECT_ID`
- `INFISICAL_ENV`
- `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`
- `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET`
- optional `INFISICAL_SECRET_PATH=/litellm`

Provider API keys must be stored in Infisical and injected at runtime.

## Database

Use a dedicated Postgres database:

```text
litellm_db
```

The database can be provisioned on the shared `postgres` service. Credentials and `DATABASE_URL` should be loaded or derived by the runtime secret wrapper.

## First Implementation Step

Add a Compose file with two services:

- `litellm-proxy`
- `hermes-litellm-adapter`

Both services join `infra_net`. LiteLLM is routed through Traefik at `litellm.localhost`.
