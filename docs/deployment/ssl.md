# SahakariMS — SSL Configuration

## Overview

All SahakariMS traffic uses TLS 1.2+ encryption. We support both **Let's Encrypt** (free, auto-renewed) and **purchased certificates** (for production cooperatives requiring EV/OV certs).

---

## Let's Encrypt Setup (Recommended)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Obtain certificate for API and web app domains
sudo certbot --nginx \
  -d api.sahakarims.np \
  -d app.sahakarims.np \
  --email admin@sahakarims.np \
  --agree-tos \
  --no-eff-email

# Verify auto-renewal timer
sudo systemctl status certbot.timer

# Test renewal (dry run)
sudo certbot renew --dry-run
```

---

## Nginx SSL Configuration

```nginx
# Full SSL server block
server {
    listen 443 ssl http2;
    server_name api.sahakarims.np;

    # Certificate files (Let's Encrypt)
    ssl_certificate     /etc/letsencrypt/live/api.sahakarims.np/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.sahakarims.np/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/api.sahakarims.np/chain.pem;

    # Modern TLS configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;

    # SSL session
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;

    location / {
        proxy_pass http://sahakarims_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## JWT RS256 Key Pair

```bash
# Generate 2048-bit RSA key pair for JWT signing
openssl genrsa -out /opt/sahakari-ms/keys/jwt_private.pem 2048
openssl rsa -in /opt/sahakari-ms/keys/jwt_private.pem -pubout -out /opt/sahakari-ms/keys/jwt_public.pem

# Set permissions (private key readable only by app user)
chmod 600 /opt/sahakari-ms/keys/jwt_private.pem
chmod 644 /opt/sahakari-ms/keys/jwt_public.pem
chown appuser:appgroup /opt/sahakari-ms/keys/jwt_private.pem
```

---

## SSL Rating Target

Target: **A+ rating on SSL Labs** (https://ssllabs.com/ssltest/)

Achieved by:
- TLS 1.2+ only (no SSLv3, TLS 1.0, TLS 1.1)
- Strong cipher suites (ECDHE + AES-GCM)
- HSTS with long max-age and preload
- OCSP stapling enabled
- No weak Diffie-Hellman parameters

---

## Certificate Renewal Alert

Set up an additional cron job to alert 30 days before expiry:

```bash
# Check certificate expiry
0 9 * * * /opt/sahakari-ms/scripts/check-cert.sh >> /var/log/cert-check.log 2>&1
```

```bash
#!/bin/bash
# scripts/check-cert.sh
DOMAIN="api.sahakarims.np"
EXPIRY_DATE=$(openssl s_client -connect ${DOMAIN}:443 -servername ${DOMAIN} \
    </dev/null 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "${EXPIRY_DATE}" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt 30 ]; then
    curl -s -X POST https://api.sparrowsms.com/v2/sms/ \
      -d "token=${SPARROW_TOKEN}&from=SahakariMS&to=${ADMIN_PHONE}&text=SSL Certificate expires in ${DAYS_LEFT} days!"
    echo "ALERT: Certificate expires in ${DAYS_LEFT} days"
fi
```
