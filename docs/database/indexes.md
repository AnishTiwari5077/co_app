# SahakariMS — Database Indexes

## Indexing Strategy

Proper indexes are critical for a financial system that can have millions of rows. We follow these principles:

1. **Index foreign keys** — Always index columns used in JOIN conditions
2. **Partial indexes** — Only index active/non-deleted records where appropriate
3. **Composite indexes** — Match the exact query patterns used in production
4. **Covering indexes** — Include frequently SELECTed columns to avoid table lookups
5. **No over-indexing** — Each index slows down INSERT/UPDATE; only add what is needed

---

## Members Table

```sql
-- Primary lookup patterns
CREATE INDEX idx_members_branch_id
    ON members(branch_id)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_members_member_code
    ON members(member_code)
    WHERE is_deleted = FALSE;

CREATE UNIQUE INDEX idx_members_citizenship_unique
    ON members(citizenship_number)
    WHERE citizenship_number IS NOT NULL AND is_deleted = FALSE;

CREATE INDEX idx_members_phone
    ON members(phone_primary)
    WHERE is_deleted = FALSE;

-- Status-based filtering
CREATE INDEX idx_members_branch_status
    ON members(branch_id, status)
    WHERE is_deleted = FALSE;

-- Full-text search on name (Nepali and English)
CREATE INDEX idx_members_fulltext
    ON members USING GIN (
        to_tsvector('simple',
            COALESCE(first_name, '') || ' ' ||
            COALESCE(last_name, '') || ' ' ||
            COALESCE(first_name_np, '') || ' ' ||
            COALESCE(last_name_np, ''))
    );

-- Trigram search for partial name matching
CREATE INDEX idx_members_name_trgm
    ON members USING GIN (
        (first_name || ' ' || last_name) gin_trgm_ops
    );

-- KYC pending list
CREATE INDEX idx_members_kyc_pending
    ON members(branch_id, created_at)
    WHERE kyc_verified = FALSE AND status = 'Pending' AND is_deleted = FALSE;
```

---

## Saving Accounts

```sql
CREATE INDEX idx_saving_accounts_member_id
    ON saving_accounts(member_id)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_saving_accounts_branch_scheme
    ON saving_accounts(branch_id, scheme_id)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_saving_accounts_status
    ON saving_accounts(branch_id, status)
    WHERE is_deleted = FALSE;

-- Accounts with upcoming FD maturity
CREATE INDEX idx_saving_accounts_maturity
    ON saving_accounts(maturity_date_ad)
    WHERE account_type IN ('FixedDeposit', 'RecurringDeposit')
    AND status = 'Active';
```

---

## Saving Transactions (High Volume)

```sql
-- Most common: transactions for a specific account, newest first
CREATE INDEX idx_saving_txn_account_date
    ON saving_transactions(account_id, transaction_date_ad DESC);

-- Date range queries for reporting
CREATE INDEX idx_saving_txn_branch_date
    ON saving_transactions(branch_id, transaction_date_ad);

-- Receipt number lookup
CREATE UNIQUE INDEX idx_saving_txn_receipt
    ON saving_transactions(receipt_number)
    WHERE receipt_number IS NOT NULL;

-- Collector app: find today's collections by collector
CREATE INDEX idx_saving_txn_collector_date
    ON saving_transactions(collected_by, transaction_date_ad)
    WHERE collected_by IS NOT NULL;
```

---

## Loans

```sql
CREATE INDEX idx_loans_member_id
    ON loans(member_id)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_loans_branch_status
    ON loans(branch_id, status)
    WHERE is_deleted = FALSE;

-- Overdue loans for NPA job
CREATE INDEX idx_loans_overdue
    ON loans(branch_id, maturity_date_ad)
    WHERE status IN ('Active', 'Overdue') AND is_deleted = FALSE;

-- NPA classification
CREATE INDEX idx_loans_npa
    ON loans(branch_id, npa_classification)
    WHERE npa_classification IS NOT NULL AND is_deleted = FALSE;

-- Loans pending approval
CREATE INDEX idx_loans_pending_approval
    ON loans(branch_id, created_at)
    WHERE status IN ('Pending', 'UnderReview') AND is_deleted = FALSE;
```

