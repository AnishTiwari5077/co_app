# SahakariMS — Module: Authentication

## Overview

The Authentication module handles user login, session management, token lifecycle, and Two-Factor Authentication (2FA) for all SahakariMS applications (Admin Web, Collector App, Mobile Banking).

---

## Features

| Feature | Description |
|---------|-------------|
| Username/Password Login | Standard credential-based login |
| JWT Access Token | Short-lived (15 min) RS256 signed token |
| Refresh Token Rotation | 7-day refresh tokens, rotated on every use |
| Two-Factor Authentication | TOTP via Google Authenticator or SMS OTP |
| Account Lockout | Locked after 5 failed attempts (15-min lockout) |
| Password Policy | Enforced complexity, history check |
| Mobile PIN Login | 6-digit PIN for collector and mobile apps |
| Biometric Login | Fingerprint/face unlock for mobile apps |
| Device Registration | Known device tracking; alert on new device |

---

## Authentication Flow

### Step 1: Initial Login

```
POST /api/v1/auth/login
{
  "username": "cashier01@sahakarims.np",
  "password": "MyPass@123",
  "deviceId": "device-uuid-abc"
}

Response (no 2FA):
{
  "accessToken": "eyJ...",
  "refreshToken": "dGhp...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "requiresTwoFactor": false,
  "user": { ... }
}

Response (2FA required):
{
  "requiresTwoFactor": true,
  "twoFactorToken": "temp-2fa-token",
  "twoFactorMethods": ["TOTP", "SMS"]
}
```

### Step 2: 2FA Verification (if required)

```
POST /api/v1/auth/verify-2fa
{
  "twoFactorToken": "temp-2fa-token",
  "code": "123456",
  "method": "TOTP"
}

Response:
{
  "accessToken": "eyJ...",
  "refreshToken": "dGhp..."
}
```

### Step 3: Token Refresh

```
POST /api/v1/auth/refresh-token
{
  "refreshToken": "dGhp..."
}

Response:
{
  "accessToken": "eyJ...",   // New access token
  "refreshToken": "bmV3..."  // New refresh token (old one invalidated)
}
```

---

## JWT Token Structure

```
Header: { "alg": "RS256", "typ": "JWT" }

Payload: {
  "sub": "user-uuid",
  "name": "Ram Bahadur Shrestha",
  "email": "ram@sahakarims.np",
  "branchId": "branch-uuid",
  "branchCode": "KTM",
  "roles": ["Cashier"],
  "perms": ["SAVINGS_DEPOSIT", "SAVINGS_WITHDRAW", "CASH_COUNTER"],
  "iat": 1719000000,
  "exp": 1719000900,    // 15 minutes from iat
  "jti": "unique-token-id"
}

Signature: RS256(base64(header) + "." + base64(payload), privateKey)
```

---

## Implementation

### Handler

```csharp
// Application/Auth/Commands/LoginCommandHandler.cs
public class LoginCommandHandler : IRequestHandler<LoginCommand, Result<LoginResponse>>
{
    private readonly IUserRepository _userRepo;
    private readonly ITokenService _tokenService;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IAuthAuditService _auditService;
    private readonly ILogger<LoginCommandHandler> _logger;

    public async Task<Result<LoginResponse>> Handle(
        LoginCommand command, CancellationToken ct)
    {
        // 1. Find user
        var user = await _userRepo.GetByUsernameAsync(command.Username, ct);
        if (user is null)
        {
            await _auditService.LogFailedLoginAsync(command.Username, "User not found", command.IpAddress);
            return Result<LoginResponse>.Failure("Invalid credentials.");
        }

        // 2. Check lockout
        if (user.IsLocked)
        {
            return Result<LoginResponse>.Failure(
                $"Account locked. Try again after {user.LockedUntil:HH:mm}.");
        }

        // 3. Verify password
        if (!_passwordHasher.Verify(command.Password, user.PasswordHash))
        {
            await user.RecordFailedLogin();
            await _userRepo.UpdateAsync(user, ct);
            await _auditService.LogFailedLoginAsync(command.Username, "Wrong password", command.IpAddress);

            return Result<LoginResponse>.Failure(
                $"Invalid credentials. {5 - user.FailedLoginCount} attempts remaining.");
        }

        // 4. Reset failed count
        user.ResetFailedLoginCount();

        // 5. Check if 2FA is required
        if (user.IsTwoFactorEnabled)
        {
            var tempToken = await _tokenService.CreateTempTwoFactorTokenAsync(user.Id);
            return Result<LoginResponse>.Success(new LoginResponse
            {
                RequiresTwoFactor = true,
                TwoFactorToken = tempToken
            });
        }

        // 6. Issue tokens
        var (accessToken, refreshToken) = await _tokenService.CreateTokensAsync(user, command.DeviceId);

        await _auditService.LogSuccessfulLoginAsync(user.Id, command.IpAddress, command.DeviceId);

        return Result<LoginResponse>.Success(new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            ExpiresIn = 900,
            User = UserDto.FromUser(user)
        });
    }
}
```

