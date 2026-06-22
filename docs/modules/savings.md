# SahakariMS — Module: Savings & Deposits

## Overview

The Savings module manages all member deposit accounts including regular savings, recurring deposits (RD), fixed deposits (FD), and specialized schemes (daily, women, child, etc.).

---

## Account Types

| Account Type | Description | Interest Posting |
|-------------|-------------|-----------------|
| Regular Savings | Standard savings account | Monthly |
| Daily Savings | Daily collection scheme | Monthly |
| Women Savings | Special scheme for women | Monthly |
| Child Savings | Minors' savings (guardian) | Monthly |
| Senior Savings | Senior citizen scheme | Monthly |
| Recurring Deposit (RD) | Fixed monthly installment | On Maturity |
| Fixed Deposit (FD) | Lump sum for fixed tenure | Monthly or On Maturity |
| Special Purpose | Housing, education, etc. | Quarterly |

---

## Savings Scheme Configuration

Each scheme defines:
```
scheme_code:          REG-001
scheme_name:          Regular Savings
account_type:         Regular
interest_rate:        7.5%  (p.a.)
min_balance:          NPR 100
min_deposit:          NPR 50
withdrawal_allowed:   TRUE
interest_frequency:   Monthly
penalty_rate:         0%
```

---

## Account Number Format

```
{TYPE_PREFIX}-{BRANCH_CODE}-{YEAR}-{SEQUENCE}

Examples:
  SAV-KTM-2081-00456   ← Regular savings
  FD-KTM-2081-00089    ← Fixed deposit
  RD-PKR-2081-00012    ← Recurring deposit
```

---

## Interest Calculation

See [interest-calculation.md](../business/interest-calculation.md) for complete formulas.

### Daily Product Method (Regular Savings)

```
Daily Interest = Balance × Rate / (Days in Year × 100)
Monthly Interest = Sum of Daily Interest

Example (NPR 50,000 @ 7.5% p.a.):
  Daily Interest = 50,000 × 7.5 / (365 × 100) = NPR 10.274
  Monthly (30 days) = NPR 308.22
```

---

## Transactions

### Deposit

```
POST /savings/accounts/{id}/deposit
{
  "amount": 5000.00,
  "depositMode": "Cash",        // Cash | Cheque | Transfer
  "narration": "Daily savings",
  "chequeNumber": null,
  "collectedBy": null           // Collector UUID if via collector app
}

Response:
{
  "transactionId": "uuid",
  "receiptNumber": "RCP-KTM-2081-04567",
  "amount": 5000.00,
  "balanceBefore": 45000.00,
  "balanceAfter": 50000.00,
  "transactionDate": "2081-04-15"
}

Accounting Entry:
  Dr  Cash in Hand (or Bank)      5,000
  Cr  Member Savings Account      5,000
```

### Withdrawal

```
POST /savings/accounts/{id}/withdraw
{
  "amount": 2000.00,
  "withdrawalMode": "Cash",
  "narration": "Emergency",
  "verifiedBy": "uuid"           // Supervisor for large withdrawals
}

Business Rules:
  - amount > 0
  - amount ≤ current_balance - min_balance
  - account.status == 'Active'
  - member.status == 'Active'

Accounting Entry:
  Dr  Member Savings Account      2,000
  Cr  Cash in Hand                2,000
```

---

## Fixed Deposit (FD)

### Creation

```json
{
  "memberId": "uuid",
  "schemeId": "uuid",
  "principal": 500000.00,
  "tenureMonths": 12,
  "interestMode": "Monthly",      // Monthly | OnMaturity
  "interestCreditAccountId": "uuid",
  "autoRenew": false,
  "nomineeId": "uuid"
}
```

### Maturity Calculation

```
Principal:  500,000
Rate:       12% p.a.
Tenure:     12 months

Total Interest = 500,000 × 12 / 100 = NPR 60,000
Monthly Interest = 60,000 / 12 = NPR 5,000/month
Maturity Amount = 500,000 + 60,000 = NPR 560,000
```

### Premature Closure

