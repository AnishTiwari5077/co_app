# SahakariMS — Security Architecture

## Security Principles

SahakariMS applies **Defence in Depth** — multiple layers of security so that if one layer fails, others continue to protect the system.

| Layer | Control |
|-------|---------|
| Network | Nginx, firewall, TLS |
| Application | JWT, RBAC, rate limiting |
| Data | Encryption, parameterized queries |
| Audit | Complete activity logging |
| Operational | Backups, disaster recovery |

---

## Authentication

### JWT (JSON Web Token)

- **Algorithm**: RS256 (asymmetric — private key signs, public key verifies)
- **Access Token TTL**: 15 minutes
- **Refresh Token TTL**: 7 days
- **Refresh Token Rotation**: Every refresh issues a new refresh token and invalidates the old one
- **Stored in**: `flutter_secure_storage` (iOS Keychain / Android Keystore)

```
Access Token Claims:
{
  "sub": "user-uuid",
  "name": "Ram Bahadur Shrestha",
  "email": "ram@sahakarims.np",
  "branchId": "branch-uuid",
  "roles": ["Cashier"],
  "perms": ["SAVINGS_DEPOSIT", "SAVINGS_WITHDRAW"],
  "iat": 1719000000,
  "exp": 1719000900
}
```

### Two-Factor Authentication (2FA)

- **Primary**: TOTP (Time-based One-Time Password) via Google Authenticator, Authy
- **Fallback**: SMS OTP via Sparrow SMS (6-digit, valid 5 minutes)
- **Enforcement**: Mandatory for Administrator and Manager roles
- **Optional**: For other roles (configurable per branch)

### OTP Security

```
OTP Properties:
- Length: 6 digits
- TTL: 5 minutes
- Max attempts: 3 (then new OTP required)
- Rate limit: Max 3 OTP requests per 15 minutes per phone number
- Storage: Redis (key: "otp:{phone}:{purpose}", value: hashed OTP)
```

---

## Authorization (RBAC)

### Role Hierarchy

```
Administrator
  └── Manager
        ├── Accountant
        ├── Loan Officer
        │     └── Collector
        └── Cashier
              └── Teller

Auditor (read-only cross-role)
Member (external — mobile app only)
```

### Permission Structure

Permissions follow the format: `{MODULE}_{ACTION}`

| Module | Actions |
|--------|---------|
| MEMBERS | VIEW, CREATE, EDIT, APPROVE, CLOSE |
| SAVINGS | VIEW, DEPOSIT, WITHDRAW, FREEZE, CLOSE |
| LOANS | VIEW, APPLY, APPROVE, DISBURSE, WRITE_OFF |
| ACCOUNTING | VIEW, CREATE_VOUCHER, POST_VOUCHER, CLOSE_YEAR |
| CASH | OPEN, DEPOSIT, WITHDRAW, VAULT_TRANSFER, CLOSE |
| REPORTS | VIEW_BASIC, VIEW_FINANCIAL, EXPORT |
| USERS | VIEW, CREATE, EDIT, DELETE, ASSIGN_ROLES |
| SETTINGS | VIEW, EDIT |
| AUDIT | VIEW |

### Default Role Permissions

| Permission | Admin | Manager | Accountant | Cashier | Loan Officer | Collector | Auditor |
|-----------|-------|---------|-----------|---------|-------------|----------|---------|
| MEMBERS_VIEW | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| MEMBERS_CREATE | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| MEMBERS_APPROVE | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| SAVINGS_DEPOSIT | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ |
| SAVINGS_WITHDRAW | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| LOANS_APPROVE | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| LOANS_DISBURSE | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| ACCOUNTING_POST | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| USERS_CREATE | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| AUDIT_VIEW | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## Data Protection

### Encryption at Rest

| Data | Encryption | Method |
|------|-----------|--------|
| Passwords | bcrypt (cost: 12) | One-way hash |
| Fingerprint templates | AES-256-GCM | Encrypted blob |
| PAN numbers | AES-256-GCM | Encrypted field |
| Account numbers | Not encrypted (indexed) | |
| Documents (MinIO) | AES-256 (MinIO native) | Server-side encryption |
| Database backups | AES-256 | GPG encrypted |

```csharp
// Encryption service
public class AesEncryptionService : IEncryptionService
{
    private readonly byte[] _key;
    private readonly byte[] _iv;

    public string Encrypt(string plaintext)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.IV = _iv;
        aes.Mode = CipherMode.GCM;
        // ... encrypt and return base64
    }

    public string Decrypt(string ciphertext)
    {
        // ... decrypt and return plaintext
    }
}
```

