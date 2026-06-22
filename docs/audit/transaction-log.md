# SahakariMS — Audit: Transaction Log

## Overview

The transaction log is an immutable, append-only record of every financial event — deposits, withdrawals, EMI payments, interest postings, and all money movements. It is the definitive source of truth for financial reconciliation and audit.

---

## What Is Logged

| Category | Events |
|----------|--------|
| Savings | Deposit, Withdrawal, Interest Credit, TDS Deduction |
| Loans | Disbursement, EMI Payment, Penalty Charge, Penalty Waiver, Write-off |
| Shares | Purchase, Refund, Transfer, Dividend |
| Fixed Deposit | Creation, Interest Credit, Premature Closure, Maturity |
| Accounting | Voucher Posted, Voucher Reversed, Year Closed |
| Cash | Counter Open, Counter Close, Cash Difference |

---

## Immutability Rules

```
Financial transactions CANNOT be:
  ✗ Updated
  ✗ Deleted
  ✗ Backdated beyond 1 day (requires manager override + audit entry)

Corrections are done by:
  ✅ Reversal voucher (accounting)
  ✅ Credit/debit adjustment transaction
  ✅ Documented exception with manager approval

Audit log entries CANNOT be:
  ✗ Modified by any user role
  ✗ Deleted even by Admin
  ✗ Edited via raw SQL in production
```

---

## Transaction Log Schema

```sql
-- Partitioned by month for performance
CREATE TABLE audit.transaction_log (
    id                  UUID NOT NULL DEFAULT gen_random_uuid(),
    branch_id           UUID NOT NULL,
    branch_code         VARCHAR(10) NOT NULL,
    transaction_type    VARCHAR(50) NOT NULL,  -- SavingDeposit | LoanEmiPayment | etc.
    transaction_id      UUID NOT NULL,          -- FK to source record
    member_id           UUID,
    member_code         VARCHAR(30),
    account_number      VARCHAR(50),
    reference_number    VARCHAR(100),           -- Receipt/voucher number
    debit_amount        NUMERIC(18,4) DEFAULT 0,
    credit_amount       NUMERIC(18,4) DEFAULT 0,
    balance_before      NUMERIC(18,4),
    balance_after       NUMERIC(18,4),
    currency            VARCHAR(3) DEFAULT 'NPR',
    payment_mode        VARCHAR(30),
    narration           TEXT,
    processed_by_user   UUID NOT NULL,
    processed_by_name   VARCHAR(200) NOT NULL,
    ip_address          INET,
    device_id           VARCHAR(200),
    transaction_date_ad DATE NOT NULL,
    transaction_date_bs VARCHAR(10) NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Immutability enforcement
    is_deleted          BOOLEAN GENERATED ALWAYS AS (FALSE) STORED,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Monthly partitions
CREATE TABLE audit.transaction_log_2081_01
    PARTITION OF audit.transaction_log
    FOR VALUES FROM ('2024-04-14') TO ('2024-05-14');

CREATE TABLE audit.transaction_log_2081_02
    PARTITION OF audit.transaction_log
    FOR VALUES FROM ('2024-05-14') TO ('2024-06-14');
-- ... auto-created monthly by pg_partman
```

---

## Transaction Log Queries

### Daily Transaction Reconciliation

```sql
-- Daily summary for reconciliation
SELECT
    tl.transaction_date_bs AS date_bs,
    tl.transaction_type,
    COUNT(*) AS count,
    SUM(tl.debit_amount) AS total_debit,
    SUM(tl.credit_amount) AS total_credit,
    SUM(tl.credit_amount) - SUM(tl.debit_amount) AS net
FROM audit.transaction_log tl
WHERE tl.branch_id = 'branch-uuid'
  AND tl.transaction_date_ad = CURRENT_DATE
GROUP BY tl.transaction_date_bs, tl.transaction_type
ORDER BY tl.transaction_type;
```

### Member Statement Query

```sql
-- Complete member transaction history
SELECT
    tl.transaction_date_bs,
    tl.transaction_type,
    tl.reference_number,
    tl.narration,
    CASE WHEN tl.credit_amount > 0 THEN tl.credit_amount ELSE NULL END AS credit,
    CASE WHEN tl.debit_amount > 0 THEN tl.debit_amount ELSE NULL END AS debit,
    tl.balance_after,
    tl.payment_mode,
    tl.processed_by_name
FROM audit.transaction_log tl
WHERE tl.member_id = 'member-uuid'
  AND tl.transaction_date_ad BETWEEN '2024-04-14' AND '2024-07-30'
ORDER BY tl.created_at;
```

### Cash Reconciliation (End of Day)

```sql
-- Verify cash counter vs transaction log
WITH counter AS (
    SELECT
        cs.cashier_user_id,
        u.full_name AS cashier,
        cs.opening_cash,
        cs.closing_cash,
        cs.total_deposits,
        cs.total_withdrawals
    FROM cash_counter_sessions cs
    JOIN users u ON u.id = cs.cashier_user_id
    WHERE cs.branch_id = 'branch-uuid'
      AND cs.session_date = CURRENT_DATE
),
txn_log AS (
    SELECT
        SUM(tl.credit_amount) AS actual_receipts,
        SUM(tl.debit_amount) AS actual_payments
    FROM audit.transaction_log tl
    WHERE tl.branch_id = 'branch-uuid'
      AND tl.transaction_date_ad = CURRENT_DATE
      AND tl.payment_mode = 'Cash'
)
SELECT
    c.*,
    t.actual_receipts,
    t.actual_payments,
    (c.opening_cash + t.actual_receipts - t.actual_payments) AS expected_closing,
    c.closing_cash - (c.opening_cash + t.actual_receipts - t.actual_payments) AS difference
FROM counter c, txn_log t;
```

---

## Transaction Log API

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/audit/transactions` | AUDIT_VIEW | Query transaction log |
| GET | `/audit/transactions/{memberId}` | REPORTS_VIEW_BASIC | Member transaction history |
| GET | `/audit/transactions/daily-summary` | REPORTS_VIEW_BASIC | Daily summary |
| GET | `/audit/transactions/reconciliation` | AUDIT_VIEW | Reconciliation report |
| GET | `/audit/transactions/export` | REPORTS_EXPORT | Export to Excel/CSV |

---

## Integrity Verification

A nightly job verifies transaction log integrity:

```csharp
[DisableConcurrentExecution(300)]
public class TransactionLogIntegrityJob
{
    public async Task ExecuteAsync()
    {
        // Verify: Sum of all credits = Sum of all debits (by account)
        var imbalanced = await _db.Database.SqlQueryRaw<ImbalancedAccount>(@"
            SELECT account_number,
                   SUM(credit_amount) - SUM(debit_amount) AS discrepancy
            FROM audit.transaction_log
            WHERE transaction_date_ad = CURRENT_DATE - 1
            GROUP BY account_number
            HAVING ABS(SUM(credit_amount) - SUM(debit_amount) - latest_balance) > 0.01
        ").ToListAsync();

        if (imbalanced.Any())
        {
            _logger.LogCritical(
                "Transaction log integrity violation: {Count} accounts with discrepancies",
                imbalanced.Count);
            await _alertService.SendCriticalAlertAsync(imbalanced);
        }
    }
}
```
