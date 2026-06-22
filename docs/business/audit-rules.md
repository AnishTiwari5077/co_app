# SahakariMS — Business: Audit Rules

## Overview

Audit rules govern how SahakariMS tracks, stores, and protects its audit trail. These rules ensure regulatory compliance, financial accountability, and security forensics capability.

---

## Core Audit Principles

| Principle | Rule |
|-----------|------|
| **Completeness** | Every user action and financial event is recorded |
| **Integrity** | Audit records cannot be modified or deleted |
| **Availability** | Audit logs accessible to authorized users within seconds |
| **Non-repudiation** | Actions are tied to specific users with timestamps |
| **Retention** | Records retained as per regulatory requirements |

---

## What Must Be Audited

### ALWAYS audit (no exceptions):
- All financial transactions (deposit, withdrawal, EMI, disbursement)
- All user login events (success and failure)
- All member status changes (approval, suspension, closure)
- All loan status changes (approval, rejection, disbursement)
- All voucher operations (create, post, reverse)
- All user management actions (create, deactivate, role changes)
- All settings changes
- All bulk operations (interest posting, dividend posting)
- All COPOMIS exports and report downloads

### Audit with context (include before/after values):
- Member profile edits
- Loan reschedule
- Interest rate changes on loan products
- Account freezing/unfreezing
- Guarantor changes on existing loans

---

## Audit Capture Implementation

```csharp
// Application/Behaviours/AuditBehaviour.cs
// MediatR pipeline behaviour — auto-audits every command

public class AuditBehaviour<TRequest, TResponse>
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IAuditableCommand
{
    private readonly IAuditService _auditService;
    private readonly ICurrentUserService _currentUser;

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken ct)
    {
        TResponse response;
        Exception? exception = null;

        try
        {
            response = await next();
        }
        catch (Exception ex)
        {
            exception = ex;
            throw;
        }
        finally
        {
            // Log the action regardless of success/failure
            var auditEntry = new AuditLog
            {
                UserId = _currentUser.UserId,
                BranchId = _currentUser.BranchId,
                Module = request.Module,
                Action = request.AuditAction,
                EntityType = request.EntityType,
                EntityId = request.EntityId,
                Description = request.AuditDescription,
                IpAddress = _currentUser.IpAddress,
                WasSuccessful = exception is null,
                FailureReason = exception?.Message,
                DurationMs = _stopwatch.ElapsedMilliseconds
            };

            // Fire-and-forget audit (don't block the response)
            _ = _auditService.RecordAsync(auditEntry, CancellationToken.None);
        }

        return response;
    }
}
```

---

## Audit Retention Schedule

| Data Type | Retention | Storage | Access |
|-----------|-----------|---------|--------|
| Financial transactions | 10 years | PostgreSQL → MinIO archive | Always |
| Login history | 5 years | PostgreSQL → MinIO archive | Auditor |
| Activity logs | 7 years | PostgreSQL → MinIO archive | Auditor |
| Error logs | 1 year | Loki / file | Ops team |
| Performance metrics | 1 year | Prometheus / Grafana | Ops team |
| COPOMIS exports | 7 years | MinIO | Auditor |

---

## Tamper Evidence

The audit system detects tampering via:

1. **Row count verification** — Nightly count of audit entries vs expected
2. **Hash chaining** — Each audit entry includes hash of previous entry
3. **Database-level protection** — `REVOKE DELETE ON audit.audit_logs FROM app_user`
4. **Monitoring alert** — Prometheus alert if audit log insert rate drops unexpectedly

```sql
-- Prevent deletion from audit tables (enforced at DB user level)
REVOKE DELETE ON audit.audit_logs FROM sahakarims_app;
REVOKE UPDATE ON audit.audit_logs FROM sahakarims_app;
REVOKE TRUNCATE ON audit.audit_logs FROM sahakarims_app;

-- Only the audit_writer role can INSERT
GRANT INSERT ON audit.audit_logs TO sahakarims_audit_writer;
GRANT SELECT ON audit.audit_logs TO sahakarims_app;
```

---

## Audit Report Access

```
Who can view audit logs:

  Admin (Head Office):    Full access to all branches
  Branch Manager:         Own branch's activity logs and financial transactions
  Internal Auditor:       Read-only access to all logs (assigned per engagement)
  External Auditor:       Temporary account with 30-day access (time-limited)
  Cashier/Loan Officer:   Cannot view audit logs

All audit log access is itself audited.
```

---

## Compliance Checklist

| Requirement | Rule | Implementation |
|-------------|------|---------------|
| Nepal Cooperative Act §45 | All transactions recorded | Automatic transaction audit |
| Nepal NRB AML §12 | Large transaction reporting | Auto-flag > NPR 10L |
| COPOMIS Reporting | Quarterly submission | Export API with XML generation |
| DoC Audit | Annual auditor access | Time-limited auditor role |
| Data Privacy Act | PII access logging | All member data access audited |
| IT Policy | System admin actions | All user management audited |
