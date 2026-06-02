#!/usr/bin/env bash

set -euo pipefail

container_name=${1:-infra-postgres-collation-test}

db_list=$(
  docker exec "$container_name" \
    psql -U postgres -d postgres -Atc \
    "SELECT datname FROM pg_database WHERE datname <> 'template0' ORDER BY datname;"
)

for db in $db_list; do
  echo "## $db"
  docker exec "$container_name" \
    psql -U postgres -d "$db" -F $'\t' -Atc "
WITH collatable_columns AS (
  SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    a.attname AS column_name,
    format_type(a.atttypid, a.atttypmod) AS data_type
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE a.attnum > 0
    AND NOT a.attisdropped
    AND c.relkind IN ('r', 'm', 'p')
    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND a.attcollation <> 0
),
collatable_indexes AS (
  SELECT DISTINCT
    idx.indexrelid::regclass::text AS index_name
  FROM pg_index idx
  JOIN pg_class c ON c.oid = idx.indrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(idx.indkey)
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND a.attcollation <> 0
)
SELECT
  '$db',
  (SELECT count(*) FROM collatable_columns),
  (SELECT count(*) FROM collatable_indexes);
"
done
