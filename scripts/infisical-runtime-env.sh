#!/bin/sh

set -eu

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_var() {
  eval "value=\${$1:-}"
  [ -n "$value" ] || fail "$1 is required"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required in the runtime image"
}

SECRET_PATH="${INFISICAL_SECRET_PATH:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --path=*)
      SECRET_PATH="${1#*=}"
      shift
      ;;
    --path)
      shift
      [ "$#" -gt 0 ] || fail "--path requires a value"
      SECRET_PATH="$1"
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

[ -n "$SECRET_PATH" ] || fail "INFISICAL_SECRET_PATH or --path is required"
[ "$#" -gt 0 ] || fail "service command is required"

require_command curl
require_command jq
require_var INFISICAL_PROJECT_ID
require_var INFISICAL_ENV
require_var INFISICAL_UNIVERSAL_AUTH_CLIENT_ID
require_var INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET

INFISICAL_HOST_URL="${INFISICAL_HOST_URL:-http://infisical:8080}"
INFISICAL_WORKSPACE_ID="${INFISICAL_WORKSPACE_ID:-$INFISICAL_PROJECT_ID}"
INFISICAL_PROJECT_SLUG="${INFISICAL_PROJECT_SLUG:-}"

log "Fetching Infisical secrets from ${SECRET_PATH}"

LOGIN_BODY="$(
  jq -n \
    --arg clientId "$INFISICAL_UNIVERSAL_AUTH_CLIENT_ID" \
    --arg clientSecret "$INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET" \
    '{clientId: $clientId, clientSecret: $clientSecret}'
)"

LOGIN_RESPONSE_FILE="$(mktemp)"
LOGIN_STATUS="$(
  curl -sS -o "$LOGIN_RESPONSE_FILE" -w '%{http_code}' \
    -X POST "${INFISICAL_HOST_URL}/api/v1/auth/universal-auth/login" \
    -H "Content-Type: application/json" \
    -d "$LOGIN_BODY"
)" || {
  rm -f "$LOGIN_RESPONSE_FILE"
  fail "Infisical Universal Auth request failed"
}

[ "$LOGIN_STATUS" -ge 200 ] && [ "$LOGIN_STATUS" -lt 300 ] || {
  cat "$LOGIN_RESPONSE_FILE" >&2
  rm -f "$LOGIN_RESPONSE_FILE"
  fail "Infisical Universal Auth returned HTTP ${LOGIN_STATUS}"
}

ACCESS_TOKEN="$(jq -r '.accessToken // empty' "$LOGIN_RESPONSE_FILE")"
rm -f "$LOGIN_RESPONSE_FILE"
[ -n "$ACCESS_TOKEN" ] || fail "Infisical Universal Auth response did not include accessToken"

log "Authenticated with Infisical"

SECRETS_RESPONSE_FILE="$(mktemp)"
SECRETS_QUERY_FILE="$(mktemp)"
{
  printf '%s\n' "--data-urlencode" "environment=${INFISICAL_ENV}"
  printf '%s\n' "--data-urlencode" "secretPath=${SECRET_PATH}"
  printf '%s\n' "--data-urlencode" "expand=true"
  printf '%s\n' "--data-urlencode" "recursive=true"
  if [ -n "$INFISICAL_PROJECT_SLUG" ]; then
    printf '%s\n' "--data-urlencode" "projectSlug=${INFISICAL_PROJECT_SLUG}"
  else
    printf '%s\n' "--data-urlencode" "workspaceId=${INFISICAL_WORKSPACE_ID}"
  fi
} > "$SECRETS_QUERY_FILE"

SECRETS_STATUS="$(
  xargs curl -sS -G -o "$SECRETS_RESPONSE_FILE" -w '%{http_code}' \
    "${INFISICAL_HOST_URL}/api/v3/secrets/raw" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    < "$SECRETS_QUERY_FILE"
)" || {
  rm -f "$SECRETS_QUERY_FILE"
  rm -f "$SECRETS_RESPONSE_FILE"
  fail "Infisical secrets request failed"
}
rm -f "$SECRETS_QUERY_FILE"

