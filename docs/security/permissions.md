# SahakariMS — Security: Permissions Reference

## Permission Structure

All permissions follow the format: `{MODULE}_{ACTION}`

Permissions are stored in the `permissions` table, assigned to roles via `role_permissions`, and included as `perms` claims in JWT tokens for server-side enforcement.

---

## Complete Permission List

### Members Module

| Code | Action | Description |
|------|--------|-------------|
| `MEMBERS_VIEW` | VIEW | View member profiles and lists |
| `MEMBERS_CREATE` | CREATE | Register new members |
| `MEMBERS_EDIT` | EDIT | Edit member personal information |
| `MEMBERS_APPROVE` | APPROVE | Approve pending memberships |
| `MEMBERS_KYC_VERIFY` | VERIFY | Mark KYC as verified |
| `MEMBERS_SUSPEND` | SUSPEND | Suspend active members |
| `MEMBERS_REACTIVATE` | REACTIVATE | Reactivate suspended members |
| `MEMBERS_CLOSE` | CLOSE | Close member accounts |
| `MEMBERS_EXPORT` | EXPORT | Export member data |

### Savings Module

| Code | Action | Description |
|------|--------|-------------|
| `SAVINGS_VIEW` | VIEW | View savings accounts and balances |
| `SAVINGS_OPEN_ACCOUNT` | CREATE | Open new savings accounts |
| `SAVINGS_DEPOSIT` | DEPOSIT | Process deposits |
| `SAVINGS_WITHDRAW` | WITHDRAW | Process withdrawals |
| `SAVINGS_FREEZE` | FREEZE | Freeze/unfreeze accounts |
| `SAVINGS_INTEREST_POST` | POST | Post interest to accounts |
| `SAVINGS_CLOSE` | CLOSE | Close savings accounts |
| `SAVINGS_STATEMENT` | VIEW | Download statements |

### Fixed Deposits

| Code | Action | Description |
|------|--------|-------------|
| `FD_VIEW` | VIEW | View FD accounts |
| `FD_CREATE` | CREATE | Create new FDs |
| `FD_CLOSE` | CLOSE | Close/mature FDs |
| `FD_PREMATURE_CLOSE` | CLOSE | Premature closure with penalty |

### Loans Module

| Code | Action | Description |
|------|--------|-------------|
| `LOANS_VIEW` | VIEW | View loan details and schedules |
| `LOANS_APPLY` | CREATE | Submit loan applications |
| `LOANS_APPROVE` | APPROVE | Approve/reject loan applications |
| `LOANS_DISBURSE` | DISBURSE | Disburse approved loans |
| `LOANS_PAYMENT` | PAYMENT | Record EMI payments |
| `LOANS_RESCHEDULE` | EDIT | Reschedule loan terms |
| `LOANS_WRITE_OFF` | WRITE_OFF | Write off NPA loans |
| `LOANS_WAIVE_PENALTY` | EDIT | Waive loan penalty |

### Shares Module

| Code | Action | Description |
|------|--------|-------------|
| `SHARES_VIEW` | VIEW | View share accounts |
| `SHARES_PURCHASE` | CREATE | Process share purchases |
| `SHARES_REFUND` | REFUND | Process share refunds |
| `SHARES_TRANSFER` | TRANSFER | Transfer shares between members |
| `SHARES_DIVIDEND` | POST | Post dividend to members |
| `SHARES_CERTIFICATE` | PRINT | Issue share certificates |

### Accounting Module

| Code | Action | Description |
|------|--------|-------------|
| `ACCOUNTING_VIEW` | VIEW | View chart of accounts, ledger |
| `ACCOUNTING_VOUCHER_CREATE` | CREATE | Create journal vouchers |
| `ACCOUNTING_VOUCHER_POST` | POST | Post/approve vouchers |
| `ACCOUNTING_VOUCHER_REVERSE` | REVERSE | Reverse posted vouchers |
| `ACCOUNTING_COA_EDIT` | EDIT | Modify chart of accounts |
| `ACCOUNTING_YEAR_CLOSE` | CLOSE | Close fiscal year |
| `ACCOUNTING_OPENING_BALANCE` | EDIT | Enter opening balances |

### Cash Counter

| Code | Action | Description |
|------|--------|-------------|
| `CASH_OPEN` | CREATE | Open cashier session |
| `CASH_CLOSE` | CLOSE | Close cashier session |
| `CASH_VAULT_TRANSFER` | TRANSFER | Transfer to/from vault |
| `CASH_VIEW_ALL` | VIEW | View all cashier sessions |

