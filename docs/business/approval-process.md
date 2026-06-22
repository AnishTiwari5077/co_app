# SahakariMS — Business: Approval Process

## Overview

SahakariMS implements a multi-tier approval workflow for high-value or sensitive operations. Approvals are enforced at the domain layer and cannot be bypassed by the UI.

---

## Approval Tier Structure

| Tier | Approver | Authority |
|------|---------|-----------|
| Self-Approval | Cashier/Officer | Routine transactions within limit |
| Level 1 | Senior Officer | Transactions above Cashier limit |
| Level 2 | Branch Manager | Loans, large withdrawals, member status changes |
| Level 3 | Head Office Admin | Write-offs, policy exceptions, branch settings |

---

## Member Approval Workflow

```
Member Submits Registration (Officer)
          │
          ▼
KYC Document Upload (Officer or Member via portal)
          │
          ▼
KYC Review (Branch Manager)
  - Verify citizenship document
  - Verify photo matches
  - Check for duplicates
          │
    ┌─────┴─────┐
  Reject      Approve
    │              │
    ▼              ▼
Notify Member   Member becomes Active
(with reason)   Share account opened
                SMS sent to member
```

---

## Loan Approval Workflow

```
Loan Application Submitted
          │
          ▼
[Automatic Eligibility Check]
  - Active member? ✓
  - KYC verified? ✓
  - No existing NPA? ✓
  - Within product limits? ✓
          │
          ▼
Loan Officer Review
  - Check income source
  - Verify guarantors
  - Assess collateral
  - Check credit history (CCIS)
          │
    ┌─────┴─────┐
  Reject      Recommend
    │              │
    ▼              ▼
Notify          Branch Manager Approval
Member          - Final decision
(with reason)   - Can modify terms
                      │
                ┌─────┴─────┐
              Reject      Approve
                │              │
                ▼              ▼
            Notify Member  Notify Cashier
            (with reason)  to Disburse

For loans > NPR 50 lakh:
  Head Office Counter-Sign also required
```

---

## Large Withdrawal Approval

```
Member requests withdrawal > NPR 1,00,000 (configurable)
          │
          ▼
Cashier initiates request
          │
          ▼
Branch Manager receives alert
  - Reviews member balance
  - Confirms no freeze order
  - Approves or rejects
          │
    ┌─────┴─────┐
  Reject      Approve (+ reason)
    │              │
    ▼              ▼
Cashier notified   Cashier can now
                   process withdrawal

Timeout: If not approved in 30 min → Auto-rejected
```

---

## Implementation: Approval Entity

```csharp
// Domain/Entities/Approval.cs
public class Approval : Entity
{
    public Guid ReferenceId { get; private set; }    // LoanId, MemberId, etc.
    public string ReferenceType { get; private set; } // "Loan" | "Member" | "Withdrawal"
    public ApprovalLevel Level { get; private set; }
    public ApprovalStatus Status { get; private set; }
    public Guid RequestedBy { get; private set; }
    public Guid? ReviewedBy { get; private set; }
    public string? Remarks { get; private set; }
    public DateTime? ReviewedAt { get; private set; }
    public DateTime ExpiresAt { get; private set; }

    public static Approval Create(
        Guid referenceId,
        string referenceType,
        ApprovalLevel level,
        Guid requestedBy,
        TimeSpan? expiryDuration = null)
    {
        return new Approval
        {
            ReferenceId = referenceId,
            ReferenceType = referenceType,
            Level = level,
            Status = ApprovalStatus.Pending,
            RequestedBy = requestedBy,
            ExpiresAt = DateTime.UtcNow.Add(expiryDuration ?? TimeSpan.FromHours(24))
        };
    }

    public void Approve(Guid reviewerId, string remarks)
    {
        if (Status != ApprovalStatus.Pending)
            throw new DomainException("Cannot approve a non-pending request.");

        if (DateTime.UtcNow > ExpiresAt)
            throw new DomainException("Approval request has expired.");

        Status = ApprovalStatus.Approved;
        ReviewedBy = reviewerId;
        Remarks = remarks;
        ReviewedAt = DateTime.UtcNow;

        AddDomainEvent(new ApprovalGrantedEvent(ReferenceId, ReferenceType, reviewerId));
    }

    public void Reject(Guid reviewerId, string reason)
    {
        if (Status != ApprovalStatus.Pending)
            throw new DomainException("Cannot reject a non-pending request.");

        Status = ApprovalStatus.Rejected;
        ReviewedBy = reviewerId;
        Remarks = reason;
        ReviewedAt = DateTime.UtcNow;

        AddDomainEvent(new ApprovalRejectedEvent(ReferenceId, ReferenceType, reason));
    }
}
```

---

## Pending Approvals Dashboard

The Branch Manager's dashboard shows a prioritized list of pending approvals:

```
PENDING APPROVALS (6)
─────────────────────────────────────────
🔴 URGENT (> 4 hours old)
  Loan Application LN-2081-089   Ram Shrestha    NPR 5,00,000   5h 23m
  Large Withdrawal               Sita Tamang     NPR 2,00,000   4h 10m

🟡 NORMAL
  Member Approval                Hari Prasad     New Member     2h 15m
  Member Approval                Kamala Gurung   New Member     1h 45m
  Loan Application LN-2081-092   Bikash KC       NPR 2,00,000   45m
  Large Withdrawal               Rita Magar      NPR 1,50,000   20m
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/approvals/pending` | MANAGER | Get all pending approvals |
| POST | `/approvals/{id}/approve` | MANAGER | Approve a request |
| POST | `/approvals/{id}/reject` | MANAGER | Reject with reason |
| GET | `/approvals/history` | MANAGER | Approval history |
| GET | `/approvals/stats` | MANAGER | Avg approval time, rejection rate |
