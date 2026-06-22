# SahakariMS — Audit: Login History

## Overview

The login history module tracks every authentication attempt — successful and failed — for security monitoring, anomaly detection, and compliance auditing.

---

## Database Schema

```sql
CREATE TABLE audit.login_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id),
    username        VARCHAR(100) NOT NULL,     -- Stored even if user not found
    status          VARCHAR(20) NOT NULL,       -- Success | Failed | Locked | OTP_Failed
    failure_reason  VARCHAR(200),              -- Wrong password | Account locked | etc.
    ip_address      INET NOT NULL,
    user_agent      TEXT,
    device_id       VARCHAR(200),
    device_name     VARCHAR(200),              -- "Samsung Galaxy S21"
    os              VARCHAR(100),              -- "Android 13"
    app_version     VARCHAR(20),              -- "1.0.0"
    location_city   VARCHAR(100),             -- From IP geolocation
    location_country VARCHAR(50),
    is_new_device   BOOLEAN DEFAULT FALSE,     -- True = device not seen before
    two_factor_used BOOLEAN DEFAULT FALSE,
    login_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX idx_login_history_user_date ON audit.login_history(user_id, login_at DESC);
CREATE INDEX idx_login_history_ip       ON audit.login_history(ip_address, login_at DESC);
CREATE INDEX idx_login_history_status   ON audit.login_history(status, login_at DESC);
CREATE INDEX idx_login_history_device   ON audit.login_history(device_id, login_at DESC)
    WHERE device_id IS NOT NULL;
```

---

## Login Events Recorded

| Event | Status | Description |
|-------|--------|-------------|
| Successful login | `Success` | Valid credentials, tokens issued |
| Wrong password | `Failed` | Invalid password attempt |
| User not found | `Failed` | Username doesn't exist |
| Account locked | `Locked` | Too many failed attempts |
| Account inactive | `Failed` | Suspended/inactive user |
| OTP failed | `OTP_Failed` | 2FA code wrong |
| OTP expired | `OTP_Failed` | OTP not used within 5 min |
| Token refresh | Not logged | Routine — not tracked |
| Logout | Not logged | Tracked in activity_logs |

---

## Implementation

```csharp
// Infrastructure/Audit/LoginHistoryService.cs
public class LoginHistoryService : ILoginHistoryService
{
    private readonly SahakariMSDbContext _db;
    private readonly IGeoIpService _geoIp;

    public async Task RecordLoginAsync(LoginHistoryRecord record, CancellationToken ct)
    {
        var location = await _geoIp.LookupAsync(record.IpAddress);

        var history = new LoginHistory
        {
            UserId = record.UserId,
            Username = record.Username,
            Status = record.Status,
            FailureReason = record.FailureReason,
            IpAddress = record.IpAddress,
            UserAgent = record.UserAgent,
            DeviceId = record.DeviceId,
            DeviceName = ParseDeviceName(record.UserAgent),
            Os = ParseOs(record.UserAgent),
            AppVersion = record.AppVersion,
            LocationCity = location?.City,
            LocationCountry = location?.Country,
            IsNewDevice = await IsNewDeviceAsync(record.UserId, record.DeviceId, ct),
            TwoFactorUsed = record.TwoFactorUsed
        };

        _db.LoginHistories.Add(history);
        await _db.SaveChangesAsync(ct);

        // Alert on new device
        if (history.IsNewDevice && history.Status == LoginStatus.Success)
        {
            await _notificationService.SendNewDeviceAlertAsync(record.UserId, history);
        }

        // Alert on multiple failures
        var recentFailures = await GetRecentFailureCountAsync(record.UserId, minutes: 10, ct);
        if (recentFailures >= 3)
        {
            await _notificationService.AlertSecurityTeamAsync(
                $"User {record.Username} has {recentFailures} failed logins in 10 minutes from IP {record.IpAddress}");
        }
    }
}
```

---

## Security Monitoring Queries

