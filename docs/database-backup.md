# Database Backup

HelixKit includes automated daily database backups to Amazon S3.

## How It Works

The `DatabaseBackupJob` runs daily at 4am and:

1. Creates a `pg_dump` of the primary PostgreSQL database
2. Compresses the dump with gzip (~90% size reduction)
3. Uploads to the S3 bucket configured in `postgres_bucket` credential
4. Cleans up temporary files

Backup files are named with timestamps: `helix_kit_production_2025-01-08_04-00-00.sql.gz`

## Configuration

### Required Credentials

Add the following to your Rails credentials (`rails credentials:edit -e production`):

```yaml
aws:
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
  s3_region: eu-north-1
  postgres_bucket: your-backup-bucket-name
```

### Schedule

The backup runs daily at 4am via Solid Queue's recurring tasks (configured in `config/recurring.yml`).

## Manual Backup

To trigger a backup manually:

```bash
# In production
kamal app exec -r web "bin/rails runner 'DatabaseBackupJob.perform_now'"

# In development
rails runner 'DatabaseBackupJob.perform_now'
```

## Restoring from Backup

### 1. Download the backup from S3

```bash
aws s3 cp s3://your-backup-bucket/helix_kit_production_2025-01-08_04-00-00.sql.gz ./backup.sql.gz
```

### 2. Decompress

```bash
gunzip backup.sql.gz
```

### 3. Restore to database

```bash
# For a fresh restore (drops and recreates)
psql -h HOST -U USER -d helix_kit_production < backup.sql

# Or to restore to a different database for testing
createdb helix_kit_restore
psql -h HOST -U USER -d helix_kit_restore < backup.sql
```

## Monitoring

Check backup status in the logs:

```bash
# Production logs
kamal app logs -r jobs | grep -i backup

# Or check Solid Queue
kamal app exec -i -r web "bin/rails c"
> SolidQueue::Job.where("class_name LIKE '%Backup%'").order(created_at: :desc).limit(5)
```

## Retention Policy

Backups are retained indefinitely in S3. To manage storage costs, configure an S3 lifecycle rule in the AWS console:

1. Go to S3 > your-backup-bucket > Management > Lifecycle rules
2. Create a rule to delete objects older than N days (e.g., 90 days)
3. Or transition old backups to Glacier for cheaper storage

## What's Backed Up

Only the **primary database** is backed up. The following auxiliary databases are NOT backed up as they contain ephemeral data:

- `*_queue` - Solid Queue job data (recreated on restart)
- `*_cache` - Solid Cache data (temporary by nature)
- `*_cable` - Solid Cable WebSocket data (session-based)

## Troubleshooting

### Backup fails with "pg_dump failed"

- Check that `pg_dump` is available in the Docker container
- Verify DATABASE_URL is set correctly
- Check PostgreSQL connection from the jobs container

### S3 upload fails

- Verify AWS credentials are correct
- Check the `postgres_bucket` credential is set
- Ensure the S3 bucket exists and allows PutObject