### Token Service

```csharp
public class JwtTokenService : ITokenService
{
    private readonly RsaSecurityKey _privateKey;
    private readonly RsaSecurityKey _publicKey;
    private readonly IRefreshTokenRepository _refreshTokenRepo;

    public async Task<(string access, string refresh)> CreateTokensAsync(
        User user, string? deviceId)
    {
        // Build claims
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Name, user.FullName),
            new(JwtRegisteredClaimNames.Email, user.Email),
            new("branchId", user.BranchId.ToString()),
            new("jti", Guid.NewGuid().ToString()),
        };

        foreach (var role in user.Roles)
            claims.Add(new Claim(ClaimTypes.Role, role.RoleCode));

        foreach (var perm in user.Permissions)
            claims.Add(new Claim("perms", perm.PermissionCode));

        // Access token (15 minutes)
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddMinutes(15),
            SigningCredentials = new SigningCredentials(_privateKey, SecurityAlgorithms.RsaSha256)
        };
        var handler = new JwtSecurityTokenHandler();
        var accessToken = handler.WriteToken(handler.CreateToken(tokenDescriptor));

        // Refresh token (7 days)
        var refreshToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        var refreshTokenHash = BCrypt.Net.BCrypt.HashPassword(refreshToken);

        await _refreshTokenRepo.CreateAsync(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = refreshTokenHash,
            DeviceId = deviceId,
            ExpiresAt = DateTime.UtcNow.AddDays(7)
        });

        return (accessToken, refreshToken);
    }
}
```

---

## Security Policies

| Policy | Value |
|--------|-------|
| Access token TTL | 15 minutes |
| Refresh token TTL | 7 days |
| Lockout after | 5 failed attempts |
| Lockout duration | 15 minutes |
| OTP TTL | 5 minutes |
| OTP max attempts | 3 |
| Password min length | 8 characters |
| Password history | Last 5 |
| Session inactivity timeout | 30 minutes |
| Max concurrent sessions | 3 per user |

---

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/login` | None | Login with credentials |
| POST | `/auth/verify-2fa` | Temp token | Verify 2FA code |
| POST | `/auth/refresh-token` | Refresh token | Get new access token |
| POST | `/auth/logout` | Bearer | Invalidate refresh token |
| POST | `/auth/send-otp` | None | Send SMS OTP |
| POST | `/auth/verify-otp` | None | Verify SMS OTP |
| POST | `/auth/change-password` | Bearer | Change own password |
| POST | `/auth/forgot-password` | None | Send password reset link |
| POST | `/auth/reset-password` | Reset token | Reset with new password |
| POST | `/auth/setup-2fa` | Bearer | Get TOTP QR code |
| POST | `/auth/enable-2fa` | Bearer | Enable 2FA (verify code) |
| POST | `/auth/disable-2fa` | Bearer | Disable 2FA |
