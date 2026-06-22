# SahakariMS — Security: JWT & Token Management

## JWT Overview

SahakariMS uses **RS256 (RSA + SHA-256)** signed JWT tokens. This asymmetric scheme means:
- The **private key** (server-side only) signs tokens
- The **public key** can verify tokens — it can be distributed to multiple services
- Compromise of public key cannot forge tokens

---

## Token Types

| Token | Purpose | TTL | Storage |
|-------|---------|-----|---------|
| Access Token | Authenticate API requests | 15 minutes | Memory / Secure storage |
| Refresh Token | Get new access tokens | 7 days | Encrypted DB + Secure storage |
| Temp 2FA Token | Short-lived 2FA flow | 5 minutes | Redis |
| OTP Token | SMS/Email OTP verification | 5 minutes | Redis |
| Password Reset | One-time password reset | 30 minutes | Redis |

---

## Access Token Claims

```json
{
  "sub": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "name": "Ram Bahadur Shrestha",
  "email": "ram.shrestha@sahakarims.np",
  "branchId": "b1c2d3e4-f5a6-7890-bcde-fa1234567890",
  "branchCode": "KTM",
  "roles": ["Cashier"],
  "perms": [
    "MEMBERS_VIEW",
    "SAVINGS_DEPOSIT",
    "SAVINGS_WITHDRAW",
    "CASH_COUNTER"
  ],
  "iat": 1719050000,
  "exp": 1719050900,
  "jti": "unique-token-id-uuid"
}
```

---

## Token Lifecycle

```
Login
  │
  ▼
Server validates credentials
  │
  ▼
Issue Access Token (15 min) + Refresh Token (7 days)
  │
  ├──────────────────────────────────────────┐
  │                                          │
  ▼                                          ▼
Client stores:                         Server stores:
  Access Token → memory                  Refresh token HASH in DB
  Refresh Token → SecureStorage          (never store plaintext)
  │
  ▼
API request with Access Token in header
  │
  ▼ (after 15 min)
Access Token expires
  │
  ▼
Client sends Refresh Token to /auth/refresh-token
  │
  ▼
Server:
  1. Find refresh token hash in DB
  2. Verify it's not expired or revoked
  3. Issue NEW Access Token (15 min)
  4. Issue NEW Refresh Token (7 days)
  5. Revoke OLD refresh token (rotation)
  │
  ▼
Client updates stored tokens
  │
  ▼ (after 7 days of no refresh)
Refresh token expires → Force re-login
```

---

## Refresh Token Security

```csharp
public class RefreshTokenService
{
    public async Task<RefreshTokenResult> RotateRefreshTokenAsync(
        string incomingRefreshToken,
        string deviceId,
        string ipAddress,
        CancellationToken ct)
    {
        // 1. Hash the incoming token for DB lookup
        var tokenHash = BCrypt.Net.BCrypt.HashPassword(incomingRefreshToken);

        // 2. Find token in DB
        var storedToken = await _repo.FindByHashAsync(tokenHash, ct);

        if (storedToken is null)
        {
            // SECURITY: Token not found — could be reuse attack
            // Revoke ALL tokens for this user (if we can identify them)
            _logger.LogWarning("Unknown refresh token presented. Possible token theft.");
            return RefreshTokenResult.Unauthorized("Invalid refresh token.");
        }

        if (storedToken.IsRevoked)
        {
            // SECURITY: Revoked token reused — definite token theft
            // Revoke ALL tokens for this user
            await _repo.RevokeAllUserTokensAsync(storedToken.UserId, ct);
            _logger.LogCritical(
                "Revoked refresh token reused for user {UserId}. All sessions terminated.",
                storedToken.UserId);
            return RefreshTokenResult.Unauthorized("Security violation detected. All sessions terminated.");
        }

        if (storedToken.ExpiresAt < DateTime.UtcNow)
            return RefreshTokenResult.Unauthorized("Refresh token expired. Please log in again.");

        // 3. Revoke old token
        storedToken.Revoke(reason: "Rotated", revokedAt: DateTime.UtcNow);
        await _repo.UpdateAsync(storedToken, ct);

        // 4. Issue new tokens
        var user = await _userRepo.GetByIdAsync(storedToken.UserId, ct);
        var (newAccess, newRefresh) = await _jwtService.CreateTokensAsync(user, deviceId);

        return RefreshTokenResult.Success(newAccess, newRefresh);
    }
}
```

---

## Token Blacklisting (Logout)

```csharp
// On logout — revoke the specific refresh token
public async Task LogoutAsync(string refreshToken, Guid userId, CancellationToken ct)
{
    var tokenHash = BCrypt.Net.BCrypt.HashPassword(refreshToken);
    var token = await _repo.FindByHashAsync(tokenHash, ct);

    if (token?.UserId == userId)
    {
        token.Revoke(reason: "User logout");
        await _repo.UpdateAsync(token, ct);
    }

    // Log the logout event
    await _auditService.LogLogoutAsync(userId);
}

// Force logout from all devices (e.g., password change)
public async Task RevokeAllSessionsAsync(Guid userId, CancellationToken ct)
{
    await _repo.RevokeAllUserTokensAsync(userId, ct);
    _logger.LogInformation("All sessions revoked for user {UserId}", userId);
}
```

---

## Flutter Token Storage

```dart
// lib/core/auth/token_storage.dart
class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  // flutter_secure_storage uses:
  // - iOS: Keychain
  // - Android: EncryptedSharedPreferences (AES-256)
  // - Windows: Windows Credential Locker

  Future<void> saveTokens(String access, String refresh) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: access),
      _storage.write(key: _refreshTokenKey, value: refresh),
    ]);
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
```

---

## Dio Interceptor (Auto-Refresh)

```dart
// lib/core/auth/auth_interceptor.dart
class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final AuthApiService _authApi;
  bool _isRefreshing = false;
  final _pendingRequests = <({RequestOptions options, ErrorInterceptorHandler handler})>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;

      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        _redirectToLogin();
        return handler.next(err);
      }

      try {
        final newTokens = await _authApi.refreshToken(refreshToken);
        await _tokenStorage.saveTokens(newTokens.accessToken, newTokens.refreshToken);

        // Retry the failed request
        err.requestOptions.headers['Authorization'] = 'Bearer ${newTokens.accessToken}';
        final response = await Dio().fetch(err.requestOptions);
        handler.resolve(response);
      } catch (_) {
        await _tokenStorage.clearAll();
        _redirectToLogin();
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}
```

---

## Key Generation and Rotation

```bash
# Generate new RS256 key pair (rotate annually)
openssl genrsa -out new_private.pem 2048
openssl rsa -in new_private.pem -pubout -out new_public.pem

# During rotation:
# 1. Keep old public key available to verify existing tokens
# 2. Sign new tokens with new private key
# 3. Once all old tokens expire (15 min), remove old public key

# The kid (key ID) claim in JWT helps identify which key to use:
{
  "alg": "RS256",
  "kid": "key-2081-rotation-01"
}
```
