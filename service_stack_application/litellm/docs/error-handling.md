# Error Handling

## Goal

The adapter and LiteLLM config should convert provider-specific failures into a small set of operational classes.

## Error Classes

| Error | Retry | Fallback | User Action | Notes |
| --- | --- | --- | --- | --- |
| Rate limit | yes | yes | no | respect `Retry-After` |
| Timeout | yes | yes | no | bounded retries only |
| Auth error | no | no | yes | check Infisical/provider secret configuration |
| Quota exceeded | no | yes | yes | fallback only if an alternate funded provider exists |
| Model unavailable | yes | yes | no | circuit breaker should track provider/model health |
| Context length exceeded | no initially | conditional | maybe | run context policy first |
| Invalid request | no | no | yes | return controlled client error |
| Safety/content filtering | no | no | maybe | no blind fallback |
| Network error | yes | yes | no | bounded retries with jitter |
| Provider-specific error | depends | depends | depends | map through `config/error-mapping.yaml` |

## Auth Errors

Auth errors are never retried and never silently routed elsewhere. They should return a clean operational message pointing to Infisical/provider configuration.

## Safety Errors

Safety or content-filter errors must not trigger blind fallback because fallback can bypass provider safety intent. Return a controlled response with metadata.

## Mapping File

Implementation should create:

```text
config/error-mapping.yaml
```

The mapping should define:

- normalized error code
- matching provider status codes/messages
- retryable flag
- fallbackable flag
- user-action-required flag
- fatal flag
- default user-facing message