---

## Loan Schedules

```sql
-- EMI due date lookups (daily job)
CREATE INDEX idx_loan_schedules_due_date
    ON loan_schedules(due_date_ad, status)
    WHERE status IN ('Pending', 'PartiallyPaid', 'Overdue');

-- All schedules for a loan
CREATE INDEX idx_loan_schedules_loan_id
    ON loan_schedules(loan_id, emi_number);

-- Overdue calculation
CREATE INDEX idx_loan_schedules_overdue
    ON loan_schedules(due_date_ad)
    WHERE status != 'Paid';
```

---

## Accounting

```sql
-- Voucher lookup by branch + date
CREATE INDEX idx_vouchers_branch_date
    ON accounting.vouchers(branch_id, voucher_date_ad DESC)
    WHERE is_deleted = FALSE;

-- Voucher by fiscal year
CREATE INDEX idx_vouchers_fiscal_year
    ON accounting.vouchers(fiscal_year_id, voucher_date_ad)
    WHERE is_deleted = FALSE;

-- Voucher entries by account (for ledger)
CREATE INDEX idx_voucher_entries_account
    ON accounting.voucher_entries(account_id, voucher_id);

-- Account by code
CREATE INDEX idx_accounts_code
    ON accounting.accounts(branch_id, account_code)
    WHERE is_active = TRUE;

-- Account type hierarchy
CREATE INDEX idx_accounts_parent
    ON accounting.accounts(parent_id)
    WHERE is_active = TRUE;
```

---

## Users & Authentication

```sql
CREATE UNIQUE INDEX idx_users_username
    ON users(username)
    WHERE is_deleted = FALSE;

CREATE UNIQUE INDEX idx_users_email
    ON users(email)
    WHERE is_deleted = FALSE;

CREATE INDEX idx_users_branch
    ON users(branch_id)
    WHERE is_deleted = FALSE AND status = 'Active';

-- Refresh token lookup
CREATE UNIQUE INDEX idx_refresh_tokens_hash
    ON refresh_tokens(token_hash)
    WHERE is_revoked = FALSE;

CREATE INDEX idx_refresh_tokens_user
    ON refresh_tokens(user_id, expires_at)
    WHERE is_revoked = FALSE;
```

---

## Audit Logs (Partitioned)

```sql
-- Audit logs are partitioned by month; indexes per partition
CREATE INDEX idx_audit_logs_user_date
    ON audit.audit_logs(user_id, created_at DESC);

CREATE INDEX idx_audit_logs_module_action
    ON audit.audit_logs(module, action, created_at DESC);

CREATE INDEX idx_audit_logs_entity
    ON audit.audit_logs(entity_type, entity_id, created_at DESC);

-- Login history
CREATE INDEX idx_login_history_user
    ON audit.login_history(user_id, login_at DESC);

CREATE INDEX idx_login_history_ip
    ON audit.login_history(ip_address, login_at DESC);
```

---

## Notifications

```sql
CREATE INDEX idx_notifications_member_status
    ON notifications(member_id, status, created_at DESC);

CREATE INDEX idx_notifications_pending
    ON notifications(status, channel, created_at)
    WHERE status = 'Pending';
```

---

## Index Maintenance

```sql
-- Check index usage (run monthly)
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan AS scans,
    idx_tup_read AS tuples_read,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;

-- Rebuild bloated indexes (run during maintenance window)
REINDEX INDEX CONCURRENTLY idx_saving_txn_account_date;

-- Check for missing FK indexes
SELECT
    tc.table_name,
    kcu.column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
AND NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = tc.table_name
    AND indexdef LIKE '%' || kcu.column_name || '%'
);
```
