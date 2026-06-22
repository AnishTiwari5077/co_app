# SahakariMS — Business: Savings Rules

## Core Savings Rules

These rules govern all savings operations and are enforced at both the domain layer and database level.

---

## Account Opening Rules

| Rule | Details |
|------|---------|
| SAV-O-001 | Member must be Active to open an account |
| SAV-O-002 | Member can have multiple savings accounts (different schemes) |
| SAV-O-003 | Opening balance ≥ scheme minimum balance |
| SAV-O-004 | One FD per term (same member can have multiple FDs) |
| SAV-O-005 | Account type must be an active configured scheme |

---

## Deposit Rules

| Rule | Details |
|------|---------|
| SAV-D-001 | Amount > 0 |
| SAV-D-002 | Account must be Active (not Dormant, Frozen, or Closed) |
| SAV-D-003 | Member must be Active |
| SAV-D-004 | Minimum deposit = scheme minimum deposit amount |
| SAV-D-005 | Cheque deposits must include cheque number |
| SAV-D-006 | Post-dated cheques not accepted |

---

## Withdrawal Rules

| Rule | Details |
|------|---------|
| SAV-W-001 | Amount > 0 |
| SAV-W-002 | Account must be Active |
| SAV-W-003 | Balance after withdrawal ≥ scheme minimum balance |
| SAV-W-004 | Frozen accounts cannot be withdrawn |
| SAV-W-005 | Loan-pledged accounts: minimum balance = pledged amount |
| SAV-W-006 | Withdrawal amount > NPR 1,00,000 requires manager approval |
| SAV-W-007 | Member must be present at counter (or authorized via mobile for < NPR 50,000) |

---

## Interest Rules

| Rule | Details |
|------|---------|
| INT-001 | Daily product method: balance × rate / 365 per day |
| INT-002 | Interest accrues on minimum daily balance |
| INT-003 | Interest posted on last day of each month (Ashad 32 → Ashadh end) |
| INT-004 | If account closed before month-end, interest credited for days held |
| INT-005 | No interest on dormant accounts with zero balance |
| INT-006 | Interest is subject to 5% TDS (tax deducted at source) for Nepal |

---

## FD-Specific Rules

| Rule | Details |
|------|---------|
| FD-001 | FD tenure between scheme min and max (e.g., 1 month to 10 years) |
| FD-002 | Premature closure applies penalty rate deduction |
| FD-003 | Premature closure penalty = (Normal Rate - Penalty%) |
| FD-004 | Interest can be: Monthly credit | On Maturity |
| FD-005 | Auto-renewal on same terms if auto_renew = TRUE |
| FD-006 | Maturity alert sent 7 days and 1 day before maturity |
| FD-007 | Matured FD credited to linked savings account |

---

## Dormancy Rules

| Rule | Details |
|------|---------|
| DORM-001 | Account becomes Dormant after 12 months no transactions |
| DORM-002 | Dormant accounts cannot be transacted without manager reactivation |
| DORM-003 | Dormant reactivation requires fresh KYC verification |
| DORM-004 | Interest continues on dormant accounts |
| DORM-005 | Branch manager notified monthly of dormant accounts |

---

## Account Closure Rules

| Rule | Details |
|------|---------|
| CLO-001 | Account balance must be zero before closing (or full balance withdrawn) |
| CLO-002 | Outstanding loan pledge must be released first |
| CLO-003 | Manager approval required for closure |
| CLO-004 | Final interest credited before closure |
| CLO-005 | Closed accounts are read-only (historical view only) |

---

## Savings Domain Logic

```csharp
// Domain/Entities/SavingAccount.cs

public class SavingAccount : AggregateRoot
{
    public decimal CurrentBalance { get; private set; }
    public decimal MinimumBalance { get; private set; }
    public decimal? PledgedBalance { get; private set; }  // For loan collateral

    public void Deposit(decimal amount, DepositMode mode, string narration, Guid processedBy)
    {
        Guard.Against.NegativeOrZero(amount, nameof(amount));
        Guard.Against.StringTooShort(narration, 1, nameof(narration));

        if (Status != AccountStatus.Active)
            throw new DomainException($"Cannot deposit to a {Status} account.");

        if (amount < Scheme.MinimumDeposit)
            throw new DomainException(
                $"Minimum deposit is NPR {Scheme.MinimumDeposit:N2}.");

        CurrentBalance += amount;
        TotalDeposits += amount;

        AddDomainEvent(new SavingDepositedEvent(Id, MemberId, amount, CurrentBalance));
    }

    public void Withdraw(decimal amount, string narration, Guid processedBy)
    {
        Guard.Against.NegativeOrZero(amount, nameof(amount));

        if (Status == AccountStatus.Frozen)
            throw new DomainException("Account is frozen. Contact branch for assistance.");

        if (Status != AccountStatus.Active)
            throw new DomainException($"Cannot withdraw from a {Status} account.");

        // Effective minimum = max(scheme minimum, pledged balance)
        decimal effectiveMinimum = Math.Max(
            MinimumBalance,
            PledgedBalance ?? 0);

        if (CurrentBalance - amount < effectiveMinimum)
            throw new DomainException(
                $"Insufficient balance. Available for withdrawal: " +
                $"NPR {CurrentBalance - effectiveMinimum:N2}.");

        CurrentBalance -= amount;
        TotalWithdrawals += amount;

        AddDomainEvent(new SavingWithdrawnEvent(Id, MemberId, amount, CurrentBalance));
    }

    public void PostInterest(decimal interestAmount, DateOnly periodEnd, Guid postedBy)
    {
        if (interestAmount <= 0) return;  // Nothing to post

        // Apply 5% TDS on interest
        decimal tdsAmount = Math.Round(interestAmount * 0.05m, 2);
        decimal netInterest = interestAmount - tdsAmount;

        CurrentBalance += netInterest;
        AccruedInterest = 0;  // Reset accrual after posting

        AddDomainEvent(new InterestPostedEvent(Id, MemberId, netInterest, tdsAmount, periodEnd));
    }
}
```
