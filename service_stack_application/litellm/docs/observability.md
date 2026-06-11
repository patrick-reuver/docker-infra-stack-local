# Observability

## Goal

Prepare Langfuse and local structured logs for technical diagnostics without exposing raw prompts or personenbezogene Daten.

## Default Metadata

Log:

- request ID
- route group
- model
- provider
- latency
- input tokens
- output tokens
- total tokens
- estimated cost
- error class
- retry count
- fallback chain
- context size

Do not log by default:

- raw prompt
- raw completion
- deanonymization map
- provider keys
- LiteLLM master key

## Langfuse

Langfuse integration is optional and disabled by default. If enabled, it should receive metadata only unless anonymized prompt logging is explicitly enabled.

Preferred internal host:

```text
http://langfuse-web:3000
```

## Privacy Rule

Only anonymized content may reach Langfuse. Raw Hermes prompts must stay within Hermes and the Privacy Gateway request lifecycle.
