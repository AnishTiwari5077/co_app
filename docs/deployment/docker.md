# SahakariMS — Docker Configuration

## Overview

SahakariMS uses Docker and Docker Compose to containerize all services, ensuring consistent environments from development to production.

---

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| api | Custom (ASP.NET Core 8) | 8080 | REST API server |
| db | postgres:16-alpine | 5432 | Primary database |
| redis | redis:7-alpine | 6379 | Cache + sessions |
| minio | minio/minio:latest | 9000, 9001 | Object storage |
| nginx | nginx:1.26-alpine | 80, 443 | Reverse proxy + SSL |
| hangfire | (same as api) | — | Background jobs |
| prometheus | prom/prometheus | 9090 | Metrics collection |
| grafana | grafana/grafana | 3000 | Metrics dashboard |

---

## API Dockerfile

```dockerfile
# src/backend/Dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy and restore
COPY ["SahakariMS.API/SahakariMS.API.csproj", "SahakariMS.API/"]
COPY ["SahakariMS.Application/SahakariMS.Application.csproj", "SahakariMS.Application/"]
COPY ["SahakariMS.Domain/SahakariMS.Domain.csproj", "SahakariMS.Domain/"]
COPY ["SahakariMS.Infrastructure/SahakariMS.Infrastructure.csproj", "SahakariMS.Infrastructure/"]
RUN dotnet restore "SahakariMS.API/SahakariMS.API.csproj"

# Copy all files and build
COPY . .
WORKDIR "/src/SahakariMS.API"
RUN dotnet build "SahakariMS.API.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
RUN dotnet publish "SahakariMS.API.csproj" -c Release -o /app/publish \
    /p:UseAppHost=false

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Security: non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

COPY --from=publish /app/publish .

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "SahakariMS.API.dll"]
```

---

## Development Docker Compose

```yaml
# docker-compose.dev.yml
version: '3.9'

services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: sahakarims_dev
      POSTGRES_USER: sahakarims
      POSTGRES_PASSWORD: devpassword
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
      - ./docker/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes

  minio:
    image: minio/minio:latest
    restart: unless-stopped
    ports:
      - "9000:9000"   # S3 API
      - "9001:9001"   # MinIO Console
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    command: server /data --console-address ":9001"
    volumes:
      - minio_dev_data:/data

  pgadmin:
    image: dpage/pgadmin4:latest
    restart: unless-stopped
    ports:
      - "5050:80"
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@sahakarims.np
      PGADMIN_DEFAULT_PASSWORD: admin

  redis-commander:
    image: rediscommander/redis-commander:latest
    restart: unless-stopped
    ports:
      - "8081:8081"
    environment:
      REDIS_HOSTS: local:redis:6379

volumes:
  postgres_dev_data:
  minio_dev_data:
```

---

## PostgreSQL Init Script

```sql
-- docker/postgres/init.sql
-- Create schemas
CREATE SCHEMA IF NOT EXISTS accounting;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS hr;
CREATE SCHEMA IF NOT EXISTS inventory;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Performance settings
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '4MB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = '0.9';
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = '100';
SELECT pg_reload_conf();
```

---

## Nginx Configuration

```nginx
# docker/nginx/nginx.conf
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log warn;

events {
    worker_connections  2048;
    use epoll;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format json_combined escape=json
        '{"time":"$time_iso8601",'
        '"status":"$status",'
        '"method":"$request_method",'
        '"uri":"$request_uri",'
        '"duration":"$request_time",'
        '"ip":"$remote_addr",'
        '"bytes":"$body_bytes_sent"}';

    access_log /var/log/nginx/access.log json_combined;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    gzip on;
    gzip_types text/plain application/json application/javascript text/css;

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
    limit_req_zone $binary_remote_addr zone=auth:10m rate=10r/m;

    # Upstream API
    upstream sahakarims_api {
        server api:8080;
        keepalive 32;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name api.sahakarims.np app.sahakarims.np;
        return 301 https://$host$request_uri;
    }

    # API Server
    server {
        listen 443 ssl http2;
        server_name api.sahakarims.np;

        ssl_certificate     /etc/letsencrypt/live/api.sahakarims.np/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/api.sahakarims.np/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        client_max_body_size 50M;  # For document uploads

        location /api/v1/auth {
            limit_req zone=auth burst=5 nodelay;
            proxy_pass http://sahakarims_api;
            include /etc/nginx/proxy_params;
        }

        location /api/ {
            limit_req zone=api burst=50 nodelay;
            proxy_pass http://sahakarims_api;
            include /etc/nginx/proxy_params;
        }

        location /health {
            proxy_pass http://sahakarims_api;
            access_log off;
        }

        location /swagger {
            # Only allow in non-production
            deny all;
        }
    }
}
```

---

## Useful Docker Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs api -f
docker compose logs db -f --tail=100

# Execute commands in container
docker compose exec api bash
docker compose exec db psql -U sahakarims -d sahakarims_prod

# Database backup
docker compose exec db pg_dump -U sahakarims sahakarims_prod > backup.sql

# Database restore
cat backup.sql | docker compose exec -T db psql -U sahakarims sahakarims_prod

# Scale API instances (load balancing)
docker compose up -d --scale api=3

# Update single service
docker compose pull api
docker compose up -d --no-deps api

# View resource usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Clean up unused images
docker system prune -af --volumes
```

---

## Health Checks

```csharp
// Program.cs — health check configuration
builder.Services.AddHealthChecks()
    .AddNpgsql(connectionString, name: "database", tags: ["db"])
    .AddRedis(redisConnectionString, name: "redis", tags: ["cache"])
    .AddMinio(options => {
        options.Endpoint = minioEndpoint;
    }, name: "storage", tags: ["storage"])
    .AddHangfire(options => {
        options.MinimumAvailableServers = 1;
    }, name: "hangfire", tags: ["jobs"]);

app.MapHealthChecks("/health", new HealthCheckOptions
{
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("db")
});
```

Expected `/health` response:
```json
{
  "status": "Healthy",
  "totalDuration": "00:00:00.0512",
  "entries": {
    "database": { "status": "Healthy", "duration": "00:00:00.0102" },
    "redis":    { "status": "Healthy", "duration": "00:00:00.0021" },
    "storage":  { "status": "Healthy", "duration": "00:00:00.0089" }
  }
}
```
