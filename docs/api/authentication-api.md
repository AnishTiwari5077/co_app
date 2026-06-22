# SahakariMS — API: Authentication API

## Base URL
`/api/v1/auth`

Authentication endpoints are **public** (no token required) unless noted.

---

## POST /auth/login
Authenticate a staff user.

**Request:**
```json
{
  "username": "cashier01@sahakarims.np",
  "password": "SecurePass@123",
  "deviceId": "device-uuid-optional"
}
```

**Response 200 — 2FA NOT enabled:**
```json
{
  "accessToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6...",
  "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2ggdG9r...",
  "expiresIn": 900,
  "tokenType": "Bearer",
  "user": {
    "id": "uuid",
    "username": "cashier01@sahakarims.np",
    "fullName": "Sita Rana",
    "branchId": "uuid",
    "branchCode": "KTM",
    "roles": ["Cashier"],
    "permissions": ["MEMBERS_VIEW", "SAVINGS_DEPOSIT", "SAVINGS_WITHDRAW", "LOANS_PAYMENT"]
  }
}
```

**Response 200 — 2FA ENABLED:**
```json
{
  "requires2FA": true,
  "twoFactorToken": "eyJhbGciOiJSUzI1NiIsInR5cCI...",
  "method": "TOTP",
  "expiresIn": 300
}
```

**Errors:**
| Code | Reason |
|------|--------|
| `401` | Invalid credentials |
| `403` | Account locked — includes `lockedUntil` timestamp |
| `403` | Account inactive |

---

## POST /auth/two-factor/verify
Complete 2FA challenge.

**Request:**
```json
{
  "twoFactorToken": "eyJhbGciOiJSUzI1NiIsInR5cCI...",
  "code": "456123",
  "method": "TOTP"
}
```

**Response 200:** Same as successful login (accessToken + refreshToken).

**Errors:**
- `401` — Invalid or expired OTP
- `401` — twoFactorToken expired (re-login required)

---

## POST /auth/refresh-token
Get new access token using refresh token.

**Request:**
```json
{
  "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2ggdG9r..."
}
```

**Response 200:**
```json
{
  "accessToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6...",
  "refreshToken": "bmV3IHJlZnJlc2ggdG9rZW4gaGVyZQ==",
  "expiresIn": 900
}
```

**Errors:**
- `401` — Refresh token invalid, expired, or revoked
- `401` — Refresh token already used (possible token theft — all sessions revoked)

---

## POST /auth/logout
**Requires:** Bearer token

Revoke current session's refresh token.

**Request:**
```json
{ "refreshToken": "current-refresh-token" }
```

**Response 204:** No content

---

## POST /auth/logout-all
**Requires:** Bearer token

Revoke all active sessions (all devices).

**Response 204:** No content

---

## POST /auth/change-password
**Requires:** Bearer token

**Request:**
```json
{
  "currentPassword": "OldPass@123",
  "newPassword": "NewPass@456"
}
```

**Response 200:**
```json
{ "message": "Password changed successfully. All other sessions have been terminated." }
```

**Side effects:** All refresh tokens for the user are revoked on password change.

---

## POST /auth/forgot-password
Initiate password reset (sends OTP to registered email/phone).

**Request:**
```json
{ "username": "cashier01@sahakarims.np" }
```

**Response 200:**
```json
{
  "message": "Reset OTP sent to registered phone ending in ***4567",
  "resetToken": "opaque-token-for-next-step",
  "expiresIn": 1800
}
```

**Security:** Always returns 200 even if user not found (prevents username enumeration).

---

## POST /auth/reset-password
Complete password reset using OTP.

**Request:**
```json
{
  "resetToken": "opaque-token-from-previous-step",
  "otp": "784321",
  "newPassword": "NewPass@789"
}
```

**Response 200:**
```json
{ "message": "Password reset successful. Please log in with your new password." }
```

---

## GET /auth/me
**Requires:** Bearer token

Get current user's profile and permissions.

**Response 200:**
```json
{
  "id": "uuid",
  "username": "cashier01@sahakarims.np",
  "fullName": "Sita Rana",
  "email": "sita.rana@sahakarims.np",
  "branchId": "uuid",
  "branchCode": "KTM",
  "branchName": "Kathmandu Main Branch",
  "roles": ["Cashier"],
  "permissions": [
    "MEMBERS_VIEW",
    "SAVINGS_DEPOSIT",
    "SAVINGS_WITHDRAW",
    "LOANS_PAYMENT",
    "CASH_OPEN",
    "CASH_CLOSE"
  ],
  "isTwoFactorEnabled": true,
  "lastLoginAt": "2081-04-15T09:32:11Z",
  "passwordExpiresAt": "2081-07-15"
}
```

---

## POST /auth/2fa/setup
**Requires:** Bearer token

Begin TOTP 2FA setup — returns QR code URI for authenticator app.

**Response 200:**
```json
{
  "secret": "BASE32SECRETKEY",
  "qrCodeUri": "otpauth://totp/SahakariMS:sita.rana?secret=BASE32SECRET&issuer=SahakariMS",
  "backupCodes": ["abc123", "def456", "ghi789"]
}
```

## POST /auth/2fa/confirm
Confirm TOTP setup by verifying a code.

**Request:**
```json
{ "code": "123456" }
```

## DELETE /auth/2fa
**Requires:** Bearer token + current password

Disable 2FA.
