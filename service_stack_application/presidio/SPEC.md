# Presidio PII Service — Specification

## Overview
Presidio (by Microsoft) provides PII detection and anonymization for privacy-sensitive data before sending to LLMs. This service runs as a central infrastructure component in `docker-infra-stack`, accessible via `infra_net` to all consumers (LiteLLM Router, Hermes, Second Brain, Twenty CRM, etc.).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        infra_net                                │
├─────────────┬─────────────┬─────────────┬─────────────────────┤
│  Traefik    │  Postgres   │   Redis     │    Presidio         │
│  (routing)  │  (shared)   │  (shared)   │  (PII detect/anon)  │
└─────────────┴─────────────┴─────────────┴─────────────────────┘
                                              │
                                              ▼
                                    ┌─────────────────────┐
                                    │  Consumers via      │
                                    │  presidio.localhost │
                                    │  or internal DNS:   │
                                    │  presidio:3000      │
                                    └─────────────────────┘
```

## Requirements

### Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-01 | Run Presidio Analyzer API (port 3000) for PII detection | P0 |
| FR-02 | Run Presidio Anonymizer API (port 3000) for anonymization/de-anonymization | P0 |
| FR-03 | Support custom recognizers for German PII (DE addresses, IBAN, Steuer-ID, etc.) | P1 |
| FR-04 | Provide health check endpoint | P0 |
| FR-05 | Expose via Traefik at `presidio.localhost` | P0 |
| FR-06 | Store secrets (API keys, config) in Infisical | P0 |

### Non-Functional Requirements
| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-01 | Container startup < 30 seconds | P1 |
| NFR-02 | Memory usage < 1GB | P1 |
| NFR-03 | Response latency < 500ms for typical requests | P1 |
| NFR-04 | Support graceful shutdown | P1 |
| NFR-05 | Structured logging (JSON) | P2 |

## API Endpoints (Presidio v2.2.350)

### Analyzer
- `POST /analyze` — Detect PII entities in text
- `POST /analyze/batch` — Batch analysis
- `GET /recognizers` — List available recognizers
- `GET /supportedentities` — List supported entity types
- `GET /health` — Health check

### Anonymizer
- `POST /anonymize` — Anonymize detected entities
- `POST /deanonymize` — Restore original text from anonymized
- `GET /health` — Health check

## Configuration

### Environment Variables (from Infisical)
```bash
# Presidio Analyzer
PRESIDIO_ANALYZER_PORT=3000
PRESIDIO_ANALYZER_LOG_LEVEL=INFO
PRESIDIO_ANALYZER_CORS_ENABLED=true

# Presidio Anonymizer
PRESIDIO_ANONYMIZER_PORT=3000
PRESIDIO_ANONYMIZER_LOG_LEVEL=INFO

# Custom Recognizers (German)
PRESIDIO_CUSTOM_RECOGNIZERS_ENABLED=true
PRESIDIO_GERMAN_RECOGNIZERS_PATH=/app/custom_recognizers

# Model Configuration
SPACY_MODEL=de_core_news_lg
TRANSFORMERS_MODEL=dslim/bert-base-NER
```

### Docker Compose Structure
```yaml
services:
  presidio-analyzer:
    image: mcr.microsoft.com/presidio-analyzer:latest
    ports: ["3000:3000"]
    environment: [...]
    healthcheck: [...]
    networks: [infra_net]
    labels: [traefik routing]

  presidio-anonymizer:
    image: mcr.microsoft.com/presidio-anonymizer:latest
    ports: ["3001:3000"]
    environment: [...]
    healthcheck: [...]
    networks: [infra_net]
    labels: [traefik routing]
```

## Traefik Routing
- `presidio.localhost` → Analyzer (port 3000)
- `presidio-anonymizer.localhost` → Anonymizer (port 3000)
- Or single entry with path stripping: `/analyzer/*` and `/anonymizer/*`

## Infisical Secrets Structure
```
Project: docker-infra-stack
Environment: development
Path: /presidio
Secrets:
  - SPACY_MODEL (default: de_core_news_lg)
  - TRANSFORMERS_MODEL (default: dslim/bert-base-NER)
  - PRESIDIO_LOG_LEVEL (default: INFO)
  - CUSTOM_RECOGNIZERS_CONFIG (JSON)
```

## Testing Strategy (TDD)

### Unit Tests
- [ ] Custom German recognizers load correctly
- [ ] Analyzer detects PERSON, LOCATION, EMAIL, PHONE_NUMBER
- [ ] Anonymizer replaces entities with `<ENTITY_TYPE>`
- [ ] Deanonymizer restores original text from anonymized + mapping

### Integration Tests
- [ ] Docker compose starts both services healthy
- [ ] Traefik routes `presidio.localhost/analyze` → analyzer
- [ ] Traefik routes `presidio-anonymizer.localhost/anonymize` → anonymizer
- [ ] End-to-end: analyze → anonymize → deanonymize roundtrip
- [ ] Health endpoints return 200
- [ ] Infisical secrets injected correctly

### Performance Tests
- [ ] Analyze 1000 chars < 500ms
- [ ] Concurrent 10 requests < 2s total

## Acceptance Criteria
1. `docker compose -f presidio/docker-compose.yml up -d` starts both services
2. `curl presidio.localhost/health` returns 200
3. `curl presidio-anonymizer.localhost/health` returns 200
4. PII detection works for German and English text
5. Anonymization + deanonymization roundtrip preserves meaning
6. Services accessible via `infra_net` internal DNS
7. Secrets managed via Infisical (no hardcoded values)
8. Infrastructure.md and tools-and-services.md updated