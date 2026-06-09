#!/bin/sh
set -eu

export PGPASSWORD="${POSTGRES_ADMIN_PASSWORD}"

psql \
  -h "${POSTGRES_HOST}" \
  -p "${POSTGRES_PORT}" \
  -U "${POSTGRES_ADMIN_USER}" \
  -d "${POSTGRES_DEFAULT_DB}" \
  -v app_user="${POSTGRES_APP_USER}" \
  -v app_db="${INFISICAL_POSTGRES_DB}" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'app_db', :'app_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'app_db')\gexec

GRANT ALL PRIVILEGES ON DATABASE :"app_db" TO :"app_user";
SQL

echo "Database ${INFISICAL_POSTGRES_DB} is ready for ${POSTGRES_APP_USER}."
