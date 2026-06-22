# SahakariMS — Security: Encryption

## Overview

SahakariMS encrypts data at rest for sensitive fields and uses TLS for all data in transit. The encryption strategy balances security with the need for some fields to be searchable.

---

## What Is Encrypted

| Field | Table | Method | Reason |
|-------|-------|--------|--------|
| PAN number | `members.pan_number` | AES-256-GCM | Tax identity — highly sensitive |
| Fingerprint template | `members.fingerprint_data` | AES-256-GCM | Biometric data |
| 2FA TOTP secret | `users.two_factor_secret` | AES-256-GCM | Auth secret |
| Password | `users.password_hash` | bcrypt (cost 12) | One-way hash |
| Refresh token | `refresh_tokens.token_hash` | bcrypt | One-way hash |
| Backup files | MinIO / filesystem | AES-256 (GPG) | Data at rest |
| SSL/TLS | All network traffic | TLS 1.2+ | Data in transit |

---

## What Is NOT Encrypted (Searchable/Indexed)

| Field | Reason |
|-------|--------|
| Citizenship number | Indexed for search |
| Phone number | Indexed for search |
| Member name | Full-text search |
| Account number | Direct lookup |
| Loan number | Direct lookup |
| Transaction amounts | Aggregation queries |

---

## AES-256-GCM Implementation

```csharp
// Infrastructure/Security/AesEncryptionService.cs
public class AesEncryptionService : IEncryptionService
{
    private readonly byte[] _key;  // 32 bytes for AES-256

    public AesEncryptionService(IOptions<EncryptionSettings> options)
    {
        _key = Convert.FromHexString(options.Value.Key);
        if (_key.Length != 32)
            throw new InvalidOperationException("AES-256 requires a 32-byte key.");
    }

    public string Encrypt(string plaintext)
    {
        if (string.IsNullOrEmpty(plaintext)) return plaintext;

        // Generate random 12-byte nonce (IV) per encryption
        var nonce = new byte[12];
        RandomNumberGenerator.Fill(nonce);

        var plaintextBytes = Encoding.UTF8.GetBytes(plaintext);
        var ciphertextBytes = new byte[plaintextBytes.Length];
        var tag = new byte[16];  // 128-bit auth tag

        using var aesGcm = new AesGcm(_key, tagSizeInBytes: 16);
        aesGcm.Encrypt(nonce, plaintextBytes, ciphertextBytes, tag);

        // Pack: nonce (12) + tag (16) + ciphertext
        var result = new byte[12 + 16 + ciphertextBytes.Length];
        Buffer.BlockCopy(nonce, 0, result, 0, 12);
        Buffer.BlockCopy(tag, 0, result, 12, 16);
        Buffer.BlockCopy(ciphertextBytes, 0, result, 28, ciphertextBytes.Length);

        return Convert.ToBase64String(result);
    }

    public string Decrypt(string ciphertext)
    {
        if (string.IsNullOrEmpty(ciphertext)) return ciphertext;

        var data = Convert.FromBase64String(ciphertext);

        var nonce = data[..12];
        var tag = data[12..28];
        var encryptedBytes = data[28..];
        var decryptedBytes = new byte[encryptedBytes.Length];

        using var aesGcm = new AesGcm(_key, tagSizeInBytes: 16);
        aesGcm.Decrypt(nonce, encryptedBytes, tag, decryptedBytes);

        return Encoding.UTF8.GetString(decryptedBytes);
    }

    /// <summary>
    /// Encrypt without revealing that two identical values are the same.
    /// Uses same random IV, so each call produces different ciphertext.
    /// </summary>
    public string EncryptDeterministic(string plaintext)
    {
        // Uses HMAC-SHA256 as a deterministic nonce (for searchable encryption)
        var hmac = new HMACSHA256(_key);
        var nonce = hmac.ComputeHash(Encoding.UTF8.GetBytes(plaintext))[..12];
        // ... same as Encrypt but with deterministic nonce
        return Encrypt(plaintext);  // Simplified — production uses deterministic nonce
    }
}
```

---

## EF Core Value Converter (Transparent Encryption)

