# SahakariMS — Testing: Security Testing

## Overview

Security testing identifies vulnerabilities before attackers do. SahakariMS undergoes automated SAST, dependency scanning, and manual penetration testing before each major release.

---

## Security Testing Layers

| Layer | Tool | When |
|-------|------|------|
| SAST (Static Analysis) | SonarQube, Semgrep | Every PR |
| Dependency Scan | OWASP Dependency-Check | Daily CI job |
| Secret Detection | Gitleaks, TruffleHog | Every commit |
| DAST (Dynamic) | OWASP ZAP | Pre-release |
| Penetration Test | Manual (external firm) | Pre v1.0 |
| SSL/TLS | SSL Labs test | Before production |

---

## OWASP Top 10 Test Cases

### A01 — Broken Access Control

```bash
# Test: Can a Cashier approve loans? (LOANS_APPROVE required)
TOKEN=$(get_cashier_token)
curl -X POST https://api.sahakarims.np/api/v1/loans/${LOAN_ID}/approve \
  -H "Authorization: Bearer ${TOKEN}"
# Expected: 403 Forbidden

# Test: Can a user from Branch A access Branch B data?
TOKEN=$(get_ktm_cashier_token)
curl https://api.sahakarims.np/api/v1/members/${PKR_MEMBER_ID} \
  -H "Authorization: Bearer ${TOKEN}"
# Expected: 404 Not Found (RLS hides it) or 403

# Test: Accessing admin endpoints without auth
curl https://api.sahakarims.np/api/v1/admin/users
# Expected: 401 Unauthorized

# Test: JWT with tampered payload
# Manually change branchId in JWT (without re-signing)
# Expected: 401 Invalid signature
```

### A02 — Cryptographic Failures

```bash
# Test: Is password stored in plaintext?
docker exec sahakarims-db psql -U sahakarims -d sahakarims_prod \
  -c "SELECT username, password_hash FROM users LIMIT 3"
# Expected: hash starts with $2b$ (bcrypt)

# Test: Is PAN stored encrypted?
docker exec sahakarims-db psql -U sahakarims -d sahakarims_prod \
  -c "SELECT pan_number FROM members WHERE pan_number IS NOT NULL LIMIT 3"
# Expected: base64 string (AES-256 encrypted), NOT plaintext like "123456789"

# Test: TLS version
nmap --script ssl-enum-ciphers -p 443 api.sahakarims.np
# Expected: Only TLSv1.2 and TLSv1.3, no weak ciphers
```

### A03 — Injection (SQL Injection)

```bash
# Test: SQL injection in member search
curl "https://api.sahakarims.np/api/v1/members?search=' OR 1=1--" \
  -H "Authorization: Bearer ${TOKEN}"
# Expected: 200 with empty results or escaped search, NOT all members

# Test: SQL injection in loan amount
curl -X POST https://api.sahakarims.np/api/v1/loans \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{"amount": "100000; DROP TABLE loans;--"}'
# Expected: 400 Bad Request (validation) or safe parameterized query
```

### A05 — Security Misconfiguration

```bash
# Test: Swagger exposed in production
curl https://api.sahakarims.np/swagger
# Expected: 404 (blocked in Nginx for production)

# Test: Debug headers
curl -I https://api.sahakarims.np/api/v1/members
# Expected: NO Server: Kestrel header, NO X-AspNet-Version

# Test: Directory listing disabled
curl https://api.sahakarims.np/api/
# Expected: 404, not a file listing

# Test: CORS policy
curl -H "Origin: https://evil.com" https://api.sahakarims.np/api/v1/members
# Expected: Access-Control-Allow-Origin: https://app.sahakarims.np only
```

### A07 — Authentication Failures

```bash
# Test: Brute force protection
for i in {1..10}; do
  curl -X POST https://api.sahakarims.np/api/v1/auth/login \
    -d '{"username":"admin@test.np","password":"wrong"}'
done
# Expected: After 5 attempts, account locked for 15 minutes

# Test: Weak password accepted?
curl -X POST https://api.sahakarims.np/api/v1/auth/change-password \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{"newPassword":"123"}'
# Expected: 400 Bad Request (password too weak)

# Test: Expired JWT accepted?
# Use a JWT with exp in the past
# Expected: 401 Unauthorized

# Test: JWT with wrong algorithm (algorithm confusion)
# Craft HS256 token using public key as HMAC secret
# Expected: 401 Invalid token
```

### A09 — Security Logging Failures

```bash
# Test: Failed login is logged
curl -X POST https://api.sahakarims.np/api/v1/auth/login \
  -d '{"username":"admin","password":"wrong"}'

# Check login_history table
docker exec sahakarims-db psql -U sahakarims -d sahakarims_prod \
  -c "SELECT * FROM audit.login_history WHERE status='Failed' ORDER BY login_at DESC LIMIT 1"
# Expected: Record with IP, username, failure reason
```

---

## OWASP ZAP Automated Scan

```bash
# Install ZAP
docker pull ghcr.io/zaproxy/zaproxy:stable

# Run API scan against OpenAPI spec
docker run -v $(pwd):/zap/wrk/:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py \
  -t https://api.sahakarims.np/swagger/v1/swagger.json \
  -f openapi \
  -r zap-report.html \
  -I  # Ignore informational alerts

# Expected: 0 HIGH/CRITICAL findings before release
# Review all MEDIUM findings for false positives
```

---

## Security Headers Check

```bash
# All responses should include security headers
curl -I https://api.sahakarims.np/api/v1/health

# Check for:
# Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
# Referrer-Policy: strict-origin-when-cross-origin
# Content-Security-Policy: (if serving HTML)
```

---

## Dependency Vulnerability Scan

```bash
# .NET dependencies
dotnet list src/backend/SahakariMS.API package --vulnerable --include-transitive

# Node.js (if any)
npm audit --audit-level=high

# Run OWASP Dependency-Check
docker run --rm \
  -v $(pwd):/src \
  -v $(pwd)/owasp-reports:/report \
  owasp/dependency-check \
  --project "SahakariMS" \
  --scan /src \
  --format HTML \
  --out /report \
  --failOnCVSS 7
```

---

## Security Checklist Before v1.0

- [ ] OWASP ZAP scan: 0 HIGH/CRITICAL findings
- [ ] SonarQube: Security hotspots all reviewed
- [ ] All dependencies: 0 HIGH CVEs
- [ ] Penetration test: External firm report reviewed
- [ ] SSL Labs: A+ rating
- [ ] Sensitive data audit: All PII fields encrypted
- [ ] Secrets audit: No hardcoded keys in codebase (Gitleaks clean)
- [ ] CORS policy: Only allowed origins
- [ ] Error responses: No stack traces in production
- [ ] Rate limiting: Verified at 100+ req/min
- [ ] JWT: RS256 (not HS256), short TTL, proper validation
- [ ] Admin default password: Changed before deployment