### Suspicious Login Patterns

```sql
-- 1. Multiple failed logins from same IP
SELECT
    ip_address,
    COUNT(*) AS failed_attempts,
    MIN(login_at) AS first_attempt,
    MAX(login_at) AS last_attempt,
    COUNT(DISTINCT username) AS distinct_usernames,
    STRING_AGG(DISTINCT username, ', ') AS attempted_usernames
FROM audit.login_history
WHERE status = 'Failed'
  AND login_at >= NOW() - INTERVAL '1 hour'
GROUP BY ip_address
HAVING COUNT(*) >= 10
ORDER BY failed_attempts DESC;

-- 2. Users logging in from multiple countries same day
SELECT
    user_id,
    u.full_name,
    STRING_AGG(DISTINCT location_country, ', ') AS countries,
    COUNT(DISTINCT location_country) AS country_count
FROM audit.login_history lh
JOIN users u ON u.id = lh.user_id
WHERE login_at::DATE = CURRENT_DATE
  AND status = 'Success'
GROUP BY user_id, u.full_name
HAVING COUNT(DISTINCT location_country) > 1;

-- 3. Logins during unusual hours (midnight to 5 AM)
SELECT
    lh.login_at,
    u.full_name,
    lh.ip_address,
    lh.location_city,
    lh.device_name
FROM audit.login_history lh
JOIN users u ON u.id = lh.user_id
WHERE EXTRACT(HOUR FROM lh.login_at AT TIME ZONE 'Asia/Kathmandu') BETWEEN 0 AND 5
  AND lh.status = 'Success'
  AND lh.login_at >= NOW() - INTERVAL '7 days'
ORDER BY lh.login_at DESC;

-- 4. New device logins this week
SELECT
    lh.login_at,
    u.full_name,
    u.email,
    lh.device_name,
    lh.ip_address,
    lh.location_city
FROM audit.login_history lh
JOIN users u ON u.id = lh.user_id
WHERE lh.is_new_device = TRUE
  AND lh.status = 'Success'
  AND lh.login_at >= NOW() - INTERVAL '7 days'
ORDER BY lh.login_at DESC;

-- 5. Current active sessions by user
SELECT
    u.full_name,
    COUNT(*) AS active_sessions,
    STRING_AGG(rt.device_id, ', ') AS devices
FROM refresh_tokens rt
JOIN users u ON u.id = rt.user_id
WHERE rt.is_revoked = FALSE
  AND rt.expires_at > NOW()
GROUP BY u.full_name
ORDER BY active_sessions DESC;
```

---

## Login History Flutter Screen

The admin login history screen shows a filterable timeline:

```
LOGIN HISTORY — Ram Shrestha (Admin)

Filter: [ All ] [ Successful ] [ Failed ] [ New Device ]

2081-04-15 09:32 AM   ✅ Success     192.168.1.45     Samsung S21 (Android 13)
2081-04-14 09:01 AM   ✅ Success     192.168.1.45     Samsung S21 (Android 13)
2081-04-13 09:15 AM   ❌ Failed      192.168.1.45     Chrome (Windows 11) — Wrong password
2081-04-13 09:14 AM   ❌ Failed      192.168.1.45     Chrome (Windows 11) — Wrong password
2081-04-12 09:05 AM   ✅ Success     192.168.1.45     Chrome (Windows 11) 🆕 New device
2081-04-10 09:22 AM   ✅ Success     192.168.1.45     Samsung S21 (Android 13)
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/users/{id}/login-history` | AUDIT_VIEW or own | Login history for a user |
| GET | `/admin/audit/login-history` | AUDIT_VIEW | All login history |
| GET | `/admin/audit/failed-logins` | AUDIT_VIEW | Failed logins report |
| GET | `/admin/audit/active-sessions` | ADMIN | Current active sessions |
| DELETE | `/admin/audit/sessions/{userId}` | ADMIN | Revoke all user sessions |
