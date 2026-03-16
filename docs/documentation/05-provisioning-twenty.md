# Step 5: Provisioning Twenty CRM

Before connecting Twenty CRM to the shared infrastructure, the necessary resources (database and storage bucket) must be provisioned.

## 1. Database Provisioning (Postgres)

Once the `infra-stack` is running, execute the following commands to create a dedicated user and database for Twenty CRM.

### Commands

```sql
-- Connect to Postgres as root
-- docker exec -it infra-postgres psql -U postgres

-- Create user and database
CREATE USER twenty_user WITH ENCRYPTED PASSWORD 'PnwdAKd/xbXvfANOv8UsgdIGKrmySpvy';
CREATE DATABASE twenty_db OWNER twenty_user;
GRANT ALL PRIVILEGES ON DATABASE twenty_db TO twenty_user;
```

## 2. Storage Provisioning (MinIO)

Twenty CRM requires an S3-compatible bucket for file storage.

### Credentials

- **Access Key**: `minioadmin` (Root User)
- **Secret Key**: `change_me_minio` (as defined in `.env`)
- **Bucket Name**: `twenty`

### Commands (via MinIO Client `mc`)

```bash
# Set alias if not already done
mc alias set local http://localhost:9000 minioadmin change_me_minio

# Create bucket
mc mb local/twenty

# Set bucket to download (optional, depending on Twenty CRM requirements for public access)
mc anonymous set download local/twenty
```

## Security Credentials Summary

> [!IMPORTANT]
> Keep these credentials safe and use them in the next step to configure the `twenty-crm-application/.env` file.
> - **DB User**: `twenty_user`
> - **DB Password**: `PnwdAKd/xbXvfANOv8UsgdIGKrmySpvy`
> - **DB Name**: `twenty_db`
