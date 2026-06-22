# SahakariMS — Business Rules

## Overview

Business rules define the non-negotiable constraints that govern cooperative operations. These rules are **enforced at the Domain Layer** inside entity methods and domain services — not in controllers or handlers.

---

## 1. Member Rules

| Rule ID | Rule | Enforcement |
|---------|------|------------|
| MEM-001 | A member must be at least 18 years old at registration | Domain entity |
| MEM-002 | Citizenship number must be unique across the entire system | DB unique constraint |
| MEM-003 | A member must hold minimum 10 shares to be Active | Domain event on share purchase |
| MEM-004 | A member cannot be closed while they have an outstanding loan balance | Domain entity |
| MEM-005 | A member cannot be closed while they have a non-zero savings balance | Domain entity |
| MEM-006 | KYC must be verified before a member can take a loan | Application layer check |
| MEM-007 | A closed member's member code cannot be reused | DB unique constraint (soft delete) |
| MEM-008 | Only one share account per member | DB unique constraint |
| MEM-009 | Nominee share percentages across all nominees must total 100% | Domain validation |
| MEM-010 | A suspended member cannot perform deposits or withdrawals | Permission check |

---

## 2. Share Rules

| Rule ID | Rule | Enforcement |
|---------|------|------------|
| SHR-001 | Share value is fixed per cooperative settings (e.g., NPR 100/share) | Settings lookup |
| SHR-002 | Share purchase must be a whole number of shares | Domain validation |
| SHR-003 | Minimum share purchase: per branch settings | Domain entity |
| SHR-004 | Shares cannot be refunded if outstanding loan exists | Domain entity |
| SHR-005 | Share transfer requires both members to be Active | Domain entity |
| SHR-006 | Shares transferred from closed members are refunded automatically | Domain event |
| SHR-007 | Dividend is calculated on shares held throughout the fiscal year | Domain service |
| SHR-008 | Share certificate number must be unique | DB unique constraint |
| SHR-009 | Partial share refund is allowed only if minimum shares remain | Domain entity |

---

## 3. Savings Rules

| Rule ID | Rule | Enforcement |
|---------|------|------------|
| SAV-001 | Minimum balance must be maintained at all times | Domain entity on withdrawal |
| SAV-002 | Withdrawal cannot exceed current balance minus minimum balance | Domain entity |
| SAV-003 | A Frozen account cannot process deposits or withdrawals | Domain entity |
| SAV-004 | A Closed account cannot process any transactions | Domain entity |
| SAV-005 | Deposits must be positive amounts | DB check constraint |
| SAV-006 | Withdrawals must be positive amounts and ≤ available balance | Domain entity |
| SAV-007 | Interest calculation uses the daily product method | Domain service |
| SAV-008 | Interest is posted as a credit to the savings account | Accounting service |
| SAV-009 | On account closure, accrued interest must be posted first | Domain entity |
| SAV-010 | SMS notification is triggered on every deposit and withdrawal | Domain event |
| SAV-011 | A member can have multiple savings accounts of different scheme types | No restriction |
| SAV-012 | Account numbers are system-generated and immutable | Domain entity |

---

## 4. Fixed Deposit Rules

| Rule ID | Rule | Enforcement |
|---------|------|------------|
| FD-001 | Minimum FD amount per scheme settings | Domain entity |
| FD-002 | FD tenure must be between scheme minimum and maximum | Domain entity |
| FD-003 | Premature closure is allowed with penalty deduction | Domain entity |
| FD-004 | Premature penalty rate = configured rate × remaining months | Domain service |
| FD-005 | FD interest can be posted monthly or on maturity (per scheme) | Domain service |
| FD-006 | Auto-renewal creates a new FD with same amount and tenure | Domain event on maturity |
| FD-007 | Matured FD amount is credited to linked savings account | Domain event |
| FD-008 | FD cannot be withdrawn partially — only full closure | Domain entity |
| FD-009 | FD maturity alert sent 7 days and 1 day before maturity | Background job |
| FD-010 | FD is linked to a regular savings account for interest credit | Domain entity |

---

## 5. Loan Rules

| Rule ID | Rule | Enforcement |
|---------|------|------------|
| LN-001 | Loan amount cannot exceed member's borrowing limit (product max) | Domain entity |
| LN-002 | Member must not have an NPA loan to apply for a new loan | Application layer |
| LN-003 | Member's total outstanding loans ≤ configured debt-to-income limit | Domain service |
| LN-004 | Guarantor must be an Active member of the same cooperative | Domain entity |
| LN-005 | A member cannot be their own guarantor | Domain entity |
| LN-006 | A member with an active NPA loan cannot be a guarantor | Domain entity |
| LN-007 | Loan disbursement only to member's active savings account | Domain entity |
| LN-008 | EMI schedule is generated automatically at disbursement | Domain service |
| LN-009 | EMI amount is fixed for the tenure (reducing balance method) | Domain service |
| LN-010 | Penalty accrues daily after grace period (configurable 7 days) | Background job |
| LN-011 | Penalty = outstanding EMI × penalty rate per day × overdue days | Domain service |
| LN-012 | Advance payment reduces principal and recalculates schedule | Domain service |
| LN-013 | Loan is classified Overdue after 1 day past EMI due date | Background job |
| LN-014 | Loan is classified Substandard NPA after 90 days overdue | Background job |
| LN-015 | Loan is classified Doubtful NPA after 180 days overdue | Background job |
| LN-016 | Loan is classified Loss NPA after 365 days overdue | Background job |
| LN-017 | Loan rescheduling requires Manager approval | Workflow rule |
| LN-018 | Loan write-off requires Board/Committee approval | Workflow rule |
| LN-019 | On loan closure, NOC is auto-generated | Domain event |
| LN-020 | Processing fee is deducted from disbursed amount | Domain entity |

