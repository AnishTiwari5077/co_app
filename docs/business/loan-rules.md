# SahakariMS — Business: Loan Processing Rules

## Core Loan Rules

These rules are enforced at the domain layer in `SahakariMS.Domain` and cannot be bypassed.

---

## Eligibility Criteria

### Member Eligibility

| Rule Code | Rule | Details |
|-----------|------|---------|
| LN-E-001 | Active member | Member.Status must be `Active` |
| LN-E-002 | KYC verified | Member.KycVerified must be `True` |
| LN-E-003 | Minimum share holding | Must hold ≥ minimum shares per loan product |
| LN-E-004 | No active NPA | Member must have no existing NPA (loss/doubtful) loan |
| LN-E-005 | Minimum membership | Must have been active member for ≥ 3 months |
| LN-E-006 | Clean existing EMIs | No overdue EMI > 30 days on any existing loan |
| LN-E-007 | Maximum concurrent loans | Cannot exceed max loans per product config (default: 2) |

### Guarantor Eligibility

| Rule Code | Rule |
|-----------|------|
| LN-G-001 | Must be an Active member |
| LN-G-002 | Cannot be the same person as the borrower |
| LN-G-003 | Must not have an NPA loan themselves |
| LN-G-004 | Must not be guarantor on more than 3 active loans |
| LN-G-005 | Cannot be related party where conflict of interest exists |

---

## Loan Amount Limits

| Rule Code | Rule | Details |
|-----------|------|---------|
| LN-A-001 | Product minimum | Amount ≥ product.minAmount |
| LN-A-002 | Product maximum | Amount ≤ product.maxAmount |
| LN-A-003 | Multiple of share capital | Loan ≤ member.shareCapital × product.shareMultiplier |
| LN-A-004 | Gold loan LTV | Loan ≤ 80% of gold market value |
| LN-A-005 | Total exposure limit | Total loans to one member ≤ 10% of branch loan portfolio |

---

## Interest Rate Rules

| Rule Code | Rule | Details |
|-----------|------|---------|
| LN-I-001 | Minimum rate | Rate ≥ product.minInterestRate |
| LN-I-002 | Maximum rate | Rate ≤ product.maxInterestRate |
| LN-I-003 | Penalty rate | Penalty rate = base rate + 2% (configurable) |
| LN-I-004 | NPA penalty | Additional 2% penalty when classified NPA |
| LN-I-005 | Rate change notice | Rate changes require 30-day advance notice |

---

## Disbursement Rules

| Rule Code | Rule |
|-----------|------|
| LN-D-001 | Only approved loans can be disbursed |
| LN-D-002 | Disbursement only by Cashier or above |
| LN-D-003 | Disbursement within 30 days of approval (else re-approve) |
| LN-D-004 | Amount disbursed must equal approved amount exactly |
| LN-D-005 | Disbursement credited to member's own savings account |
| LN-D-006 | Processing fee deducted before or at disbursement |

---

## Repayment Rules

| Rule Code | Rule |
|-----------|------|
| LN-R-001 | Payment ≥ EMI amount (can pay more — advance) |
| LN-R-002 | Advance payment reduces outstanding principal |
| LN-R-003 | Partial payment (< EMI) accepted but marks EMI partially paid |
| LN-R-004 | Payment allocation: Penalty first → Interest → Principal |
| LN-R-005 | Prepayment penalty if closed before 25% of tenure |
| LN-R-006 | EMI due date = disbursement date + 1 month (same day each month) |
| LN-R-007 | If due date falls on weekend/holiday, due on next working day |

---

## Overdue and Penalty Rules

| Rule Code | Rule |
|-----------|------|
| LN-O-001 | EMI overdue from day after due date |
| LN-O-002 | Penalty calculated on overdue principal × penalty rate × overdue days / 365 |
| LN-O-003 | Penalty waiver only by Branch Manager |
| LN-O-004 | NPA status triggers branch manager and admin alert |
| LN-O-005 | Loan statement must show penalty separately from interest |

---

## Rescheduling Rules

Rescheduling changes the loan terms prospectively (does not modify past):

| Rule | Detail |
|------|--------|
| Approval | Requires Branch Manager approval |
| Frequency | Maximum 1 reschedule per loan |
| Timing | Cannot reschedule NPA Loss loans |
| Documentation | Reason and new terms must be documented |
| Accounting | New EMI schedule generated; old schedule closed |

---

## Write-Off Rules

| Rule | Detail |
|------|--------|
| Eligibility | Only NPA Loss classification (365+ days overdue) |
| Approval | Requires Admin (Head Office) approval |
| Accounting | Dr Loan Loss Provision / Cr Loan Receivable |
| Recovery | Future recoveries credited to income |
| Guarantor | Collection from guarantor continues after write-off |
| Report | Write-off loans remain on books for 10 years |

---

## Loan Domain Logic

```csharp
// Domain/Entities/Loan.cs (key business methods)

public class Loan : AggregateRoot
{
    // Guard: Cannot disburse if not Approved
    public void Disburse(Guid disbursedBy, string narration, decimal amount)
    {
        if (Status != LoanStatus.Approved)
            throw new DomainException($"Cannot disburse loan with status {Status}.");

        if (amount != PrincipalAmount)
            throw new DomainException("Disbursed amount must equal approved amount.");

        if (ApprovedAt.HasValue &&
            (DateTime.UtcNow - ApprovedAt.Value).TotalDays > 30)
            throw new DomainException("Approval has expired. Re-approval required.");

        Status = LoanStatus.Active;
        DisbursedAt = DateTime.UtcNow;
        DisbursedBy = disbursedBy;

        AddDomainEvent(new LoanDisbursedEvent(Id, MemberId, PrincipalAmount));
    }

    // Payment allocation: Penalty → Interest → Principal
    public LoanPaymentResult RecordPayment(decimal amount, DateTime paymentDate)
    {
        if (Status != LoanStatus.Active && Status != LoanStatus.Overdue)
            throw new DomainException("Cannot pay a closed or written-off loan.");

        decimal remaining = amount;
        decimal penaltyPaid = 0, interestPaid = 0, principalPaid = 0;

        // 1. Settle penalty first
        if (AccruedPenalty > 0)
        {
            penaltyPaid = Math.Min(remaining, AccruedPenalty);
            AccruedPenalty -= penaltyPaid;
            remaining -= penaltyPaid;
        }

        // 2. Settle interest
        var dueInterest = CalculateDueInterest(paymentDate);
        if (remaining > 0 && dueInterest > 0)
        {
            interestPaid = Math.Min(remaining, dueInterest);
            remaining -= interestPaid;
        }

        // 3. Remaining goes to principal
        if (remaining > 0)
        {
            principalPaid = Math.Min(remaining, OutstandingBalance);
            OutstandingBalance -= principalPaid;
        }

        // Auto-close if fully paid
        if (OutstandingBalance <= 0)
        {
            Status = LoanStatus.Closed;
            ClosedAt = DateTime.UtcNow;
            AddDomainEvent(new LoanClosedEvent(Id, MemberId));
        }

        return new LoanPaymentResult(penaltyPaid, interestPaid, principalPaid);
    }
}
```
