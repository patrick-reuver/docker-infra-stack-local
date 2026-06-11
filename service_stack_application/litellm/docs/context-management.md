# Context Management

## Goal

Avoid provider context errors and prevent raw personenbezogene Daten from being summarized or compressed by external models before Presidio anonymization.

## Model Metadata

Implementation should create:

```text
config/model-metadata.yaml
```

Each model entry should include:

- provider
- model name
- maximum context size
- recommended maximum input size
- reserved output tokens
- maximum output tokens
- input/output costs
- capabilities: reasoning, coding, extraction, summarization, audio, vision, long_context
- privacy suitability
- local availability
- fallback group

## Request Policy

Before forwarding a request:

1. Estimate token count.
2. Subtract reserved output tokens.
3. Check target model context limit.
4. If oversized, remove irrelevant context.
5. If still oversized, summarize only after Presidio anonymization.
6. If still oversized, choose a larger-context model.
7. If no route works, return a controlled context error.

## Privacy Constraint

No raw personal data may be sent to an external model for summarization, compression, or context optimization. Presidio must run first.

## MVP Defaults

- Prefer conservative token estimates.
- Reserve output tokens per model group.
- Treat context overflow as a policy event, not a generic provider error.
