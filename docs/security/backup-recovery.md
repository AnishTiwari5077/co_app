# SahakariMS — Security: Backup & Recovery

## Backup Strategy

SahakariMS follows the **3-2-1 backup rule**:
- **3** copies of data
- **2** different storage media/locations
- **1** offsite copy

| Copy | Location | Retention |
|------|----------|-----------|
| Primary | PostgreSQL WAL (continuous) | Real-time |
| Daily backup | Local server `/opt/backups/` | 7 days |
| Remote backup | MinIO `backups` bucket | 30 days |
| Monthly archive | External HDD / NAS | 10 years |

---

## Backup Schedule

| Job | Frequency | Time | Type |
|-----|-----------|------|------|
| WAL archiving | Continuous | Always | Transaction log |
| Full DB dump | Daily | 2:00 AM | Full |
| MinIO sync | Daily | 2:30 AM | Remote copy |
| Monthly archive | 1st of month | 3:00 AM | Long-term |
| Verify backup | Weekly (Sunday) | 4:00 AM | Restore test |

---

## Backup Script

```bash
#!/bin/bash
# /opt/sahakari-ms/scripts/backup.sh

set -euo pipefail

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/sahakarims"
DB_BACKUP="${BACKUP_DIR}/db_${DATE}.dump"
LOG_FILE="/var/log/sahakarims-backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

mkdir -p "$BACKUP_DIR"

# 1. Database backup
log "Starting PostgreSQL backup..."
docker exec sahakarims-db pg_dump \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  --format=custom \
  --compress=9 \
  --verbose \
  > "${DB_BACKUP}"

if [ $? -ne 0 ]; then
  log "ERROR: PostgreSQL backup FAILED"
  send_alert "Database backup FAILED at $(date)"
  exit 1
fi

DB_SIZE=$(du -sh "${DB_BACKUP}" | cut -f1)
log "Database backup completed: ${DB_BACKUP} (${DB_SIZE})"

# 2. Encrypt backup
log "Encrypting backup..."
gpg --batch --yes \
    --symmetric \
    --cipher-algo AES256 \
    --passphrase "${BACKUP_GPG_PASSPHRASE}" \
    --output "${DB_BACKUP}.gpg" \
    "${DB_BACKUP}"
rm -f "${DB_BACKUP}"
log "Backup encrypted: ${DB_BACKUP}.gpg"

# 3. Copy to MinIO
log "Uploading to MinIO..."
docker exec sahakarims-minio mc cp \
  "${DB_BACKUP}.gpg" \
  "minio/backups/daily/$(basename ${DB_BACKUP}.gpg)"
log "Upload to MinIO complete"

# 4. Cleanup old local backups (keep 7 days)
find "${BACKUP_DIR}" -name "db_*.dump.gpg" -mtime +7 -delete
log "Old backups cleaned up"

# 5. Verify backup size is reasonable (> 100KB)
SIZE=$(stat -c%s "${DB_BACKUP}.gpg")
if [ "$SIZE" -lt 102400 ]; then
  log "WARNING: Backup file seems too small (${SIZE} bytes)"
  send_alert "Backup suspiciously small: ${SIZE} bytes"
fi

log "Backup process completed successfully"

send_alert() {
  curl -s -X POST https://api.sparrowsms.com/v2/sms/ \
    -d "token=${SPARROW_TOKEN}&from=SahakariMS&to=${ADMIN_PHONE}&text=$1"
}
```

---

## Point-in-Time Recovery (PITR)

For granular recovery, PostgreSQL WAL archiving is configured:

```conf
# postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /opt/pg_wal_archive/%f'
restore_command = 'cp /opt/pg_wal_archive/%f %p'
```

This allows recovery to any point in time, not just backup timestamps.

---

## Recovery Procedures

### Scenario 1: Accidental Data Deletion