### Encryption in Transit

- **TLS 1.2+** enforced on all connections
- **HSTS** (HTTP Strict Transport Security) header: `max-age=31536000; includeSubDomains`
- **Certificate**: Let's Encrypt (auto-renewed) or purchased SSL
- **No HTTP** — all HTTP requests redirected to HTTPS

---

## Input Validation & Injection Prevention

### SQL Injection

All database queries use **Entity Framework Core** with parameterized LINQ:

```csharp
// SAFE — parameterized query
var member = await _db.Members
    .Where(m => m.CitizenshipNumber == citizenshipNumber && !m.IsDeleted)
    .FirstOrDefaultAsync(ct);

// NEVER do raw string interpolation in queries
// BAD: $"SELECT * FROM members WHERE citizenship = '{citizenshipNumber}'"
```

### XSS Prevention

- Content Security Policy (CSP) header on all responses
- Input sanitization before storage
- Output encoding in generated PDFs and reports

```
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
```

### CSRF Protection

- API is stateless (JWT) — CSRF not applicable for API endpoints
- Admin web portal uses anti-forgery tokens for form submissions

---

## Rate Limiting

```csharp
// Configuration in Program.cs
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("api", limiter =>
    {
        limiter.PermitLimit = 300;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiter.QueueLimit = 10;
    });

    // Stricter limit for auth endpoints
    options.AddFixedWindowLimiter("auth", limiter =>
    {
        limiter.PermitLimit = 10;
        limiter.Window = TimeSpan.FromMinutes(15);
    });
});
```

---

## Account Security Policies

### Password Policy

```
Minimum length: 8 characters
Maximum length: 128 characters
Requirements:
  - At least 1 uppercase letter (A-Z)
  - At least 1 lowercase letter (a-z)
  - At least 1 digit (0-9)
  - At least 1 special character (!@#$%^&*)
Password history: Last 5 passwords cannot be reused
Expiry: 90 days (configurable per role)
Forced change on first login: Yes
```

### Account Lockout

```
Failed attempts before lockout: 5
Lockout duration: 15 minutes (auto-unlock)
Admin unlock: Available at any time
Failed attempts from same IP: Rate-limited (10 attempts / 30 min)
Notification: Email alert to user and admin on lockout
```

### Session Management

```
Access token TTL: 15 minutes
Refresh token TTL: 7 days
Inactivity timeout: 30 minutes (configurable)
Concurrent sessions: Max 3 per user (configurable)
Session revocation: Immediate on logout or password change
Device fingerprinting: Track and alert on new device
```

---

## API Security Headers

All API responses include:

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
Cache-Control: no-store, no-cache, must-revalidate
X-Correlation-ID: abc-123-def-456
```

---

## Security Monitoring

### Events Requiring Alert

| Event | Alert Level | Notification |
|-------|------------|-------------|
| Admin login | Info | Email to admin |
| 5+ failed logins | Warning | Email to admin + lock |
| Login from new country | Warning | Email to user |
| Permission escalation | Critical | Email + SMS to admin |
| Large transaction | Warning | Email to manager |
| Bulk data export | Warning | Email to admin |
| Database backup failure | Critical | SMS to admin |
| Certificate expiry (7 days) | Warning | Email to admin |

### Security Scan Schedule

| Scan Type | Frequency | Tool |
|-----------|----------|------|
| Dependency vulnerability | Every CI run | OWASP Dependency Check |
| SAST (code analysis) | Every PR | SonarQube |
| DAST (API scanning) | Weekly | OWASP ZAP |
| SSL certificate check | Daily | Internal check |
| Penetration testing | Annually | External vendor |

---

## Compliance Checklist

- [x] JWT RS256 authentication
- [x] Refresh token rotation
- [x] Two-Factor Authentication
- [x] RBAC with granular permissions
- [x] Password policy enforcement
- [x] Account lockout after failed attempts
- [x] AES-256 encryption for PII
- [x] bcrypt password hashing (cost 12)
- [x] TLS 1.2+ enforced
- [x] HSTS header
- [x] CSP headers
- [x] SQL injection prevention (EF Core parameterized)
- [x] Rate limiting per user and IP
- [x] Complete audit logging
- [x] Session timeout
- [x] Device registration and tracking
- [x] Automated nightly backup
- [x] Encrypted backup files
- [x] Soft-delete (no physical data deletion)
- [x] Input validation on every endpoint
