# Backlog

## Audio Limits

Audio is not part of the first text MVP. Prepare later support for:

- ASH: audio seconds per hour
- ASD: audio seconds per day
- transcription routing
- audio cost tracking
- provider-specific file size and duration constraints

## Vision

Vision routing is prepared as a routing group but not required for the first MVP.

## MCP

MCP centralization is backlog. Future design should evaluate whether LiteLLM, the Privacy Gateway, or a separate MCP Gateway should own:

- MCP server discovery
- tool authorization
- tool-call audit logs
- privacy filtering around tool inputs/outputs
- per-agent tool policies

## Local Fallback

Local fallback is a routing group placeholder. Later implementation should define:

- local model runtime
- health checks
- context limits
- privacy guarantees
- quality threshold for fallback eligibility
