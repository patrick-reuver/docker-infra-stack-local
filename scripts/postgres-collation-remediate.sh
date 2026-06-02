#!/usr/bin/env bash

set -euo pipefail

container_name=${1:-infra-postgres-collation-test}

db_list=$(
  docker exec "$container_name" \
    psql -U postgres -d postgres -Atc \
    "SELECT datname FROM pg_database WHERE datname <> 'template0' ORDER BY datname;"
)

for db in $db_list; do
  echo "==> remediating $db"
  docker exec "$container_name" \
    psql -U postgres -d "$db" -v ON_ERROR_STOP=1 -c "REINDEX DATABASE \"$db\";"
  docker exec "$container_name" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "ALTER DATABASE \"$db\" REFRESH COLLATION VERSION;"
done

echo "remediation completed for ${container_name}"
