# SahakariMS — Audit Specification

## Overview

SahakariMS maintains a comprehensive, immutable audit trail for every action in the system. The audit system ensures accountability, enables forensic analysis, and satisfies Nepal Department of Cooperatives compliance requirements.

---

## Audit Principles

| Principle | Description |
|-----------|-------------|
| **Immutability** | Audit records can never be edited or deleted |
| **Completeness** | Every financial transaction and sensitive action is audited |
| **Non-repudiation** | Every record has who, what, when, where |
| **Retention** | Audit logs retained for minimum 7 years |
| **Performance** | Audit inserts are async and non-blocking |
| **Partitioning** | Logs partitioned by month for query performance |

---

## Audit Tables

### audit.audit_logs

General activity audit — all user actions.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Unique log ID |
| branch_id | UUID | Branch where action occurred |
| user_id | UUID | User who performed the action |
| module | VARCHAR(50) | System module (MEMBERS, LOANS, etc.) |
| action | VARCHAR(100) | Specific action (CREATE, APPROVE, DELETE) |
| entity_type | VARCHAR(50) | Entity affected (Member, Loan, etc.) |
| entity_id | UUID | ID of affected record |
| description | TEXT | Human-readable description |
| ip_address | VARCHAR(45) | Client IP address |
| user_agent | TEXT | Browser / app user agent |
| request_path | TEXT | API endpoint called |
| response_status | INTEGER | HTTP response code |
| duration_ms | INTEGER | Request duration in milliseconds |
| created_at | TIMESTAMPTZ | When the action occurred |

### audit.transaction_audit

Field-level change tracking for financial records.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Unique audit ID |
| table_name | VARCHAR(100) | Database table affected |
| operation | VARCHAR(10) | INSERT, UPDATE, DELETE |
| record_id | UUID | Primary key of affected row |
| old_data | JSONB | Previous state of the record |
| new_data | JSONB | New state of the record |
| changed_fields | TEXT[] | Array of changed column names |
| changed_by | UUID | User who made the change |
| changed_at | TIMESTAMPTZ | Timestamp of change |

### audit.login_history

Login and logout events.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Unique event ID |
| user_id | UUID | User attempting login |
| login_at | TIMESTAMPTZ | Login timestamp |
| logout_at | TIMESTAMPTZ | Logout timestamp (NULL if session active) |
| ip_address | VARCHAR(45) | Login IP address |
| device_type | VARCHAR(30) | Mobile, Desktop, Tablet |
| device_info | TEXT | Detailed device information |
| browser | VARCHAR(100) | Browser name and version |
| os | VARCHAR(100) | Operating system |
| success | BOOLEAN | Whether login succeeded |
| failure_reason | VARCHAR(100) | Reason if login failed |
| session_duration | INTEGER | Session duration in seconds |

---

## Audited Events by Module

### Authentication

| Event | Audit Level | Data Captured |
|-------|------------|---------------|
| Successful login | INFO | User, IP, device, timestamp |
| Failed login | WARNING | User (if found), IP, reason |
| Account locked | WARNING | User, IP, failed attempt count |
| Password changed | INFO | User, IP, timestamp |
| 2FA enabled/disabled | INFO | User, changed by |
| OTP requested | INFO | Phone number, purpose |
| OTP verified | INFO | Phone number, success/failure |
| Session expired | INFO | User, session duration |
| Logout | INFO | User, session duration |

### Member Management

| Event | Audit Level | Data Captured |
|-------|------------|---------------|
| Member registered | INFO | Member data snapshot |
| KYC uploaded | INFO | Document type, file name |
| KYC verified | INFO | Verified by, timestamp |
| Membership approved | INFO | Approved by, timestamp |
| Member profile edited | INFO | Changed fields, old → new values |
| Member suspended | WARNING | Reason, suspended by |
| Member closed | INFO | Reason, final balances |
| Member reactivated | INFO | Reactivated by |

### Financial Transactions

| Event | Audit Level | Data Captured |
|-------|------------|---------------|
| Savings deposit | INFO | Account, amount, balance before/after |
| Savings withdrawal | INFO | Account, amount, balance before/after |
| FD created | INFO | FD number, amount, tenure, rate |
| FD premature closure | WARNING | Reason, penalty amount |
| Loan application | INFO | Loan type, amount, member |
| Loan approval | INFO | Approved by, approved amount |
| Loan rejection | INFO | Rejected by, reason |
| Loan disbursement | INFO | Disbursed by, amount |
| EMI payment | INFO | Amount, principal/interest split |
| Loan write-off | WARNING | Approved by, amount written off |
| Interest posting | INFO | Account count, total interest posted |
| Share purchase | INFO | Quantity, amount |
| Share refund | INFO | Quantity, amount |
| Dividend posting | INFO | Rate, total amount |

### Accounting

| Event | Audit Level | Data Captured |
|-------|------------|---------------|
| Voucher created | INFO | Voucher number, type, amount |
| Voucher posted | INFO | Posted by, date |
| Voucher reversed | WARNING | Reversed by, reason |
| Fiscal year closed | CRITICAL | Closed by, closing balances |
| Chart of account modified | WARNING | Old → new values |