[ "$SECRETS_STATUS" -ge 200 ] && [ "$SECRETS_STATUS" -lt 300 ] || {
  cat "$SECRETS_RESPONSE_FILE" >&2
  rm -f "$SECRETS_RESPONSE_FILE"
  fail "Infisical secrets request returned HTTP ${SECRETS_STATUS}"
}

SECRET_COUNT="$(jq '.secrets | length' "$SECRETS_RESPONSE_FILE")"
[ "$SECRET_COUNT" -gt 0 ] || {
  rm -f "$SECRETS_RESPONSE_FILE"
  fail "Infisical returned no secrets for ${SECRET_PATH} in environment ${INFISICAL_ENV}"
}

EXPORT_FILE="$(mktemp)"
jq -r '
  .secrets[]
  | select(.secretKey | test("^[A-Za-z_][A-Za-z0-9_]*$"))
  | [.secretKey, (.secretValue // "")]
  | @tsv
' "$SECRETS_RESPONSE_FILE" > "$EXPORT_FILE"
rm -f "$SECRETS_RESPONSE_FILE"

LOADED_COUNT=0
while IFS="$(printf '\t')" read -r KEY VALUE; do
  [ -n "$KEY" ] || continue
  export "$KEY=$VALUE"
  LOADED_COUNT=$((LOADED_COUNT + 1))
  log "Loaded secret: ${KEY}"
done < "$EXPORT_FILE"
rm -f "$EXPORT_FILE"

[ "$LOADED_COUNT" -gt 0 ] || fail "No valid environment-variable secrets were loaded from ${SECRET_PATH}"

if [ -z "${DATABASE_USERNAME:-}" ] && [ -n "${POSTGRES_APP_USER:-}" ]; then
  export DATABASE_USERNAME="$POSTGRES_APP_USER"
  log "Derived env: DATABASE_USERNAME"
fi

if [ -z "${SALT:-}" ] && [ -n "${LANGFUSE_SALT:-}" ]; then
  export SALT="$LANGFUSE_SALT"
  log "Derived env: SALT"
fi

if [ -z "${DATABASE_PASSWORD:-}" ] && [ -n "${POSTGRES_APP_PASSWORD:-}" ]; then
  export DATABASE_PASSWORD="$POSTGRES_APP_PASSWORD"
  log "Derived env: DATABASE_PASSWORD"
fi

if [ -z "${DATABASE_URL:-}" ] \
  && [ -n "${DATABASE_HOST:-}" ] \
  && [ -n "${DATABASE_USERNAME:-}" ] \
  && [ -n "${DATABASE_PASSWORD:-}" ] \
  && [ -n "${DATABASE_NAME:-}" ]; then
  DATABASE_USERNAME_ENCODED="$(jq -rn --arg value "$DATABASE_USERNAME" '$value | @uri')"
  DATABASE_PASSWORD_ENCODED="$(jq -rn --arg value "$DATABASE_PASSWORD" '$value | @uri')"
  DATABASE_URL="postgresql://${DATABASE_USERNAME_ENCODED}:${DATABASE_PASSWORD_ENCODED}@${DATABASE_HOST}/${DATABASE_NAME}"
  if [ -n "${DATABASE_ARGS:-}" ]; then
    DATABASE_URL="${DATABASE_URL}?${DATABASE_ARGS}"
  fi
  export DATABASE_URL
  export DIRECT_URL="${DIRECT_URL:-$DATABASE_URL}"
  log "Derived env: DATABASE_URL"
fi

if [ -z "${CLICKHOUSE_MIGRATION_URL:-}" ] && [ -n "${CLICKHOUSE_URL:-}" ]; then
  CLICKHOUSE_MIGRATION_HOST="$(
    printf '%s\n' "$CLICKHOUSE_URL" \
      | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/:]+)(:[0-9]+)?(/.*)?$#\1#'
  )"
  [ -n "$CLICKHOUSE_MIGRATION_HOST" ] || fail "Could not derive ClickHouse migration host from CLICKHOUSE_URL"
  export CLICKHOUSE_MIGRATION_URL="clickhouse://${CLICKHOUSE_MIGRATION_HOST}:9000"
  log "Derived env: CLICKHOUSE_MIGRATION_URL"
fi

log "Starting service command: $*"
exec "$@"
