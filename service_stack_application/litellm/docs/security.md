# LiteLLM Security Model

## Core Rule

Hermes must not send raw prompts directly to LiteLLM, external model providers, or Langfuse.

The Privacy Gateway is mandatory for normal Hermes traffic.

## Secret Handling

Secrets live in Infisical under `/litellm`.

Allowed in `.env`:

- Infisical Machine Identity bootstrap values
- Infisical project/environment/path identifiers

Not allowed in repo files:

- provider API keys
- LiteLLM master keys
- virtual key secrets
- Langfuse secret keys
- database passwords

## Logging Defaults

Default logging must exclude:

- raw prompts
- raw completions
- personenbezogene Daten
- deanonymization maps
- provider API keys

Allowed metadata:

- request ID
- provider
- model
- route group
- latency
- token usage
- cost estimate
- error class
- retry count
- fallback chain
- context size

## Presidio Boundary

Presidio anonymization happens before:

- LiteLLM forwarding
- provider calls
- Langfuse prompt logging
- context summarization by external models

Deanonymization maps must stay inside the adapter request lifecycle and must not be logged.

## Direct LiteLLM Access

`litellm.localhost` is useful for admin and debug workflows. It must not become Hermes' default request path because it bypasses the privacy boundary.
