# SahakariMS — Module: Loans

## Overview

The Loan module manages the complete lifecycle of cooperative loans: from application and approval, through disbursement and EMI collection, to closure or NPA management. It is the most complex and critical module in the system.

---

## Loan Lifecycle

```
Application Submitted
       │
       ▼
  Under Review (Loan Officer)
       │
  ┌────┴────┐
Reject    Recommend for Approval
  │              │
  ▼              ▼
Notify      Manager Review
Member        │
          ┌───┴───┐
        Reject  Approve
          │         │
          ▼         ▼
       Notify   Approved
       Member      │
                   ▼
              Disburse (Cashier)
                   │
                   ▼
              Active (EMI running)
                   │
               ┌───┴──────────┐
           On Time           Overdue (1+ days)
               │                  │
               ▼                  ▼
           Continue          Substandard NPA (90d)
               │             Doubtful NPA (180d)
               ▼             Loss NPA (365d)
            Closed ◄──────── Write-Off
```

---

## Loan Types

| Type | Max Amount | Typical Rate | Collateral |
|------|-----------|-------------|-----------|
| Personal Loan | NPR 5 Lakh | 16% | Optional |
| Business Loan | NPR 50 Lakh | 14% | Required |
| Agriculture Loan | NPR 10 Lakh | 10% | Optional |
| Gold Loan | NPR 20 Lakh | 12% | Gold (80% LTV) |
| Vehicle Loan | NPR 30 Lakh | 13% | Vehicle |
| Education Loan | NPR 15 Lakh | 9% | Guarantor |
| Micro Loan | NPR 1 Lakh | 18% | None |

---

## Loan Product Configuration

```json
{
  "productCode": "BL-001",
  "productName": "Business Loan",
  "loanType": "Business",
  "minAmount": 100000,
  "maxAmount": 5000000,
  "minTenureMonths": 12,
  "maxTenureMonths": 120,
  "interestRate": 14.0,
  "interestMethod": "ReducingBalance",
  "penaltyRate": 2.0,
  "processingFeePct": 1.0,
  "requiresGuarantor": true,
  "requiresCollateral": true,
  "minGuarantors": 1
}
```

---

## EMI Calculation

See [interest-calculation.md](../business/interest-calculation.md) for full formulas.

**Reducing Balance Example:**
```
Principal:   NPR 500,000
Rate:        14% p.a. = 1.1667% per month
Tenure:      60 months

EMI = 500,000 × 0.011667 × (1.011667)^60 / ((1.011667)^60 - 1)
    = NPR 11,634.00 per month

Total Payable = 11,634 × 60 = NPR 6,98,040
Total Interest = 6,98,040 - 5,00,000 = NPR 1,98,040
```

---

## NPA Classification Rules

| Classification | Overdue Days | Provision Required |
|---------------|-------------|-------------------|
| Standard | 0 | 1% |
| Watch List | 1–89 | 5% |
| Substandard | 90–179 | 25% |
| Doubtful | 180–364 | 50% |
| Loss | 365+ | 100% |

NPA classification runs as a **Hangfire background job** nightly at 12:30 AM:

```csharp
[AutomaticRetry(Attempts = 3)]
public class NpaClassificationJob
{
    public async Task ExecuteAsync()
    {
        var activeLoans = await _loanRepo.GetActiveAndOverdueLoansAsync();

        foreach (var loan in activeLoans)
        {
            var oldestUnpaidEmi = loan.Schedule
                .Where(s => s.Status != EmiStatus.Paid)
                .MinBy(s => s.DueDate);

            if (oldestUnpaidEmi is null) continue;

            int overdueDays = (DateOnly.FromDateTime(DateTime.Today) - oldestUnpaidEmi.DueDate).Days;
            var newClassification = DetermineNpaClassification(overdueDays);

            if (newClassification != loan.NpaClassification)
            {
                loan.UpdateNpaClassification(newClassification);
                await _loanRepo.UpdateAsync(loan);
                await _notificationService.NotifyBranchManagerAsync(loan, newClassification);
            }
        }
    }

    private NpaClassification DetermineNpaClassification(int overdueDays) => overdueDays switch
    {
        0          => NpaClassification.Standard,
        <= 89      => NpaClassification.Watchlist,
        <= 179     => NpaClassification.Substandard,
        <= 364     => NpaClassification.Doubtful,
        _          => NpaClassification.Loss
    };
}
```

---

## Loan Disbursement Accounting

```
When loan is disbursed:
  Dr  Loan Receivable (Loans)           500,000
  Cr  Member Savings Account            500,000

When EMI payment received:
  Dr  Cash in Hand                      11,634
  Cr  Loan Receivable (principal)        5,801
  Cr  Interest Income                    5,833

When penalty charged:
  Dr  Cash in Hand                      (penalty)
  Cr  Penalty Income                    (penalty)

When loan written off:
  Dr  Loan Loss Provision               500,000
  Cr  Loan Receivable                   500,000
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| POST | `/loans` | LOANS_APPLY | Submit loan application |
| GET | `/loans` | LOANS_VIEW | List loans (paginated, filterable) |
| GET | `/loans/{id}` | LOANS_VIEW | Get loan details |
| GET | `/loans/{id}/schedule` | LOANS_VIEW | Get full EMI schedule |
| POST | `/loans/{id}/approve` | LOANS_APPROVE | Approve loan |
| POST | `/loans/{id}/reject` | LOANS_APPROVE | Reject with reason |
| POST | `/loans/{id}/disburse` | LOANS_DISBURSE | Disburse approved loan |
| POST | `/loans/{id}/payment` | LOANS_VIEW | Record EMI payment |
| POST | `/loans/{id}/reschedule` | LOANS_APPROVE | Reschedule loan |
| POST | `/loans/{id}/write-off` | LOANS_WRITE_OFF | Write off NPA loan |
| GET | `/loans/{id}/noc` | LOANS_VIEW | Download closure NOC (PDF) |
| GET | `/loans/overdue` | LOANS_VIEW | List overdue loans |
| GET | `/loans/npa` | LOANS_VIEW | List NPA loans |
| GET | `/loans/disbursements-today` | LOANS_VIEW | Today's disbursements |

---

## Flutter UI Screens

### Loan Application Form (Multi-step)

1. **Loan Details** — Type, amount, tenure, purpose
2. **Guarantors** — Search and select from active members
3. **Collateral** — Type, description, estimated value, photos
4. **Documents** — Upload income proof, business registration
5. **Review & Submit**

### Loan Detail Screen

- Header: Loan number, status badge, member name
- Key figures: Disbursed amount, outstanding balance, next EMI
- Progress bar: % of loan repaid
- EMI schedule table (grouped by year, expandable)
- Payment history
- Actions: Make Payment, Download Statement, View NOC

### NPA Dashboard

- Summary cards: Total NPA amount, % of portfolio
- Breakdown by classification (Standard / Watch / Substandard / Doubtful / Loss)
- Sortable, filterable table
- Export to Excel button

---

## Guarantor Rules

| Rule | Detail |
|------|--------|
| Must be Active member | Guarantor must have Active status |
| Cannot be the borrower | Self-guarantee not allowed |
| NPA block | Member with NPA loan cannot be guarantor |
| Maximum guarantees | Configurable per branch (default: 3 loans) |
| Liability | Guarantor is liable for full outstanding on default |
