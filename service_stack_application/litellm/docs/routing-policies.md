# Routing Policies

## Priority

Routing decisions follow this order:

1. Quality
2. Cost
3. Privacy
4. Local fallback

## Routing Groups

| Group | Intent |
| --- | --- |
| `reasoning_high_quality` | best available reasoning models |
| `coding_high_quality` | coding and agentic software tasks |
| `cheap_fast` | low-latency, low-cost tasks |
| `privacy_sensitive` | models/providers with stronger privacy posture |
| `local_fallback` | local models for outages or privacy-sensitive fallback |
| `long_context` | large context windows |
| `audio_transcription` | transcription and speech tasks, post-MVP |
| `vision` | image/multimodal tasks, post-MVP |

## Fallback Rules

Fallback is allowed for:

- rate limit
- timeout
- quota exceeded where alternate budget exists
- model unavailable
- network error

Fallback is not allowed for:

- auth error
- invalid request
- safety/content filtering

Context length errors use context policy first, then larger-context model fallback, then controlled failure.

## Config Files

Implementation should create:

```text
config/litellm.config.yaml
config/routing-policies.yaml
```

Provider keys should be referenced only as runtime environment variables populated from Infisical.