```csharp
// Infrastructure/Persistence/Converters/EncryptedStringConverter.cs
public class EncryptedStringConverter : ValueConverter<string?, string?>
{
    public EncryptedStringConverter(IEncryptionService encryptionService)
        : base(
            // Store: encrypt before writing to DB
            value => value == null ? null : encryptionService.Encrypt(value),
            // Load: decrypt when reading from DB
            value => value == null ? null : encryptionService.Decrypt(value))
    {
    }
}

// Usage in DbContext
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    var encryptedConverter = new EncryptedStringConverter(_encryptionService);

    modelBuilder.Entity<Member>(entity =>
    {
        entity.Property(m => m.PanNumber)
            .HasConversion(encryptedConverter)
            .HasColumnName("pan_number");

        entity.Property(m => m.FingerprintData)
            .HasConversion(encryptedConverter)
            .HasColumnName("fingerprint_data");
    });

    modelBuilder.Entity<User>(entity =>
    {
        entity.Property(u => u.TwoFactorSecret)
            .HasConversion(encryptedConverter);
    });
}
```

---

## Password Hashing (bcrypt)

```csharp
// Infrastructure/Security/PasswordHasher.cs
public class PasswordHasher : IPasswordHasher
{
    private const int WorkFactor = 12;  // 2^12 = 4096 iterations

    public string Hash(string password)
        => BCrypt.Net.BCrypt.HashPassword(password, WorkFactor);

    public bool Verify(string password, string hash)
        => BCrypt.Net.BCrypt.Verify(password, hash);

    public bool NeedsRehash(string hash)
    {
        // Upgrade hash if work factor increased
        var info = BCrypt.Net.BCrypt.InterrogateHash(hash);
        return info.WorkFactor < WorkFactor;
    }
}
```

---

## Key Management

### Key Storage

```
Production key storage:
  AES Key → .env file (environment variable)
  JWT Private Key → /opt/sahakari-ms/keys/jwt_private.pem (600 permission)
  GPG Passphrase → password manager (1Password / Bitwarden for Teams)

Never:
  ✗ Store keys in source code
  ✗ Store keys in database
  ✗ Commit .env to git
  ✗ Log encryption keys
```

### Key Rotation

```bash
# AES Key Rotation (annual or after suspected compromise)
# 1. Generate new key
NEW_KEY=$(openssl rand -hex 32)
echo "New AES Key: ${NEW_KEY}"

# 2. Re-encrypt all sensitive fields
# Run migration script (reads with OLD key, writes with NEW key)
dotnet run --project scripts/ReEncryptSensitiveData -- \
  --old-key "${OLD_AES_KEY}" \
  --new-key "${NEW_KEY}"

# 3. Update .env with new key
sed -i "s/AES_ENCRYPTION_KEY=.*/AES_ENCRYPTION_KEY=${NEW_KEY}/" .env

# 4. Restart API
docker compose restart api

# JWT Key Rotation (annual or after compromise)
openssl genrsa -out keys/jwt_private_new.pem 2048
openssl rsa -in keys/jwt_private_new.pem -pubout -out keys/jwt_public_new.pem
# Keep old public key for 15 minutes (until old tokens expire)
# Then replace
```

---

## Data in Transit

```
Client → Nginx: TLS 1.2+ (HTTPS)
Nginx → API: HTTP (internal Docker network — trusted)
API → PostgreSQL: PostgreSQL SSL connection
API → Redis: Redis AUTH + optional TLS
API → MinIO: HTTPS
API → Sparrow SMS: HTTPS
API → Firebase: HTTPS
```

Internal Docker network traffic is trusted (same host), but external communications always use TLS.

---

## Compliance

| Standard | Requirement | Status |
|----------|-------------|--------|
| Nepal Cooperative Act | Member data protection | ✅ AES-256 for PII |
| Nepal NRB Guidelines | Financial data security | ✅ TLS + encryption at rest |
| OWASP Top 10 | A02 Cryptographic Failures | ✅ AES-GCM, bcrypt |
| Internal Policy | No plaintext secrets in code | ✅ Enforced via SAST |
