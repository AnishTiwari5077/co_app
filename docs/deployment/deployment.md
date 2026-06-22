# SahakariMS — Production Deployment Guide

## Server Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| CPU | 4 vCPU | 8 vCPU |
| RAM | 8 GB | 16 GB |
| Disk | 100 GB SSD | 500 GB SSD |
| Network | 100 Mbps | 1 Gbps |
| Backup Storage | 500 GB | 2 TB |

---

## Pre-Deployment Checklist

- [ ] Domain name configured and DNS propagated
- [ ] SSL certificate obtained (Let's Encrypt or purchased)
- [ ] Firewall configured (only ports 22, 80, 443 open)
- [ ] PostgreSQL backup strategy confirmed
- [ ] Monitoring alerts configured
- [ ] Environment variables populated in `.env`
- [ ] Docker and Docker Compose installed
- [ ] Swap space configured (at least 4 GB)

---

## Step 1: Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Configure swap (4 GB)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Configure system limits for PostgreSQL
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure UFW firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

---

## Step 2: Clone Repository

```bash
cd /opt
sudo git clone https://github.com/your-org/sahakari-ms.git
sudo chown -R $USER:$USER sahakari-ms
cd sahakari-ms
```

---

## Step 3: Configure Environment

```bash
cp .env.example .env
nano .env
```

### Required `.env` Values

```env
# Application
APP_ENV=Production
APP_URL=https://api.sahakarims.np
FLUTTER_WEB_URL=https://app.sahakarims.np

# Database
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=sahakarims_prod
POSTGRES_USER=sahakarims
POSTGRES_PASSWORD=<STRONG_PASSWORD_HERE>

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<STRONG_REDIS_PASSWORD>

# JWT (RS256 keys — generate with: openssl genrsa -out private.pem 2048)
JWT_PRIVATE_KEY_PATH=/app/keys/private.pem
JWT_PUBLIC_KEY_PATH=/app/keys/public.pem
JWT_ISSUER=sahakarims.np
JWT_AUDIENCE=sahakarims-api

# MinIO
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=<ACCESS_KEY>
MINIO_SECRET_KEY=<SECRET_KEY>
MINIO_USE_SSL=false

# SMS Gateway (Sparrow SMS)
SPARROW_SMS_TOKEN=<TOKEN>
SPARROW_SMS_FROM=SahakariMS

# Email
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=<SENDGRID_API_KEY>
SMTP_FROM=noreply@sahakarims.np

# Firebase FCM
FIREBASE_PROJECT_ID=sahakarims
FIREBASE_SERVICE_ACCOUNT_PATH=/app/keys/firebase-service-account.json

# Encryption
AES_ENCRYPTION_KEY=<32_BYTE_HEX_KEY>
AES_ENCRYPTION_IV=<16_BYTE_HEX_IV>
```

---

## Step 4: Generate JWT Keys

```bash
mkdir -p /opt/sahakari-ms/keys
cd /opt/sahakari-ms/keys

# Generate RS256 key pair
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -outform PEM -pubout -out public.pem

# Secure permissions
chmod 600 private.pem
chmod 644 public.pem
```

---

## Step 5: Build and Start Services

```bash
cd /opt/sahakari-ms

# Pull latest images and build
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml build

# Start all services
docker compose -f docker-compose.prod.yml up -d

# Check all services are running
docker compose -f docker-compose.prod.yml ps
```

---

## Step 6: Database Migration

```bash
# Run EF Core migrations
docker compose -f docker-compose.prod.yml exec api \
  dotnet ef database update \
  --project SahakariMS.Infrastructure \
  --startup-project SahakariMS.API

# Seed initial data (chart of accounts, roles, permissions, default admin)
docker compose -f docker-compose.prod.yml exec api \
  dotnet run --project scripts/SeedData -- --env Production
```

---

## Step 7: Configure SSL with Nginx

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Obtain certificate
sudo certbot --nginx -d api.sahakarims.np -d app.sahakarims.np

# Auto-renewal cron (certbot installs this automatically)
sudo systemctl status certbot.timer
```

---

## Step 8: Verify Deployment

```bash
# Check API health
curl https://api.sahakarims.np/health

# Expected response:
# {"status":"Healthy","database":"Connected","redis":"Connected","storage":"Connected"}

# Check all containers
docker compose -f docker-compose.prod.yml ps

# View API logs
docker compose -f docker-compose.prod.yml logs api --tail=50

# View database logs
docker compose -f docker-compose.prod.yml logs db --tail=50
```

---

## Step 9: Setup Automated Backups

```bash
# Add backup cron job
crontab -e

# Add these lines:
# Daily backup at 2:00 AM
0 2 * * * /opt/sahakari-ms/scripts/backup.sh >> /var/log/sahakarims-backup.log 2>&1
# Weekly verify backup at Sunday 4:00 AM
0 4 * * 0 /opt/sahakari-ms/scripts/verify-backup.sh >> /var/log/sahakarims-backup.log 2>&1
```

### Backup Script

```bash
#!/bin/bash
# scripts/backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="sahakarims_backup_${DATE}.sql.gz"
BACKUP_PATH="/tmp/${BACKUP_FILE}"
MINIO_BUCKET="backups"

echo "[$(date)] Starting backup..."

# Dump PostgreSQL
docker exec sahakarims-db pg_dump \
  -U $POSTGRES_USER \
  -d $POSTGRES_DB \
  --format=custom \
  --compress=9 \
  > ${BACKUP_PATH}

if [ $? -eq 0 ]; then
  echo "[$(date)] Database dumped successfully ($(du -sh ${BACKUP_PATH}))"

  # Encrypt backup
  gpg --symmetric --cipher-algo AES256 \
      --passphrase "${BACKUP_ENCRYPTION_PASSPHRASE}" \
      --batch -o "${BACKUP_PATH}.gpg" "${BACKUP_PATH}"

  # Upload to MinIO
  docker exec sahakarims-minio mc cp \
    "/tmp/${BACKUP_FILE}.gpg" \
    "minio/${MINIO_BUCKET}/${BACKUP_FILE}.gpg"

  echo "[$(date)] Backup uploaded to MinIO successfully"

  # Clean up local file
  rm -f "${BACKUP_PATH}" "${BACKUP_PATH}.gpg"

  # Delete backups older than 30 days
  docker exec sahakarims-minio mc rm \
    --recursive --force \
    --older-than 30d \
    "minio/${MINIO_BUCKET}/"
else
  echo "[$(date)] ERROR: Database dump failed!"
  # Send alert SMS
  curl -s -X POST https://api.sparrowsms.com/v2/sms/ \
    -d "token=${SPARROW_SMS_TOKEN}&from=SahakariMS&to=${ADMIN_PHONE}&text=ALERT: Database backup failed at $(date)"
fi
```

---

## Step 10: Post-Deployment Configuration

```bash
# 1. Change default admin password
# Login to app as admin@sahakarims.np / Admin@123
# Immediately change password via Settings → Profile

# 2. Configure chart of accounts
# Navigate to Accounting → Setup → Chart of Accounts
# Import Nepal cooperative standard chart

# 3. Configure interest rates per scheme
# Navigate to Settings → Saving Schemes

# 4. Configure loan products
# Navigate to Settings → Loan Products

# 5. Configure SMS templates
# Navigate to Settings → Notifications → SMS Templates

# 6. Set fiscal year
# Navigate to Accounting → Fiscal Year → New Fiscal Year
# Set BS year, start date, end date
```

---

## Docker Production Compose

```yaml
# docker-compose.prod.yml
version: '3.9'

services:
  api:
    image: ghcr.io/your-org/sahakarims-api:latest
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      ASPNETCORE_ENVIRONMENT: Production
      ASPNETCORE_URLS: http://+:8080
    env_file: .env
    volumes:
      - ./keys:/app/keys:ro
    networks: [sahakarims-net]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./docker/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks: [sahakarims-net]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    volumes:
      - redis_data:/data
    networks: [sahakarims-net]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s

  minio:
    image: minio/minio:latest
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - minio_data:/data
    networks: [sahakarims-net]

  nginx:
    image: nginx:1.26-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on: [api]
    networks: [sahakarims-net]

volumes:
  postgres_data:
  redis_data:
  minio_data:

networks:
  sahakarims-net:
    driver: bridge
```

---

## Monitoring Setup

```bash
# Start monitoring stack
docker compose -f docker-compose.monitoring.yml up -d

# Access Grafana at http://localhost:3000
# Default: admin / admin (change immediately)

# Import dashboards from docker/grafana/dashboards/
```

---

## Rollback Procedure

```bash
# Roll back to previous version
docker compose -f docker-compose.prod.yml down api

# Pull previous image version
docker pull ghcr.io/your-org/sahakarims-api:v1.0.1

# Update docker-compose.prod.yml image tag
# Restart
docker compose -f docker-compose.prod.yml up -d api

# If database migration needs rollback
docker compose -f docker-compose.prod.yml exec api \
  dotnet ef migrations script <PreviousMigration> <TargetMigration> | \
  docker exec -i sahakarims-db psql -U $POSTGRES_USER -d $POSTGRES_DB
```