```
Normal Rate: 12%
Penalty: 2% (configurable)
Effective Rate: 10%

If closed after 6 months:
Actual Interest = 500,000 × 10% × 180 / (365 × 100) = NPR 24,657.53
Normal Interest = 500,000 × 12% × 180 / (365 × 100) = NPR 29,589.04
Penalty = 29,589.04 - 24,657.53 = NPR 4,931.51
Net Payable = 500,000 + 24,657.53 = NPR 524,657.53
```

---

## Recurring Deposit (RD)

### Rules

- Fixed monthly installment amount set at account opening
- Installment must be paid by the end of each month
- Late payment penalty applied on overdue installments
- Maturity amount = (Monthly Amount × Tenure) + Accumulated Interest
- On completion, amount credited to linked savings account

### Installment Tracking

```
RD Account: RD-KTM-2081-00045
Monthly Amount: NPR 5,000
Tenure: 24 months
Total Corpus: NPR 120,000 + interest

Month  Due Date     Paid Date    Amount     Status
  1    2081-04-30   2081-04-28   5,000      Paid
  2    2081-05-31   2081-05-29   5,000      Paid
  3    2081-06-30   —            —          Pending
```

---

## Account Freezing

```
Reasons for freeze:
  - Legal court order
  - Member death (pending nominee transfer)
  - Loan default investigation
  - Suspicious activity

POST /savings/accounts/{id}/freeze
{
  "reason": "Court order case #2081/CV/123",
  "orderedBy": "District Court Lalitpur"
}

Effects:
  - No deposits or withdrawals allowed
  - Interest continues to accrue
  - Account appears as 'Frozen' in all reports
```

---

## Dormant Account Policy

- Account becomes **Dormant** after 12 months of no transactions
- Dormant account requires manager approval for reactivation
- Dormant accounts are excluded from active reporting
- Interest continues to accrue on dormant accounts

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/savings/accounts` | SAVINGS_VIEW | List accounts |
| POST | `/savings/accounts` | SAVINGS_VIEW | Open new account |
| GET | `/savings/accounts/{id}` | SAVINGS_VIEW | Account details |
| GET | `/savings/accounts/{id}/statement` | SAVINGS_VIEW | Statement |
| POST | `/savings/accounts/{id}/deposit` | SAVINGS_DEPOSIT | Deposit |
| POST | `/savings/accounts/{id}/withdraw` | SAVINGS_WITHDRAW | Withdraw |
| POST | `/savings/accounts/{id}/freeze` | SAVINGS_FREEZE | Freeze account |
| POST | `/savings/accounts/{id}/unfreeze` | SAVINGS_FREEZE | Unfreeze |
| POST | `/savings/accounts/{id}/close` | SAVINGS_CLOSE | Close account |
| GET | `/savings/schemes` | SAVINGS_VIEW | List schemes |
| POST | `/savings/schemes` | SETTINGS_EDIT | Create scheme |
| GET | `/savings/interest/pending` | SAVINGS_VIEW | Pending interest |
| POST | `/savings/interest/post` | SAVINGS_INTEREST | Post monthly interest |
| GET | `/savings/fd` | SAVINGS_VIEW | List FDs |
| POST | `/savings/fd` | SAVINGS_VIEW | Create FD |
| POST | `/savings/fd/{id}/close` | SAVINGS_CLOSE | Close FD |
| GET | `/savings/rd` | SAVINGS_VIEW | List RDs |
| POST | `/savings/rd` | SAVINGS_VIEW | Create RD |
| POST | `/savings/rd/{id}/pay` | SAVINGS_DEPOSIT | Pay RD installment |

---

## Flutter UI Screens

### Savings Dashboard

- Total savings balance (all accounts)
- Recent transactions timeline
- Quick action buttons: Deposit, Withdraw, Transfer
- Account cards: account number, type, balance, interest rate

### Account Statement

- Date range picker (BS calendar)
- Transaction list with color coding:
  - Green = Deposits + Interest credits
  - Red = Withdrawals + Penalty debits
- Running balance column
- Download PDF button
- Share button

### Deposit/Withdrawal Form

- Amount input with denomination helper
- Payment mode selector: Cash / Cheque / Transfer
- Narration field
- Confirm screen showing receipt preview
- Bluetooth print button after confirmation
