# Rate Limits

## Goal

Define limits per provider, model, virtual key, user/team, task type, and time window.

## Supported Limit Types

| Limit | Meaning |
| --- | --- |
| RPM | requests per minute |
| RPD | requests per day |
| TPM | tokens per minute |
| TPD | tokens per day |
| ITPM | input tokens per minute |
| OTPM | output tokens per minute |
| ASH | audio seconds per hour |
| ASD | audio seconds per day |
| Context Size | maximum context length per model |

## Usage Metrics

Track at least:

- requests
- input tokens
- output tokens
- total tokens
- audio seconds
- cost
- error rate
- retry count
- fallback usage
- latency
- context size

## Buckets

Prepare:

- minute buckets for RPM, TPM, ITPM, OTPM
- daily buckets for RPD, TPD
- hourly and daily buckets for ASH/ASD

## MVP Order

1. Text request and token limits
2. Retry and fallback usage counters
3. Context size tracking
4. Audio seconds after text MVP

## Config File

Implementation should create:

```text
config/rate-limits.yaml
```

The schema should be explicit enough to support provider, model, virtual key, user/team, and task-type policies without hard-coding secrets.
