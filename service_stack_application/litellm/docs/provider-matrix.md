# Provider Matrix

## Prepared Providers

The MVP prepares placeholders for these providers:

| Provider | Purpose | Secret Source | MVP Status |
| --- | --- | --- | --- |
| OpenAI / ChatGPT / Codex | high-quality reasoning and coding | Infisical `/litellm` | placeholder |
| OpenRouter | model aggregation and fallback | Infisical `/litellm` | placeholder |
| Groq | cheap/fast inference | Infisical `/litellm` | placeholder |
| NVIDIA | hosted and optimized models | Infisical `/litellm` | placeholder |
| opencode | coding workflow integration | Infisical `/litellm` | placeholder |
| Hugging Face | open model access | Infisical `/litellm` | placeholder |
| Gemini | long-context and multimodal options | Infisical `/litellm` | placeholder |
| Local fallback | privacy-sensitive or outage fallback | local runtime | backlog placeholder |

## Routing Priority

Model choice should be evaluated in this order:

1. Quality
2. Cost
3. Privacy
4. Local fallback

## MVP Constraint

Text models come first. Audio, vision, and MCP are prepared as config/documentation extension points, not first-pass runtime requirements.