---

## 6. Accounting Rules

| Rule ID | Rule | Enforcement |
|---------|------|------------|
| ACC-001 | Every journal entry must balance: total debits = total credits | Domain entity |
| ACC-002 | A voucher must have at least 2 entry lines | Domain entity |
| ACC-003 | Posted vouchers cannot be edited — only reversed | Domain entity |
| ACC-004 | Reversal creates a new voucher with opposite signs | Domain service |
| ACC-005 | Cash transactions auto-create accounting vouchers | Domain event |
| ACC-006 | Savings deposit: Dr Cash / Cr Member Savings Account | Accounting service |
| ACC-007 | Savings withdrawal: Dr Member Savings Account / Cr Cash | Accounting service |
| ACC-008 | Loan disbursement: Dr Loan Account / Cr Cash | Accounting service |
| ACC-009 | EMI payment: Dr Cash / Cr Loan Account (principal), Cr Interest Income | Accounting service |
| ACC-010 | Interest posting: Dr Interest Expense / Cr Member Savings Account | Accounting service |
| ACC-011 | Voucher date cannot be in a closed fiscal year | Domain entity |
| ACC-012 | Fiscal year can only be closed when trial balance is balanced | Domain entity |
| ACC-013 | Opening balance can only be entered in the first fiscal year | Domain entity |
| ACC-014 | System accounts (Cash, Bank) cannot be deleted | DB constraint |

---

## 7. Cash Counter Rules

| Rule ID | Rule | Enforcement |
|---------|------|------------|
| CSH-001 | Each cashier must open a session before processing transactions | Domain entity |
| CSH-002 | Session opening balance must be entered with denomination breakdown | Application layer |
| CSH-003 | Cashier cannot process transactions on another cashier's session | Permission check |
| CSH-004 | Closing cash must reconcile with opening + deposits − withdrawals | Domain entity |
| CSH-005 | Difference (shortage/excess) must be entered with reason | Domain entity |
| CSH-006 | Only one open session per cashier per day | DB constraint |
| CSH-007 | Vault transfer requires supervisor approval | Workflow rule |

---

## 8. Interest Calculation Rules

See detailed documentation in [interest-calculation.md](interest-calculation.md).

| Rule ID | Rule |
|---------|------|
| INT-001 | Savings interest = (Daily Balance × Interest Rate × 1) / (365 × 100) |
| INT-002 | Interest calculated on daily closing balance |
| INT-003 | Leap year uses 366 days |
| INT-004 | FD interest = Principal × Rate × Tenure (days) / (365 × 100) |
| INT-005 | Loan interest (reducing balance) = Outstanding × Rate / (12 × 100) |
| INT-006 | Loan interest (flat rate) = Principal × Rate × Tenure / (12 × 100) |
| INT-007 | Interest is never negative |
| INT-008 | Interest is rounded to 2 decimal places for posting |

---

## 9. Audit Rules

| Rule ID | Rule |
|---------|------|
| AUD-001 | Every financial transaction generates an audit log entry |
| AUD-002 | Login and logout events are always logged |
| AUD-003 | Audit logs are immutable — they cannot be edited or deleted |
| AUD-004 | Audit logs are retained for minimum 7 years |
| AUD-005 | Failed login attempts are logged with reason |
| AUD-006 | Permission changes are logged with old and new values |
| AUD-007 | Document access (download) is logged |

---

## 10. Security Rules

| Rule ID | Rule |
|---------|------|
| SEC-001 | Passwords must meet complexity policy (8+ chars, upper, lower, digit, special) |
| SEC-002 | Last 5 passwords cannot be reused |
| SEC-003 | Account locked after 5 consecutive failed logins |
| SEC-004 | 2FA mandatory for Administrator and Manager roles |
| SEC-005 | Session invalidated immediately on password change |
| SEC-006 | All HTTP requests redirected to HTTPS |
| SEC-007 | API tokens must be sent in Authorization header only |
| SEC-008 | Fingerprint data stored only in AES-256 encrypted form |
| SEC-009 | PAN numbers stored only in AES-256 encrypted form |
| SEC-010 | Deleted records are soft-deleted only; physical deletion requires DBA approval |