### Reports Module

| Code | Action | Description |
|------|--------|-------------|
| `REPORTS_VIEW_BASIC` | VIEW | View daily and member reports |
| `REPORTS_VIEW_FINANCIAL` | VIEW | View financial statements |
| `REPORTS_EXPORT` | EXPORT | Export any report |
| `REPORTS_COPOMIS` | EXPORT | Export COPOMIS data |
| `REPORTS_AUDIT` | VIEW | View audit reports |

### Users & Roles

| Code | Action | Description |
|------|--------|-------------|
| `USERS_VIEW` | VIEW | View user list |
| `USERS_CREATE` | CREATE | Create new system users |
| `USERS_EDIT` | EDIT | Edit user information |
| `USERS_DEACTIVATE` | DEACTIVATE | Deactivate users |
| `USERS_RESET_PASSWORD` | RESET | Reset user passwords |
| `USERS_UNLOCK` | UNLOCK | Unlock locked accounts |
| `ROLES_VIEW` | VIEW | View roles and permissions |
| `ROLES_MANAGE` | MANAGE | Create/edit roles and permissions |

### Settings

| Code | Action | Description |
|------|--------|-------------|
| `SETTINGS_VIEW` | VIEW | View system settings |
| `SETTINGS_EDIT` | EDIT | Modify system settings |
| `BRANCHES_MANAGE` | MANAGE | Create/edit branches |
| `LOAN_PRODUCTS_MANAGE` | MANAGE | Configure loan products |
| `SAVING_SCHEMES_MANAGE` | MANAGE | Configure saving schemes |

### Audit

| Code | Action | Description |
|------|--------|-------------|
| `AUDIT_VIEW` | VIEW | View audit logs |
| `AUDIT_EXPORT` | EXPORT | Export audit reports |

---

## Role ↔ Permission Matrix

| Permission | Admin | Manager | Accountant | Cashier | Loan Officer | Collector | Auditor | Member |
|-----------|:-----:|:-------:|:----------:|:-------:|:------------:|:---------:|:-------:|:------:|
| MEMBERS_VIEW | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| MEMBERS_CREATE | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| MEMBERS_APPROVE | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| SAVINGS_DEPOSIT | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| SAVINGS_WITHDRAW | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| SAVINGS_FREEZE | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| SAVINGS_INTEREST_POST | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| LOANS_APPROVE | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| LOANS_DISBURSE | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| LOANS_PAYMENT | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| LOANS_WRITE_OFF | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| ACCOUNTING_VOUCHER_POST | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| ACCOUNTING_YEAR_CLOSE | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| REPORTS_VIEW_FINANCIAL | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| USERS_CREATE | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| ROLES_MANAGE | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| AUDIT_VIEW | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| SETTINGS_EDIT | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## Permission Enforcement

### Backend (ASP.NET Core)

```csharp
// Custom RequirePermission attribute
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public class RequirePermissionAttribute : Attribute, IAuthorizationRequirement
{
    public string[] Permissions { get; }
    public RequirePermissionAttribute(params string[] permissions)
        => Permissions = permissions;
}

// Usage on controller actions
[HttpPost]
[RequirePermission("LOANS_APPROVE")]
public async Task<IActionResult> ApproveLoan([FromRoute] Guid id, ...)

// Multi-permission (any one sufficient)
[RequirePermission("SAVINGS_DEPOSIT", "LOANS_PAYMENT")]
public async Task<IActionResult> ProcessCashReceived(...)

// Permission handler
public class PermissionHandler : AuthorizationHandler<RequirePermissionAttribute>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        RequirePermissionAttribute requirement)
    {
        var userPerms = context.User.Claims
            .Where(c => c.Type == "perms")
            .Select(c => c.Value)
            .ToHashSet();

        if (requirement.Permissions.Any(p => userPerms.Contains(p)))
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}
```

### Flutter (Client-side guard — visual only)

```dart
// lib/core/auth/permission_guard.dart
// NOTE: Client-side is UI-only. Server enforces all permissions.

class PermissionGuard extends ConsumerWidget {
  const PermissionGuard({
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String permission;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(currentUserPermissionsProvider);
    return permissions.contains(permission) ? child : fallback;
  }
}

// Usage
PermissionGuard(
  permission: 'LOANS_APPROVE',
  child: ElevatedButton(
    onPressed: _approveLoan,
    child: const Text('Approve Loan'),
  ),
)
```
