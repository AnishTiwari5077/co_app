# SahakariMS — Module: Accounting

## Overview

The Accounting module implements a **double-entry bookkeeping** system following Nepal's cooperative accounting standards. Every financial transaction automatically generates journal vouchers, ensuring a complete and balanced accounting trail.

---

## Chart of Accounts

Nepal cooperative standard chart of accounts follows a 5-level hierarchy:

```
Level 1 — Account Class
Level 2 — Account Group
Level 3 — Account Category
Level 4 — Account Type
Level 5 — Ledger Account (leaf — postings happen here)
```

### Standard Chart of Accounts

```
1. ASSETS
   1.1 Current Assets
       1.1.1 Cash and Bank
             1.1.1.1 Cash in Hand
                     1.1.1.1.01 Main Counter Cash
                     1.1.1.1.02 Collector Cash
             1.1.1.2 Cash at Bank
                     1.1.1.2.01 Nepal Rastra Bank A/C
                     1.1.1.2.02 Himalayan Bank A/C
       1.1.2 Investments
             1.1.2.1 Fixed Deposits at Banks
             1.1.2.2 Government Securities
       1.1.3 Loan Receivables
             1.1.3.1 Personal Loans
             1.1.3.2 Business Loans
             1.1.3.3 Agriculture Loans
             1.1.3.4 Gold Loans
             1.1.3.5 Provision for Loan Loss (contra)
       1.1.4 Accrued Interest Receivable
       1.1.5 Other Current Assets
   1.2 Fixed Assets
       1.2.1 Furniture and Fixtures
       1.2.2 Equipment and Computers
       1.2.3 Vehicles
       1.2.4 Accumulated Depreciation (contra)

2. LIABILITIES
   2.1 Current Liabilities
       2.1.1 Member Savings
             2.1.1.1 Regular Savings Deposits
             2.1.1.2 FD Deposits
             2.1.1.3 RD Deposits
             2.1.1.4 Accrued Interest Payable
       2.1.2 Other Payables
   2.2 Long-term Liabilities
       2.2.1 Borrowings from Banks

3. EQUITY
   3.1 Share Capital
       3.1.1 Paid-up Share Capital
   3.2 Reserves
       3.2.1 General Reserve (25% of profit — mandatory)
       3.2.2 Cooperative Development Fund (5%)
       3.2.3 Social Development Fund (3%)
       3.2.4 Staff Welfare Fund (2%)
       3.2.5 Dividend Equalization Fund
   3.3 Retained Earnings
       3.3.1 Surplus from Previous Years

4. INCOME (REVENUE)
   4.1 Interest Income
       4.1.1 Loan Interest Income
       4.1.2 Bank FD Interest Income
       4.1.3 Investment Income
   4.2 Fee Income
       4.2.1 Processing Fees
       4.2.2 Service Charges
   4.3 Other Income
       4.3.1 Penalty Income
       4.3.2 Miscellaneous Income

5. EXPENSES
   5.1 Interest Expense
       5.1.1 Savings Interest Expense
       5.1.2 FD Interest Expense
   5.2 Operating Expenses
       5.2.1 Staff Salaries
       5.2.2 Rent
       5.2.3 Utilities
       5.2.4 Communication
       5.2.5 Stationery
   5.3 Depreciation
   5.4 Loan Loss Provision
   5.5 Other Expenses
```

---

## Voucher Types

| Type | Abbreviation | Usage |
|------|-------------|-------|
| Journal Voucher | JV | General adjustments, corrections |
| Payment Voucher | PV | Cash paid out |
| Receipt Voucher | RV | Cash received |
| Contra Voucher | CV | Cash/bank transfers |
| Opening Voucher | OV | Opening balances (first time only) |

---

## Auto-Generated Accounting Entries

Every financial operation automatically creates and posts a voucher:

| Operation | Dr | Cr |
|-----------|----|----|
| Member savings deposit (Cash) | Cash in Hand | Regular Savings Deposits |
| Member savings withdrawal (Cash) | Regular Savings Deposits | Cash in Hand |
| Loan disbursement | Loan Receivable | Cash in Hand |
| EMI payment received | Cash in Hand | Loan Receivable (principal) + Loan Interest Income |
| Monthly interest posting (savings) | Savings Interest Expense | Accrued Interest Payable |
| Interest credit to account | Accrued Interest Payable | Regular Savings Deposits |
| FD created | Cash in Hand | FD Deposits |
| FD matured | FD Deposits + FD Interest Expense | Cash in Hand |
| Share purchase | Cash in Hand | Share Capital |
| Share refund | Share Capital | Cash in Hand |
| Penalty collected | Cash in Hand | Penalty Income |
| Processing fee | Cash in Hand | Processing Fee Income |

