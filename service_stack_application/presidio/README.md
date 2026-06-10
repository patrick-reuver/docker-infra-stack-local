# Presidio PII Service

Microsoft Presidio deployment for PII detection and anonymization in the docker-infra-stack.

## Services

| Service | Internal Port | External Host | Description |
|---------|--------------|---------------|-------------|
| presidio-analyzer | 3000 | `presidio.localhost` | PII detection API |
| presidio-anonymizer | 3000 | `presidio-anonymizer.localhost` | Anonymization/de-anonymization API |

## Quick Start

```bash
# From docker-infra-stack root
cd service_stack_application/presidio
cp .env.example .env
# Edit .env with the Infisical Machine Identity bootstrap values.
docker compose up -d
```

## API Usage

### Analyze Text for PII
```bash
curl -X POST http://presidio.localhost/analyze \
  -H "Content-Type: application/json" \
  -d '{"text": "Mein Name ist Max Mustermann, IBAN: DE89370400440532013000", "language": "de"}'
```

### Anonymize Text
```bash
curl -X POST http://presidio-anonymizer.localhost/anonymize \
  -H "Content-Type: application/json" \
  -d '{"text": "Mein Name ist Max Mustermann", "analyzer_results": [{"entity_type": "PERSON", "start": 11, "end": 25, "score": 0.95}]}'
```

### Deanonymize Text
```bash
curl -X POST http://presidio-anonymizer.localhost/deanonymize \
  -H "Content-Type: application/json" \
  -d '{"text": "Mein Name ist <PERSON>", "entities": [{"entity_type": "PERSON", "start": 11, "end": 21, "text": "Max Mustermann"}]}'
```

## Custom German Recognizers

The service includes custom recognizers for German PII:
- `DE_IBAN` - German IBAN with checksum validation
- `DE_STEUER_ID` - German Steuer-ID (11 digits, validated)
- `DE_POSTAL_CODE` - German postal codes (5 digits)
- `DE_PHONE_NUMBER` - German phone numbers (mobile + landline)
- `DE_ADDRESS` - German street addresses

Located in `custom_recognizers/german_recognizers.py`.

## Configuration

Environment variables (managed via Infisical at `/presidio`):
| Variable | Default | Description |
|----------|---------|-------------|
| `PRESIDIO_LOG_LEVEL` | `INFO` | Log level for both services |
| `SPACY_MODEL` | `de_core_news_lg` | spaCy NLP model |
| `TRANSFORMERS_MODEL` | `dslim/bert-base-NER` | Transformers NER model |
| `PRESIDIO_CUSTOM_RECOGNIZERS_ENABLED` | `true` | Enable custom recognizers |

## Network

Services join `infra_net` for internal DNS resolution:
- `presidio-analyzer:3000` (analyzer)
- `presidio-anonymizer:3000` (anonymizer)

## Health Checks

```bash
curl http://presidio.localhost/health
curl http://presidio-anonymizer.localhost/health
```

## Infisical Secrets

Project: `docker-infra-stack`
Environment slug: match `INFISICAL_ENV` in `.env` (currently `local`)
Path: `/presidio`

Secrets are injected at container startup by the local runtime wrapper image. The `.env` file only contains the Universal Auth Machine Identity bootstrap values; service configuration secrets stay in Infisical. The wrapper accepts `INFISICAL_WORKSPACE_ID` or `INFISICAL_PROJECT_SLUG`; for the current local setup it also treats `INFISICAL_PROJECT_ID` as the workspace ID fallback.

The Machine Identity must be added to the Infisical project with read access to `/presidio`. Organization-level identity access alone is not enough for project secret reads.