### User & Role Management

| Event | Audit Level | Data Captured |
|-------|------------|---------------|
| User created | INFO | User details, created by |
| User deactivated | WARNING | Deactivated by, reason |
| Role assigned | WARNING | User, role, assigned by |
| Role removed | WARNING | User, role, removed by |
| Permission changed | CRITICAL | Old → new permission set |
| User unlocked | INFO | Unlocked by |

### System & Configuration

| Event | Audit Level | Data Captured |
|-------|------------|---------------|
| Setting changed | WARNING | Key, old value, new value |
| Backup completed | INFO | Size, location, duration |
| Backup failed | CRITICAL | Error message |
| Server started | INFO | Version, configuration |
| Database migration | INFO | Migration name, success/failure |

---

## Audit Log Implementation

### ASP.NET Core Audit Filter

```csharp
public class AuditActionFilter : IAsyncActionFilter
{
    private readonly IAuditService _auditService;

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var executedContext = await next();

        // Only audit mutating operations
        if (context.HttpContext.Request.Method is "POST" or "PUT" or "PATCH" or "DELETE")
        {
            var user = context.HttpContext.User;
            var module = ExtractModule(context.ActionDescriptor);
            var action = ExtractAction(context.HttpContext.Request.Method);

            await _auditService.LogAsync(new AuditEntry
            {
                UserId = user.GetUserId(),
                BranchId = user.GetBranchId(),
                Module = module,
                Action = action,
                EntityId = ExtractEntityId(context),
                IpAddress = context.HttpContext.Connection.RemoteIpAddress?.ToString(),
                UserAgent = context.HttpContext.Request.Headers.UserAgent,
                RequestPath = context.HttpContext.Request.Path,
                ResponseStatus = executedContext.HttpContext.Response.StatusCode,
                Description = BuildDescription(context, executedContext)
            });
        }
    }
}
```

### Transaction Audit Trigger (PostgreSQL)

```sql
CREATE OR REPLACE FUNCTION audit_financial_changes()
RETURNS TRIGGER AS $$
DECLARE
    changed_fields TEXT[] := '{}';
    col TEXT;
BEGIN
    -- Detect changed fields
    FOR col IN
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = TG_TABLE_NAME
    LOOP
        IF (TG_OP = 'UPDATE' AND
            row_to_json(OLD)->>(col) IS DISTINCT FROM row_to_json(NEW)->>(col)) THEN
            changed_fields := array_append(changed_fields, col);
        END IF;
    END LOOP;

    INSERT INTO audit.transaction_audit (
        table_name, operation, record_id,
        old_data, new_data, changed_fields,
        changed_by, changed_at
    ) VALUES (
        TG_TABLE_NAME,
        TG_OP,
        COALESCE(NEW.id, OLD.id),
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        changed_fields,
        COALESCE(NEW.updated_by, OLD.updated_by, OLD.created_by),
        NOW()
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply to all financial tables
CREATE TRIGGER audit_saving_transactions
    AFTER INSERT OR UPDATE OR DELETE ON saving_transactions
    FOR EACH ROW EXECUTE FUNCTION audit_financial_changes();

CREATE TRIGGER audit_loan_payments
    AFTER INSERT OR UPDATE OR DELETE ON loan_payments
    FOR EACH ROW EXECUTE FUNCTION audit_financial_changes();

CREATE TRIGGER audit_vouchers
    AFTER INSERT OR UPDATE OR DELETE ON accounting.vouchers
    FOR EACH ROW EXECUTE FUNCTION audit_financial_changes();
```

---

## Audit Log Retention Policy

| Log Type | Retention | Storage |
|----------|----------|---------|
| Financial transaction audit | 10 years | PostgreSQL (partitioned) |
| Login history | 3 years | PostgreSQL (partitioned) |
| General activity audit | 7 years | PostgreSQL (partitioned) |
| Archived logs (> 2 years) | 10 years | Compressed to MinIO |

---

## Audit Reports

### Daily Audit Summary

- Total transactions by type
- Total amount processed
- Users who logged in
- Failed login attempts
- Any suspicious activity (large transactions, unusual hours)

### User Activity Report

- Login/logout times
- Transactions processed
- Modules accessed
- Configuration changes made

### Financial Audit Report

- All financial transactions with before/after balances
- Vouchers created and posted
- Interest postings
- Reversals and adjustments

### Compliance Report

- COPOMIS data submissions
- Regulatory report generations
- Member KYC completions
- NPA classification changes

---

## Security Events — Immediate Alerts

These events trigger immediate email/SMS alert to the Administrator:

| Event | Trigger Condition |
|-------|-----------------|
| Bulk data export | Any report exported with > 1000 records |
| Large transaction | Single transaction > NPR 500,000 |
| Late-night activity | Any login between 11pm – 5am |
| Multiple failed logins | 5+ failed logins from same IP in 10 min |
| Permission escalation | Any role or permission change |
| Audit log access | Any user accessing audit logs |
| Fiscal year close | Fiscal year closing operation |
| Database backup failure | Backup job fails |