---

## Trial Balance

The trial balance verifies that debits = credits. Generated from the `accounting.accounts` table:

```
TRIAL BALANCE
Pokhara Branch — As of 2081-04-15

Account Code  Account Name                Dr (NPR)      Cr (NPR)
──────────────────────────────────────────────────────────────
1.1.1.1.01    Cash in Hand               8,50,000.00
1.1.3.1       Personal Loans           2,50,00,000.00
1.1.3.2       Business Loans           8,50,00,000.00
1.1.3.5       Loan Loss Provision                       12,50,000.00
2.1.1.1       Regular Savings                         3,45,00,000.00
2.1.1.2       FD Deposits                             2,00,00,000.00
2.1.1.4       Accrued Interest Payable                   1,50,000.00
3.1.1         Share Capital                              45,00,000.00
4.1.1         Loan Interest Income                      25,00,000.00
5.1.1         Savings Interest Expense   18,00,000.00
──────────────────────────────────────────────────────────────
              TOTALS                   11,27,50,000.00 11,27,50,000.00
              DIFFERENCE               0.00 ✓ BALANCED
```

---

## Balance Sheet

```
BALANCE SHEET
SahakariMS — Pokhara Branch
As of 2081-04-15

ASSETS                           NPR
─────────────────────────────────────
Current Assets
  Cash in Hand                8,50,000
  Loan Receivable          11,00,00,000
  Less: Loan Loss Provision   (12,50,000)
  Accrued Interest Rec.       1,50,000
Total Current Assets        10,97,50,000

Fixed Assets
  Furniture & Equipment        5,00,000
  Less: Depreciation           (2,00,000)
Total Fixed Assets             3,00,000

TOTAL ASSETS                11,00,50,000
─────────────────────────────────────
LIABILITIES & EQUITY             NPR
─────────────────────────────────────
Member Savings               5,45,00,000
FD Deposits                  2,00,00,000
Accrued Interest Payable        1,50,000
Total Liabilities            7,46,50,000

Share Capital                  45,00,000
General Reserve                20,00,000
Staff Welfare Fund              5,00,000
Surplus                        84,00,000
Total Equity                  1,54,00,000

TOTAL LIABILITIES & EQUITY  9,00,50,000
─────────────────────────────────────
(Remaining assets funded by borrowings)
```

---

## Fiscal Year Close

At the end of each fiscal year (Chaitra 2081 = ~April 2025):

1. Post all outstanding interest
2. Calculate profit/loss
3. Allocate profit to reserves (as per Nepal Cooperative Act):
   - General Reserve: 25%
   - Cooperative Dev Fund: 5%
   - Social Dev Fund: 3%
   - Staff Welfare Fund: 2%
   - Dividend Equalization Fund: variable
   - Dividend to members: remainder
4. Post dividend to member share accounts
5. Close fiscal year (lock all prior vouchers)
6. Open new fiscal year with opening balances

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/accounting/accounts` | ACCOUNTING_VIEW | Get chart of accounts |
| POST | `/accounting/accounts` | ACCOUNTING_EDIT | Create account |
| GET | `/accounting/accounts/{id}/ledger` | ACCOUNTING_VIEW | Account ledger |
| POST | `/accounting/vouchers` | ACCOUNTING_VIEW | Create voucher |
| GET | `/accounting/vouchers/{id}` | ACCOUNTING_VIEW | Get voucher |
| POST | `/accounting/vouchers/{id}/post` | ACCOUNTING_POST | Post voucher |
| POST | `/accounting/vouchers/{id}/reverse` | ACCOUNTING_POST | Reverse voucher |
| GET | `/accounting/trial-balance` | ACCOUNTING_VIEW | Trial balance |
| GET | `/accounting/balance-sheet` | ACCOUNTING_VIEW | Balance sheet |
| GET | `/accounting/profit-loss` | ACCOUNTING_VIEW | P&L statement |
| GET | `/accounting/fiscal-years` | ACCOUNTING_VIEW | List fiscal years |
| POST | `/accounting/fiscal-years` | ACCOUNTING_EDIT | Create fiscal year |
| POST | `/accounting/fiscal-years/{id}/close` | ACCOUNTING_CLOSE | Close fiscal year |
