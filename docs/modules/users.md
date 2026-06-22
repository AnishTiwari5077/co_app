# SahakariMS — Module: Users & Roles

## Overview

The Users module manages all system users (staff accounts) and their role assignments. Role-based access control (RBAC) determines what each user can see and do across all modules.

---

## User Types

| Type | Description | Auth Method |
|------|-------------|-------------|
| Admin | Head office super admin | Username + password + 2FA |
| Branch Manager | Branch-level manager | Username + password + 2FA |
| Accountant | Handles accounting/vouchers | Username + password |
| Cashier | Counter transactions | Username + password |
| Loan Officer | Loan processing | Username + password |
| Collector | Field collection | Mobile PIN + biometric |
| Auditor | Read-only audit access | Username + password |
| Member | Self-service portal | OTP or mPIN |

---

## User Account Rules

| Rule | Detail |
|------|--------|
| Unique username | `username` unique across system |
| Unique email | `email` unique across system |
| Password complexity | Min 8 chars, uppercase + lowercase + digit + special |
| Password expiry | Every 90 days (configurable) |
| Session limit | Max 3 concurrent sessions per user |
| Inactivity timeout | 30 minutes (configurable per branch) |
| Lockout | 5 failed attempts → 15-minute lockout |

---

## Role System

Roles are defined per branch. A user can have multiple roles:

```
Admin role = all permissions (no individual listing)

Manager role = [
  MEMBERS_VIEW, MEMBERS_CREATE, MEMBERS_APPROVE, MEMBERS_EDIT, MEMBERS_KYC_VERIFY,
  SAVINGS_VIEW, SAVINGS_DEPOSIT, SAVINGS_WITHDRAW, SAVINGS_FREEZE, SAVINGS_CLOSE,
  LOANS_VIEW, LOANS_APPROVE, LOANS_DISBURSE, LOANS_PAYMENT, LOANS_RESCHEDULE,
  ACCOUNTING_VIEW, ACCOUNTING_VOUCHER_CREATE, ACCOUNTING_VOUCHER_POST,
  REPORTS_VIEW_BASIC, REPORTS_VIEW_FINANCIAL, REPORTS_EXPORT,
  CASH_OPEN, CASH_CLOSE, CASH_VIEW_ALL,
  AUDIT_VIEW
]
```

---

## Implementation

```csharp
// Domain/Entities/User.cs
public class User : AggregateRoot
{
    public string Username { get; private set; }
    public string Email { get; private set; }
    public string PasswordHash { get; private set; }
    public string FullName { get; private set; }
    public Guid BranchId { get; private set; }
    public UserStatus Status { get; private set; }
    public int FailedLoginCount { get; private set; }
    public DateTime? LockedUntil { get; private set; }

    public IReadOnlyList<UserRole> Roles { get; private set; }

    public bool IsLocked => LockedUntil.HasValue && LockedUntil > DateTime.UtcNow;

    public void RecordFailedLogin()
    {
        FailedLoginCount++;
        if (FailedLoginCount >= 5)
        {
            LockedUntil = DateTime.UtcNow.AddMinutes(15);
            AddDomainEvent(new UserLockedOutEvent(Id, Username));
        }
    }

    public void ResetFailedLoginCount()
    {
        FailedLoginCount = 0;
        LockedUntil = null;
    }

    public void AssignRole(Guid roleId, Guid assignedBy)
    {
        if (Roles.Any(r => r.RoleId == roleId))
            throw new DomainException("Role already assigned.");

        _roles.Add(new UserRole(Id, roleId, assignedBy));
        AddDomainEvent(new RoleAssignedEvent(Id, roleId));
    }
}
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/users` | USERS_VIEW | List all users |
| POST | `/users` | USERS_CREATE | Create new user |
| GET | `/users/{id}` | USERS_VIEW | User details |
| PUT | `/users/{id}` | USERS_EDIT | Update user info |
| POST | `/users/{id}/deactivate` | USERS_DEACTIVATE | Deactivate user |
| POST | `/users/{id}/unlock` | USERS_UNLOCK | Unlock locked account |
| POST | `/users/{id}/reset-password` | USERS_RESET_PASSWORD | Admin password reset |
| POST | `/users/{id}/roles` | ROLES_MANAGE | Assign role to user |
| DELETE | `/users/{id}/roles/{roleId}` | ROLES_MANAGE | Remove role |
| GET | `/roles` | ROLES_VIEW | List all roles |
| POST | `/roles` | ROLES_MANAGE | Create custom role |
| GET | `/roles/{id}/permissions` | ROLES_VIEW | Get role's permissions |
| PUT | `/roles/{id}/permissions` | ROLES_MANAGE | Update permissions |
