# LiteLLM Gateway Architecture

## Goal

LiteLLM becomes the central OpenAI-compatible gateway for text-model requests in the infra stack. It should centralize provider access, routing, retry/fallback behavior, usage limits, costs, and later MCP-facing extensions.

This MVP is privacy-first: Hermes must not send raw prompts directly to LiteLLM, external providers, or Langfuse.

## Target Flow

```text
Hermes
-> Privacy Gateway / Hermes-LiteLLM Adapter
-> Presidio anonymization
-> LiteLLM
-> Model provider
-> LiteLLM
-> Presidio deanonymization
-> Privacy Gateway / Adapter
-> Hermes
```

## Components

### Hermes Privacy Gateway / Adapter

The adapter is the mandatory protection layer between Hermes and LiteLLM. It accepts OpenAI-compatible requests, applies Presidio before forwarding content, forwards only anonymized payloads to LiteLLM, deanonymizes model responses, and returns Hermes-compatible responses.

The adapter owns:

- Presidio anonymization and deanonymization calls
- privacy-safe request metadata
- technical error normalization
- retry and fallback policy coordination
- context policy before forwarding oversized requests

### LiteLLM Proxy

LiteLLM owns provider abstraction and OpenAI-compatible model routing. It is reachable through Traefik at `litellm.localhost` and internally as `litellm-proxy:4000` on `infra_net`.

LiteLLM should be treated as an internal platform component. Direct use is allowed only for admin/debug workflows and must not become Hermes' normal path.

### Presidio

Existing services:

- `presidio-analyzer:3000`
- `presidio-anonymizer:3000`

Service-to-service traffic should prefer Docker DNS on `infra_net` over Traefik routes.

### Infisical

Secrets are injected at container startup via the existing runtime wrapper. The intended secret path is `/litellm`.

No provider keys belong in:

- `docker-compose.yml`
- `litellm.config.yaml`
- `.env.example`
- documentation examples

### Database

LiteLLM may use the shared Postgres service `postgres` with a dedicated database named `litellm_db`. Runtime credentials should come from Infisical.

### Langfuse

Langfuse is prepared for later observability. Default behavior is metadata-only. Prompt logging is disabled unless explicitly enabled and must only receive anonymized content.

## Traefik And Network

Stack conventions:

- shared network: `infra_net`
- public route: `litellm.localhost`
- Traefik labels use `traefik.enable=true`
- Traefik network label uses `traefik.docker.network=infra_net`

## MVP Order

1. Text-model gateway and documentation
2. Rate limits and retry behavior
3. Context management
4. Audio limits
5. MCP extension points