```bash
# 1. Identify the time of accidental deletion
# (Check audit logs for exact timestamp)

# 2. Stop the application
docker compose -f docker-compose.prod.yml stop api

# 3. Restore from backup to a staging DB
docker exec sahakarims-db createdb sahakarims_recovery -U sahakarims

# 4. Decrypt and restore
gpg --decrypt --passphrase "${BACKUP_GPG_PASSPHRASE}" \
    backup_file.dump.gpg > backup.dump

docker exec -i sahakarims-db pg_restore \
  -U sahakarims \
  -d sahakarims_recovery \
  --no-owner \
  backup.dump

# 5. Extract specific records from recovery DB
docker exec sahakarims-db psql -U sahakarims sahakarims_recovery \
  -c "SELECT * FROM members WHERE id = 'uuid-of-deleted-record'"

# 6. Insert recovered records into production DB
# (carefully, with manager approval)

# 7. Restart application
docker compose -f docker-compose.prod.yml start api
```

### Scenario 2: Complete Server Failure

```bash
# On new server:

# 1. Install Docker and clone repo
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
git clone https://github.com/your-org/sahakari-ms.git /opt/sahakari-ms

# 2. Download latest backup from MinIO
docker run --rm minio/mc mc cp \
  "minio/backups/daily/latest.dump.gpg" /tmp/

# 3. Decrypt
gpg --decrypt --passphrase "$PASSPHRASE" /tmp/latest.dump.gpg > /tmp/restore.dump

# 4. Start DB container only
docker compose -f docker-compose.prod.yml up -d db

# 5. Restore
docker exec -i sahakarims-db pg_restore \
  -U sahakarims -d sahakarims_prod \
  --no-owner --clean /tmp/restore.dump

# 6. Restore keys and env
# (copy from secure password manager)
cp keys/* /opt/sahakari-ms/keys/
cp .env /opt/sahakari-ms/

# 7. Start all services
docker compose -f docker-compose.prod.yml up -d

# 8. Verify health
curl https://api.sahakarims.np/health

# Expected RTO: 2–4 hours
# Expected RPO: < 24 hours (daily backup) or seconds (with WAL)
```

### Scenario 3: Corrupt Database

```bash
# 1. Check PostgreSQL logs for corruption details
docker logs sahakarims-db 2>&1 | grep -i "corrupt\|invalid\|error"

# 2. Try pg_resetwal if WAL corruption (last resort)
# WARNING: This may cause data loss
docker exec sahakarims-db pg_resetwal -D /var/lib/postgresql/data

# 3. If above fails, full restore from backup
```

---

## Backup Verification (Weekly)

```bash
#!/bin/bash
# /opt/sahakari-ms/scripts/verify-backup.sh
# Runs every Sunday at 4:00 AM

LATEST_BACKUP=$(ls -t /opt/backups/sahakarims/db_*.dump.gpg | head -1)

# Decrypt
gpg --batch --decrypt \
    --passphrase "${BACKUP_GPG_PASSPHRASE}" \
    "${LATEST_BACKUP}" > /tmp/verify_restore.dump

# Create temp database
docker exec sahakarims-db createdb sahakarims_verify -U sahakarims

# Restore
docker exec -i sahakarims-db pg_restore \
  -U sahakarims -d sahakarims_verify \
  --no-owner /tmp/verify_restore.dump

# Verify row counts
MEMBER_COUNT=$(docker exec sahakarims-db psql -U sahakarims sahakarims_verify \
  -t -c "SELECT COUNT(*) FROM members WHERE is_deleted = FALSE")

PROD_COUNT=$(docker exec sahakarims-db psql -U sahakarims sahakarims_prod \
  -t -c "SELECT COUNT(*) FROM members WHERE is_deleted = FALSE")

echo "Backup members: ${MEMBER_COUNT} | Production: ${PROD_COUNT}"

# Cleanup
docker exec sahakarims-db dropdb sahakarims_verify -U sahakarims
rm -f /tmp/verify_restore.dump

echo "Backup verification completed successfully"
```

---

## RTO and RPO Targets

| Scenario | RPO (Data Loss) | RTO (Recovery Time) |
|----------|----------------|---------------------|
| Accidental row deletion | 0 (audit log) | 30 minutes |
| Application crash | 0 (WAL) | 5 minutes |
| Server hardware failure | < 24 hours (daily backup) | 2–4 hours |
| Data centre disaster | < 24 hours | 4–8 hours |
| Complete ransomware attack | < 24 hours | 8–24 hours |
