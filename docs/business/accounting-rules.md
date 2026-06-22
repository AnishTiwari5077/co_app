# SahakariMS — Business: Accounting Rules

## Overview

These rules govern all accounting operations. The system strictly follows Nepal cooperative accounting standards and double-entry bookkeeping principles.

---

## Double-Entry Rules

| Rule | Detail |
|------|--------|
| ACC-001 | Every transaction must have equal debits and credits |
| ACC-002 | Minimum 2 entries per voucher |
| ACC-003 | No entry can simultaneously have both debit and credit amounts |
| ACC-004 | Vouchers cannot be posted if imbalanced |
| ACC-005 | Auto-generated vouchers cannot be manually reversed |

---

## Account Type Rules (Normal Balance)

| Account Type | Normal Balance | Increases With | Decreases With |
|-------------|---------------|---------------|---------------|
| Asset | Debit | Debit | Credit |
| Liability | Credit | Credit | Debit |
| Equity | Credit | Credit | Debit |
| Income | Credit | Credit | Debit |
| Expense | Debit | Debit | Credit |

---

## Voucher Rules

| Rule | Detail |
|------|--------|
| VCH-001 | Vouchers must be dated within the current or previous fiscal year |
| VCH-002 | Vouchers in a closed fiscal year cannot be posted |
| VCH-003 | Posted vouchers are immutable — create reversal for corrections |
| VCH-004 | Reversals must use the original posting date or a later date |
| VCH-005 | Void (unposted) vouchers can be deleted within 7 days |

---

## Cash Counter Rules

| Rule | Detail |
|------|--------|
| CSH-001 | Cashier must open session before processing any transactions |
| CSH-002 | Only one open session per cashier per day |
| CSH-003 | Session closing cash must be counted and entered |
| CSH-004 | Cash difference > NPR 500 triggers manager review |
| CSH-005 | Session cannot be closed if pending transactions remain |
| CSH-006 | End-of-day reconciliation must be completed before next day |

---

## Chart of Accounts Rules

| Rule | Detail |
|------|--------|
| COA-001 | Nepal Cooperative Standard COA structure must be maintained |
| COA-002 | Parent-child account hierarchy max 4 levels deep |
| COA-003 | Summary accounts (with children) cannot receive direct entries |
| COA-004 | Deleting an account is not allowed if it has transaction history |
| COA-005 | Account codes follow 4-digit standard (1000–1999 Assets, etc.) |

---

## Nepal Cooperative Chart of Accounts

```
1000 ASSETS
  1100  Cash and Cash Equivalents
    1101    Cash in Hand
    1102    Cash at Bank
    1103    Cash in Transit
  1200  Loan Receivables
    1201    Business Loans
    1202    Agriculture Loans
    1203    Personal Loans
    1204    Home Loans
    1205    Microfinance Loans
    1290    Loan Loss Provision (contra)
  1300  Savings and Investments
    1301    Interbank Deposits
    1302    Government Securities
  1400  Fixed Assets
    1401    Land and Building
    1402    Furniture and Fixtures
    1403    Computer Equipment
    1490    Accumulated Depreciation (contra)
  1500  Other Assets
    1501    Prepaid Expenses
    1502    Accrued Interest Receivable
    1503    Other Receivables

2000 LIABILITIES
  2100  Member Savings
    2101    Regular Savings
    2102    Fixed Deposits
    2103    Recurring Deposits
    2104    Special Savings
  2200  Share Capital
    2201    Paid-up Share Capital
  2300  Payables
    2301    Interest Payable
    2302    Tax Payable (TDS)
    2303    PF Payable (SSF)
    2304    Salary Payable
    2305    Dividend Payable
  2400  Borrowings
    2401    Loans from Banks
    2402    Loans from Primary Cooperatives

3000 EQUITY
  3100  Cooperative Fund
    3101    Reserve Fund (25% of profit)
    3102    Education Fund (5%)
    3103    Cooperative Development Fund (3%)
    3104    Welfare Fund (2%)
  3200  Retained Earnings
    3201    Prior Year Surplus
    3202    Current Year Surplus

4000 INCOME
  4100  Interest Income
    4101    Interest on Business Loans
    4102    Interest on Agriculture Loans
    4103    Interest on Personal Loans
    4104    Interest on Bank Deposits
  4200  Fee Income
    4201    Loan Processing Fee
    4202    Account Maintenance Fee
    4203    Late Payment Fee (Penalty)
  4300  Other Income
    4301    Miscellaneous Income

5000 EXPENSES
  5100  Interest Expense
    5101    Interest on Member Savings
    5102    Interest on Fixed Deposits
    5103    Interest on Borrowings
  5200  Personnel Expenses
    5201    Staff Salaries
    5202    Staff Allowances
    5203    Staff Training
    5204    Employer PF Contribution
  5300  Administrative Expenses
    5301    Office Rent
    5302    Electricity and Water
    5303    Telephone and Internet
    5304    Stationery and Printing
    5305    Audit Fees
  5400  Provision
    5401    Loan Loss Provision Expense
    5402    Depreciation Expense
```

---

## Fiscal Year Rules

| Rule | Detail |
|------|--------|
| FY-001 | Nepal cooperative fiscal year: Shrawan 1 – Ashad 31 (Apr–Jul Gregorian) |
| FY-002 | Fiscal year must be closed before new year's transactions are posted |
| FY-003 | Closing entries: Income and expense accounts transferred to retained earnings |
| FY-004 | Opening balances for new year = Closing balances of previous year |
| FY-005 | Comparative reports show current and previous year side by side |

---

## Reserve Fund Allocation (Cooperative Act)

At year-end, cooperative surplus is distributed:

```
Net Surplus = Total Income - Total Expenses

Mandatory allocations (Nepal Cooperative Act 2074):
  Reserve Fund:            25% of net surplus
  Cooperative Dev Fund:    5% of net surplus
  Education Fund:          3% of net surplus
  Welfare Fund:            2% of net surplus
  Social Fund:             variable (board decision)

Remaining surplus available for:
  Dividend:                Max 25% of share capital
  Bonus to staff:          Max 10% of salary
  Retained earnings:       Balance
```
