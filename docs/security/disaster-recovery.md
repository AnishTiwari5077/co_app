# SahakariMS — Security: Disaster Recovery

## Overview

The Disaster Recovery (DR) plan defines how SahakariMS recovers from catastrophic failures — data center fire, ransomware, or complete server destruction. This complements the [backup-recovery.md](./backup-recovery.md) operational runbook.

---

## Recovery Objectives

| Metric | Target | Notes |
|--------|--------|-------|
| **RTO** (Recovery Time Objective) | 4 hours | System back online within 4 hours of disaster |
| **RPO** (Recovery Point Objective) | 24 hours | Maximum data loss of 1 day (daily backup) |
| **MTTR** (Mean Time To Recover) | 2 hours | For common failures (not disasters) |
| **Backup Test** | Monthly | Restore test to verify backup validity |

---

## Disaster Scenarios and Responses

### Scenario 1: Server Hardware Failure

```
IMPACT: Application down, DB inaccessible
RESPONSE TIME: 1–2 hours

Steps:
1. Identify failure (hardware diagnostics)
2. Notify stakeholders (branch managers, admin)
3. Provision new server (VM or bare metal)
4. Install Docker:
   curl -fsSL https://get.docker.com | sh
5. Clone repository:
   git clone git@github.com:org/sahakari-ms.git /opt/sahakari-ms
6. Download latest backup from MinIO:
   mc cp minio/backups/daily/latest.dump.gpg /tmp/
7. Decrypt and restore:
   gpg --decrypt ... | pg_restore ...
8. Restore secrets from password manager
9. Start services:
   docker compose -f docker-compose.prod.yml up -d
10. Verify health:
    curl https://api.sahakarims.np/health
11. Notify stakeholders — system restored

CHECKLIST PERSON: System Administrator
```

### Scenario 2: Ransomware Attack

```
IMPACT: All data encrypted, system unusable
RESPONSE TIME: 8–24 hours (longer due to forensics)

CRITICAL: Do NOT pay ransom.

Steps:
1. IMMEDIATELY disconnect server from network (unplug)
2. Contact cybersecurity incident response team
3. Preserve forensic evidence (do not boot system)
4. Spin up new clean server (never restore to infected machine)
5. Verify backup integrity (test on isolated network):
   - Check backup dates — use most recent BEFORE infection
   - Verify GPG signature
   - Restore to test environment first
6. Conduct forensics on old server (parallel):
   - Identify attack vector
   - Identify compromised credentials
   - Document for insurance claim
7. Rotate ALL credentials before going live:
   - PostgreSQL passwords
   - JWT private key (regenerate)
   - AES encryption key (re-encrypt all data)
   - MinIO credentials
   - SSH keys
   - SSL certificate (new private key)
8. Restore from clean backup to new server
9. Apply all security patches
10. OWASP ZAP scan before going live
11. File police report and cyber insurance claim
12. Post-incident review within 48 hours

CHECKLIST PERSON: System Administrator + Management
```

### Scenario 3: Data Center Fire / Flood

```
IMPACT: Physical server destroyed
RESPONSE TIME: 4–8 hours

Steps:
1. Contact cloud provider or alternative data center
2. Provision VMs (Azure, AWS, DigitalOcean, or local Hosting Nepal)
3. Follow Scenario 1 steps 4–11 above
4. Update DNS to new server IP
5. Wait for DNS propagation (TTL: recommend 300s in advance)

PREVENTIVE MEASURE: Keep daily backup in MinIO on separate physical location
```

### Scenario 4: Database Corruption

```
IMPACT: Partial or full data loss
RESPONSE TIME: 30 minutes – 2 hours

Steps:
1. Stop application immediately
2. Create full dump of corrupted DB (even if corrupt — for forensics)
3. Identify corruption extent:
   pg_dumpall --schema-only -U sahakarims 2>&1 | grep "ERROR"
4. If partial corruption (specific tables only):
   - Restore only affected tables from backup
   - pg_restore -t members -d sahakarims_prod backup.dump
5. If full corruption:
   - Full restore from last good backup
   - Apply WAL archives if available (PITR)
6. Verify data integrity:
   - Check member count matches expected
   - Verify financial totals
7. Restart application

CHECKLIST PERSON: DBA or System Administrator
```

---

## Offsite Backup Configuration

Primary backup to MinIO is on the same server. Offsite backup is **critical**:

```bash
#!/bin/bash
# /opt/sahakari-ms/scripts/offsite-backup.sh
# Runs daily after main backup via cron

# Sync to MinIO on separate server/location
docker run --rm \
  -e MINIO_SOURCE_URL=http://sahakarims-minio:9000 \
  -e MINIO_DEST_URL=https://offsite-minio.sahakarims.np \
  -e ACCESS_KEY=${OFFSITE_MINIO_ACCESS} \
  -e SECRET_KEY=${OFFSITE_MINIO_SECRET} \
  minio/mc mirror \
    --overwrite \
    source/backups \
    dest/sahakarims-backups

# Alternative: rsync to remote server
rsync -avz --delete \
  /opt/backups/sahakarims/ \
  backup@192.168.100.50:/opt/sahakari-ms-backups/
```

---

## Disaster Recovery Contacts

```yaml
Primary Contact:
  Name: System Administrator
  Phone: 98XXXXXXXX
  Email: admin@sahakarims.np
  Available: 24/7

Secondary Contact:
  Name: Branch Manager (Head Office)
  Phone: 98XXXXXXXX
  Email: manager@sahakarims.np

Hosting Provider Support:
  Provider: Hosting Nepal / DigitalOcean
  Support: support@hostingnepal.com
  Emergency: +1-XXX-XXX-XXXX

PostgreSQL Expert (on-call):
  Contact: [DBA consultant contact]

Cyber Incident Response:
  Nepal CERT: www.nepalcert.gov.np
  Hotline: [NepCERT hotline]
```

---

## Annual DR Test

Every year before monsoon season:

1. Restore backup to isolated test server
2. Verify all data is intact and correct
3. Measure actual RTO (time from start to system up)
4. Update DR plan based on findings
5. Brief all stakeholders on DR procedures
6. Update contact list

**Goal:** Prove RTO < 4 hours and RPO < 24 hours annually.
