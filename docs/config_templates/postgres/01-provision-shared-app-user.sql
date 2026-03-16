-- Usage example:
-- docker exec -i infra-postgres psql -U "$POSTGRES_USER" -d postgres \
--   -v app_user='apps_rw_user' -v app_password='REPLACE_ME' -v app_db='twenty_db' \
--   -f docs/config_templates/postgres/01-provision-shared-app-user.sql

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user') THEN
    EXECUTE format(
      'CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT',
      :'app_user',
      :'app_password'
    );
  ELSE
    EXECUTE format(
      'ALTER ROLE %I WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT',
      :'app_user',
      :'app_password'
    );
  END IF;
END
$$;

SELECT format('CREATE DATABASE %I OWNER %I', :'app_db', :'app_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'app_db')\gexec

GRANT ALL PRIVILEGES ON DATABASE :"app_db" TO :"app_user";
