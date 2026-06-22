# SahakariMS — Audit: Activity Log

## Overview

The activity log records every user action across all modules. It answers the question: **"Who did what, when, and from where?"**

---

## Log Entry Structure

```json
{
  "id": "uuid",
  "branchId": "uuid",
  "branchCode": "KTM",
  "userId": "uuid",
  "userFullName": "Ram Shrestha",
  "userRole": "Cashier",
  "module": "SAVINGS",
  "action": "DEPOSIT",
  "entityType": "SavingTransaction",
  "entityId": "uuid-of-transaction",
  "description": "Deposit of NPR 5,000.00 to account SAV-KTM-2081-456",
  "ipAddress": "192.168.1.45",
  "userAgent": "SahakariMS-Desktop/1.0.0 (Windows 11)",
  "requestPath": "/api/v1/savings/accounts/uuid/deposit",
  "responseStatus": 201,
  "durationMs": 145,
  "createdAt": "2081-04-15T09:32:11Z"
}
```

---

## Logged Actions by Module

### MEMBERS

| Action | Trigger |
|--------|---------|
| `MEMBER_REGISTERED` | New member registration submitted |
| `MEMBER_KYC_UPLOADED` | KYC document uploaded |
| `MEMBER_KYC_VERIFIED` | KYC marked as verified |
| `MEMBER_APPROVED` | Membership approved |
| `MEMBER_REJECTED` | Membership rejected |
| `MEMBER_EDITED` | Member profile updated |
| `MEMBER_SUSPENDED` | Member suspended |
| `MEMBER_REACTIVATED` | Member reactivated |
| `MEMBER_CLOSED` | Member account closed |
| `NOMINEE_ADDED` | Nominee added/updated |

### SAVINGS

| Action | Trigger |
|--------|---------|
| `ACCOUNT_OPENED` | New savings account opened |
| `DEPOSIT` | Deposit processed |
| `WITHDRAWAL` | Withdrawal processed |
| `ACCOUNT_FROZEN` | Account frozen |
| `ACCOUNT_UNFROZEN` | Account unfrozen |
| `ACCOUNT_CLOSED` | Account closed |
| `INTEREST_POSTED` | Interest batch posted |
| `STATEMENT_VIEWED` | Statement viewed/downloaded |

### LOANS

| Action | Trigger |
|--------|---------|
| `LOAN_APPLICATION` | Loan application submitted |
| `LOAN_APPROVED` | Loan approved |
| `LOAN_REJECTED` | Loan rejected |
| `LOAN_DISBURSED` | Loan disbursed to account |
| `EMI_PAYMENT` | EMI payment recorded |
| `LOAN_RESCHEDULED` | Loan rescheduled |
| `LOAN_WRITTEN_OFF` | Loan written off |
| `LOAN_CLOSED` | Loan fully paid and closed |
| `NPA_CLASSIFIED` | NPA status changed |
| `PENALTY_WAIVED` | Penalty waived by manager |

### ACCOUNTING

| Action | Trigger |
|--------|---------|
| `VOUCHER_CREATED` | Journal voucher created |
| `VOUCHER_POSTED` | Voucher posted to ledger |
| `VOUCHER_REVERSED` | Voucher reversed |
| `FISCAL_YEAR_CLOSED` | Fiscal year closed |
| `ACCOUNT_CREATED` | New GL account created |
| `OPENING_BALANCE_SET` | Opening balance entered |

### USERS & SECURITY

| Action | Trigger |
|--------|---------|
| `USER_CREATED` | System user created |
| `USER_DEACTIVATED` | User deactivated |
| `USER_UNLOCKED` | Account unlocked after lockout |
| `ROLE_ASSIGNED` | Role assigned to user |
| `ROLE_REMOVED` | Role removed from user |
| `PERMISSION_CHANGED` | Permission added or removed from role |
| `PASSWORD_RESET` | Password reset by admin |
| `SETTINGS_CHANGED` | System settings modified |

---

## Querying Audit Logs

### API

```
GET /admin/audit/activity-logs
?page=1
&pageSize=50
&userId=uuid
&module=LOANS
&action=LOAN_APPROVED
&fromDate=2081-04-01
&toDate=2081-04-15
&branchId=uuid
&sort=createdAt:desc
```

### Direct SQL (for DBA/Auditor)

```sql
-- User activity summary for a specific day
SELECT
    al.user_id,
    u.full_name,
    al.module,
    COUNT(*) AS action_count,
    MIN(al.created_at) AS first_action,
    MAX(al.created_at) AS last_action,
    STRING_AGG(DISTINCT al.action, ', ' ORDER BY al.action) AS actions
FROM audit.audit_logs al
JOIN users u ON u.id = al.user_id
WHERE al.created_at::DATE = '2024-04-28'  -- AD equivalent of 2081-04-15
  AND al.branch_id = 'branch-uuid'
GROUP BY al.user_id, u.full_name, al.module
ORDER BY action_count DESC;

-- Find all actions on a specific member
SELECT
    al.created_at,
    u.full_name AS performed_by,
    al.action,
    al.description,
    al.ip_address
FROM audit.audit_logs al
JOIN users u ON u.id = al.user_id
WHERE al.entity_type = 'Member'
  AND al.entity_id = 'member-uuid'
ORDER BY al.created_at DESC;

-- Large transactions (for fraud monitoring)
SELECT
    al.created_at,
    al.user_id,
    u.full_name,
    al.description,
    al.ip_address
FROM audit.audit_logs al
JOIN users u ON u.id = al.user_id
WHERE al.action IN ('DEPOSIT', 'WITHDRAWAL', 'LOAN_DISBURSED')
  AND al.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY al.created_at DESC;
```

---

## Retention and Archiving

```
Hot (< 2 years):     PostgreSQL partitioned tables (fast query)
Warm (2-5 years):    PostgreSQL older partitions (slower, less used)
Cold (5-7 years):    Compressed JSONL files in MinIO
Archive (7+ years):  Encrypted archives in cold storage
```

Automated archiving job runs monthly:

```csharp
[DisableConcurrentExecution(600)]
public class AuditLogArchiveJob
{
    public async Task ExecuteAsync()
    {
        // Find partitions older than 2 years
        var oldPartitions = await _db.GetOldAuditPartitionsAsync(yearsOld: 2);

        foreach (var partition in oldPartitions)
        {
            // Export to JSONL
            var filePath = await ExportPartitionToJsonlAsync(partition);

            // Compress
            var gzipPath = await GzipCompressAsync(filePath);

            // Upload to MinIO cold storage
            await _minioService.UploadAsync("audit-archive", gzipPath);

            // Verify upload
            if (await _minioService.ExistsAsync("audit-archive", gzipPath))
            {
                // Drop the old partition (data now in MinIO)
                await _db.DropPartitionAsync(partition);
                _logger.LogInformation("Archived partition: {Partition}", partition.Name);
            }
        }
    }
}
```
