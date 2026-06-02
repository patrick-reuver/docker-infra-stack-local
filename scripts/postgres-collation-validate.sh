#!/usr/bin/env bash

set -euo pipefail

container_name=${1:-infra-postgres-collation-test}

echo "==> version comparison"
docker exec "$container_name" \
  psql -U postgres -d postgres -F $'\t' -Atc \
  "SELECT datname, COALESCE(datcollversion, ''), pg_database_collation_actual_version(oid)
   FROM pg_database
   WHERE datname <> 'template0'
   ORDER BY datname;"

echo "==> warning check"
db_list=$(
  docker exec "$container_name" \
    psql -U postgres -d postgres -Atc \
    "SELECT datname FROM pg_database WHERE datname <> 'template0' ORDER BY datname;"
)

for db in $db_list; do
  if docker exec "$container_name" psql -U postgres -d "$db" -Atc "SELECT 1;" 2>&1 | rg -q "collation version mismatch"; then
    echo "warning still present for $db" >&2
    exit 1
  fi
done

echo "validation completed without collation mismatch warnings"
