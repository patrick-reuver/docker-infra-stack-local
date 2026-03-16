# Step 8: Postgres Provisioning for Shared App Runtime

Postgres was provisioned with one shared runtime user and one dedicated database for Twenty CRM.

## Provisioning Model

- One shared app runtime user: `apps_rw_user`
- One database per application: `twenty_db`
- No superuser privileges for application runtime

This keeps complexity low while preserving basic isolation per app database.

## Commands Executed

```bash
# Generate strong password
openssl rand -base64 32

# Run SQL in infra-postgres
docker exec -i infra-postgres psql -U "$POSTGRES_USER" -d postgres
```

SQL logic applied:

```sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'apps_rw_user') THEN
    CREATE ROLE apps_rw_user LOGIN PASSWORD '<generated>' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT;
  ELSE
    ALTER ROLE apps_rw_user WITH LOGIN PASSWORD '<generated>' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT;
  END IF;
END
$$;

CREATE DATABASE twenty_db OWNER apps_rw_user;
GRANT ALL PRIVILEGES ON DATABASE twenty_db TO apps_rw_user;
```

## Validation

```bash
docker exec -e PGPASSWORD="<generated>" infra-postgres \
  psql -U apps_rw_user -d twenty_db -c "SELECT current_user, current_database();"
```

Validation result:

- Login with `apps_rw_user` succeeded.
- `twenty_db` is reachable and writable for the app runtime user.

## Secret Handling

- Credentials were stored locally in `infra_stack_application/.env` for onboarding use.
- No generated secret was added to version-controlled documentation.
