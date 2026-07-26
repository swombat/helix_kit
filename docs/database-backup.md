# Database Backup

HelixKit includes automated daily full backups to Amazon S3: every hosted Chaos
agent's persistent volumes, followed by a dump of the PostgreSQL database.

## How It Works

The `FullBackupJob` runs daily at 4am and:

1. Takes a Restic snapshot of each hosted agent's persistent Docker volumes
   (identity, Chaos home, repo)
2. Creates a `pg_dump` of the primary PostgreSQL database — which records the
   snapshot IDs just taken
3. Compresses the dump with gzip (~90% size reduction)
4. Uploads to the S3 bucket configured in `postgres_bucket` credential
5. Cleans up temporary files

In the scheduled nightly run, a failed agent snapshot is recorded and logged but
does not stop the remaining agents or the database dump — restore only ever uses
the latest *successful* snapshot, so the backup set stays consistent. Agent
snapshots can be disabled globally with `HELIXKIT_AGENT_BACKUPS_ENABLED=false`
(the database dump still runs).

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
  # Optional; defaults to postgres_bucket:
  agent_backups_bucket: your-agent-backup-bucket-name
```

### Schedule

The backup runs daily at 4am via Solid Queue's recurring tasks (configured in `config/recurring.yml`).

## Manual Full Backup

To snapshot all hosted agents and then back up PostgreSQL:

```bash
bin/rails db_backup:perform
```

Each hosted-agent snapshot contains its three persistent Docker volumes:

- identity (`soul.md`, self-narrative, journals, and memory);
- Chaos home (`.chaos`, including persistent session state);
- repository/workspace.

The Restic snapshot records and per-agent repository passwords are included in
the PostgreSQL dump created immediately afterward. Unlike the nightly run, the
manual run is fail-fast: if any agent snapshot fails, the database dump is not
created, so a supervised backup never completes over a knowingly incomplete
agent backup set.

## Restoring from Backup

For the ordinary local-development refresh:

```bash
bin/rails db_backup:refresh
```

The task downloads and restores the latest PostgreSQL dump, resets local user
passwords, then offers to replace the Docker volumes for every hosted agent with
the exact successful Restic snapshot recorded in that dump. Agents that were
running in production are started with the local runtime image and local
HelixKit endpoint; agents that were offline remain restored but stopped.

You can rerun only the agent-volume part after a database restore:

```bash
bin/rails db_backup:restore_agents
```

Both restore steps prompt before replacing local state.

Docker must be running before the agent-volume restore begins. If PostgreSQL has
already been restored but Docker was unavailable, start Docker and resume with:

```bash
bin/rails db_backup:restore_agents
```

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

Both the scheduled nightly `FullBackupJob` and the manual `db_backup:perform`
back up all hosted-agent volumes and the primary database. The following
auxiliary databases are not backed up because they contain ephemeral data:

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

### Agent restore says the Docker daemon is not reachable

- Start Docker Desktop (or the local Docker daemon).
- Confirm `docker info` succeeds in the same shell.
- Run `bin/rails db_backup:restore_agents`; the database does not need to be
  restored again.
