# SahakariMS — Deployment: Nginx Configuration

## Overview

Nginx serves as the reverse proxy and SSL termination point for all SahakariMS services. It sits in front of the ASP.NET Core API, handles HTTPS, and enforces security headers.

---

## Architecture Position

```
Internet
    │
    ▼
Nginx :443 (HTTPS)
    │
    ├──▶ ASP.NET Core API   :8080 (internal)
    ├──▶ MinIO Console       :9001 (restricted)
    └──▶ Grafana             :3000 (restricted)
```

---

## nginx.conf (Production)

```nginx
# /etc/nginx/nginx.conf

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 75;
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript
               application/xml+rss text/xml image/svg+xml;

    # Security
    server_tokens off;
    client_max_body_size 20M;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=upload:10m rate=10r/m;

    # Connection limit per IP
    limit_conn_zone $binary_remote_addr zone=conn:10m;
    limit_conn conn 30;

    include /etc/nginx/conf.d/*.conf;
}
```

---

## API Virtual Host (conf.d/api.conf)

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name api.sahakarims.np;
    return 301 https://$host$request_uri;
}

# Main HTTPS server
server {
    listen 443 ssl http2;
    server_name api.sahakarims.np;

    # SSL Configuration
    ssl_certificate     /etc/nginx/ssl/sahakarims.np.crt;
    ssl_certificate_key /etc/nginx/ssl/sahakarims.np.key;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_dhparam         /etc/nginx/ssl/dhparam.pem;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    add_header Content-Security-Policy "default-src 'none'; script-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; font-src 'self'; frame-ancestors 'none'" always;

    # Remove server identification
    server_tokens off;
    more_clear_headers Server;

    # Health check (no auth, no rate limit)
    location /health {
        proxy_pass http://sahakarims-api:8080;
        proxy_http_version 1.1;
        access_log off;
    }

    # Login endpoint — strict rate limiting (5 per minute)
    location /api/v1/auth/login {
        limit_req zone=login burst=3 nodelay;
        limit_req_status 429;

        proxy_pass http://sahakarims-api:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Consistent response time to prevent timing attacks
        proxy_read_timeout 10s;
    }

    # Document upload endpoint
    location /api/v1/documents/upload {
        limit_req zone=upload burst=5 nodelay;
        client_max_body_size 20M;

        proxy_pass http://sahakarims-api:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 120s;  # Allow time for large uploads
    }

    # Swagger UI — block in production
    location /swagger {
        return 404;
    }

    # General API — standard rate limiting (60 per minute)
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        limit_req_status 429;

        proxy_pass http://sahakarims-api:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";

        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;

        proxy_connect_timeout 10s;
        proxy_read_timeout 30s;
        proxy_send_timeout 10s;

        # Handle 429 gracefully
        error_page 429 @rate_limit_exceeded;
    }

    location @rate_limit_exceeded {
        default_type application/json;
        return 429 '{"error":"Too many requests. Please try again in 1 minute.","retryAfter":60}';
    }
}

# Grafana — restricted to internal network only
server {
    listen 443 ssl http2;
    server_name monitoring.sahakarims.np;

    ssl_certificate     /etc/nginx/ssl/sahakarims.np.crt;
    ssl_certificate_key /etc/nginx/ssl/sahakarims.np.key;

    # Only allow internal IP range
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    deny all;

    location / {
        proxy_pass http://sahakarims-grafana:3000;
        proxy_set_header Host $host;
    }
}
```

---

## Nginx in Docker Compose

```yaml
# docker-compose.prod.yml
nginx:
  image: nginx:1.27-alpine
  container_name: sahakarims-nginx
  restart: unless-stopped
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - ./nginx/conf.d:/etc/nginx/conf.d:ro
    - ./nginx/ssl:/etc/nginx/ssl:ro
    - nginx-logs:/var/log/nginx
  depends_on:
    - api
  networks:
    - sahakarims-net
```

---

## Test Nginx Config

```bash
# Validate configuration before applying
docker exec sahakarims-nginx nginx -t

# Reload without downtime
docker exec sahakarims-nginx nginx -s reload

# Test SSL
openssl s_client -connect api.sahakarims.np:443 -tls1_2 2>&1 | head -20

# Test security headers
curl -I https://api.sahakarims.np/health | grep -E "Strict|X-Content|X-Frame|Referrer"
```
