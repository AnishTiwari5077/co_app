# SahakariMS — Database Design

## Design Principles

| Principle | Implementation |
|-----------|---------------|
| **ACID Compliance** | All financial operations in explicit transactions |
| **UUID Primary Keys** | `gen_random_uuid()` — prevents sequential ID attacks |
| **Soft Delete** | `is_deleted`, `deleted_at`, `deleted_by` on every table |
| **Audit Columns** | `created_at`, `updated_at`, `created_by`, `updated_by` |
| **Monetary Precision** | `NUMERIC(18,4)` for all amounts — never FLOAT or REAL |
| **Dual Calendar** | `date_ad DATE` + `date_bs VARCHAR(10)` where applicable |
| **Branch Isolation** | `branch_id UUID FK` on all multi-branch entities |
| **Row-Level Security** | PostgreSQL RLS for branch data isolation |
| **Immutable Transactions** | Financial transactions are never updated, only reversed |
| **Referential Integrity** | All FKs declared, ON DELETE RESTRICT |

---

## Database Schemas

```
public          ← Core cooperative entities
accounting      ← Chart of accounts, vouchers, ledger
audit           ← All audit log tables
hr              ← Employee and payroll management
inventory       ← Inventory management (optional)
```

---

## Core Entity Groups

### Identity & Access

| Table | Purpose |
|-------|---------|
| `branches` | Cooperative branch offices |
| `users` | System users (employees) |
| `roles` | User roles |
| `permissions` | Granular permissions |
| `user_roles` | User ↔ Role mapping |
| `role_permissions` | Role ↔ Permission mapping |
| `refresh_tokens` | JWT refresh token store |
| `user_devices` | Registered devices per user |
| `login_history` | Login audit trail |

### Members

| Table | Purpose |
|-------|---------|
| `members` | Core member profile |
| `member_family_details` | Family information |
| `member_nominees` | Nominee details |
| `member_documents` | KYC and other documents |
| `member_kyc` | KYC verification status |

### Shares

| Table | Purpose |
|-------|---------|
| `share_accounts` | Member share account |
| `share_transactions` | Purchase, refund, transfer |
| `share_certificates` | Issued certificates |
| `dividends` | Dividend declarations |
| `dividend_payments` | Per-member dividend payments |

### Savings & Deposits

| Table | Purpose |
|-------|---------|
| `saving_schemes` | Scheme definitions (Regular, RD, FD, etc.) |
| `saving_accounts` | Member savings accounts |
| `saving_transactions` | Deposit and withdrawal records |
| `recurring_deposits` | RD installment schedule |
| `fixed_deposits` | FD details and terms |
| `fd_interest_payments` | FD interest payment history |
| `interest_postings` | Batch interest posting records |

### Loans

| Table | Purpose |
|-------|---------|
| `loan_products` | Loan product definitions |
| `loans` | Loan master record |
| `loan_schedules` | EMI schedule table |
| `loan_payments` | Payment records |
| `loan_guarantors` | Guarantor relationships |
| `collaterals` | Collateral registrations |
| `loan_documents` | Loan-related documents |
| `npa_classifications` | NPA history |
| `loan_write_offs` | Write-off records |

### Accounting

| Table | Purpose |
|-------|---------|
| `accounting.accounts` | Chart of accounts |
| `accounting.fiscal_years` | Fiscal year definitions |
| `accounting.vouchers` | Voucher header |
| `accounting.voucher_entries` | Debit/credit lines |
| `accounting.general_ledger` | Materialized ledger view |

### Cash Management

| Table | Purpose |
|-------|---------|
| `cash_counter_sessions` | Cashier opening/closing sessions |
| `cash_transactions` | Counter-level cash movements |
| `vault_transfers` | Vault ↔ counter transfers |

### System

| Table | Purpose |
|-------|---------|
| `notifications` | Notification queue and delivery status |
| `sms_logs` | SMS delivery log |
| `settings` | Application settings key-value |
| `audit.audit_logs` | Complete activity audit |
| `audit.transaction_audit` | Financial transaction audit |

---

## Base Entity Template

Every table in SahakariMS includes these standard columns:

```sql
-- Applied to every table
id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
branch_id   UUID        REFERENCES branches(id),  -- on multi-branch entities
is_deleted  BOOLEAN     NOT NULL DEFAULT FALSE,
deleted_at  TIMESTAMPTZ,
deleted_by  UUID        REFERENCES users(id),
created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
created_by  UUID        NOT NULL REFERENCES users(id),
updated_by  UUID        NOT NULL REFERENCES users(id)
```

---

## Key Table Designs

### members

```sql
CREATE TABLE members (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID NOT NULL REFERENCES branches(id),
    member_code         VARCHAR(20) NOT NULL UNIQUE,
    first_name          VARCHAR(100) NOT NULL,
    middle_name         VARCHAR(100),
    last_name           VARCHAR(100) NOT NULL,
    first_name_np       VARCHAR(100),              -- Nepali name
    last_name_np        VARCHAR(100),
    gender              VARCHAR(10) NOT NULL CHECK (gender IN ('Male','Female','Other')),
    date_of_birth_ad    DATE NOT NULL,
    date_of_birth_bs    VARCHAR(10) NOT NULL,       -- e.g. "2035-05-15"
    citizenship_number  VARCHAR(50) UNIQUE,
    pan_number          VARCHAR(20),
    phone_primary       VARCHAR(15) NOT NULL,
    phone_secondary     VARCHAR(15),
    email               VARCHAR(200),
    address_province    VARCHAR(100),
    address_district    VARCHAR(100) NOT NULL,
    address_municipality VARCHAR(100) NOT NULL,
    address_ward        VARCHAR(10),
    address_tole        VARCHAR(200),
    photo_url           TEXT,
    signature_url       TEXT,
    fingerprint_data    TEXT,                      -- Encrypted biometric template
    occupation          VARCHAR(100),
    education           VARCHAR(50),
    membership_date_ad  DATE,
    membership_date_bs  VARCHAR(10),
    status              VARCHAR(20) NOT NULL DEFAULT 'Pending'
                        CHECK (status IN ('Pending','Active','Inactive','Suspended','Closed')),
    kyc_verified        BOOLEAN NOT NULL DEFAULT FALSE,
    kyc_verified_at     TIMESTAMPTZ,
    kyc_verified_by     UUID REFERENCES users(id),
    remarks             TEXT,
    -- Audit columns
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    deleted_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID NOT NULL REFERENCES users(id),
    updated_by          UUID NOT NULL REFERENCES users(id)
);
```

### loans

```sql
CREATE TABLE loans (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID NOT NULL REFERENCES branches(id),
    loan_number         VARCHAR(30) NOT NULL UNIQUE,
    member_id           UUID NOT NULL REFERENCES members(id),
    loan_product_id     UUID NOT NULL REFERENCES loan_products(id),
    applied_amount      NUMERIC(18,4) NOT NULL,
    approved_amount     NUMERIC(18,4),
    disbursed_amount    NUMERIC(18,4),
    outstanding_balance NUMERIC(18,4) NOT NULL DEFAULT 0,
    interest_rate       NUMERIC(6,4) NOT NULL,       -- % per annum
    interest_method     VARCHAR(20) NOT NULL
                        CHECK (interest_method IN ('FlatRate','ReducingBalance')),
    tenure_months       INTEGER NOT NULL,
    emi_amount          NUMERIC(18,4),
    disbursement_date_ad DATE,
    disbursement_date_bs VARCHAR(10),
    first_emi_date_ad   DATE,
    maturity_date_ad    DATE,
    loan_purpose        TEXT,
    status              VARCHAR(30) NOT NULL DEFAULT 'Pending'
                        CHECK (status IN (
                            'Pending','UnderReview','Approved','Rejected',
                            'Disbursed','Active','Overdue','NPA',
                            'Rescheduled','WrittenOff','Closed'
                        )),
    penalty_rate        NUMERIC(6,4) NOT NULL DEFAULT 0,
    npa_classification  VARCHAR(20)
                        CHECK (npa_classification IN (
                            'Standard','Watchlist','Substandard','Doubtful','Loss'
                        )),
    total_paid_principal NUMERIC(18,4) NOT NULL DEFAULT 0,
    total_paid_interest  NUMERIC(18,4) NOT NULL DEFAULT 0,
    total_paid_penalty   NUMERIC(18,4) NOT NULL DEFAULT 0,
    disbursement_account_id UUID REFERENCES saving_accounts(id),
    approved_by         UUID REFERENCES users(id),
    disbursed_by        UUID REFERENCES users(id),
    closure_date_ad     DATE,
    closure_reason      TEXT,
    remarks             TEXT,
    -- Audit columns
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    deleted_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID NOT NULL REFERENCES users(id),
    updated_by          UUID NOT NULL REFERENCES users(id)
);
```

### saving_accounts

```sql
CREATE TABLE saving_accounts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID NOT NULL REFERENCES branches(id),
    account_number      VARCHAR(20) NOT NULL UNIQUE,
    member_id           UUID NOT NULL REFERENCES members(id),
    scheme_id           UUID NOT NULL REFERENCES saving_schemes(id),
    account_type        VARCHAR(30) NOT NULL,
    current_balance     NUMERIC(18,4) NOT NULL DEFAULT 0,
    accrued_interest    NUMERIC(18,4) NOT NULL DEFAULT 0,
    interest_rate       NUMERIC(6,4) NOT NULL,
    open_date_ad        DATE NOT NULL,
    open_date_bs        VARCHAR(10) NOT NULL,
    close_date_ad       DATE,
    maturity_date_ad    DATE,                    -- For FD/RD
    status              VARCHAR(20) NOT NULL DEFAULT 'Active'
                        CHECK (status IN ('Active','Frozen','Dormant','Closed')),
    is_joint_account    BOOLEAN NOT NULL DEFAULT FALSE,
    nominee_id          UUID REFERENCES member_nominees(id),
    last_transaction_date DATE,
    remarks             TEXT,
    -- Audit columns
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    deleted_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID NOT NULL REFERENCES users(id),
    updated_by          UUID NOT NULL REFERENCES users(id)
);
```

### accounting.vouchers

```sql
CREATE TABLE accounting.vouchers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID NOT NULL REFERENCES branches(id),
    fiscal_year_id      UUID NOT NULL REFERENCES accounting.fiscal_years(id),
    voucher_number      VARCHAR(30) NOT NULL,
    voucher_type        VARCHAR(20) NOT NULL
                        CHECK (voucher_type IN (
                            'Journal','Payment','Receipt','Contra','Opening'
                        )),
    voucher_date_ad     DATE NOT NULL,
    voucher_date_bs     VARCHAR(10) NOT NULL,
    narration           TEXT NOT NULL,
    total_amount        NUMERIC(18,4) NOT NULL,
    reference_type      VARCHAR(30),             -- 'Loan','Savings','Share', etc.
    reference_id        UUID,                    -- FK to source transaction
    is_posted           BOOLEAN NOT NULL DEFAULT FALSE,
    posted_at           TIMESTAMPTZ,
    posted_by           UUID REFERENCES users(id),
    is_reversed         BOOLEAN NOT NULL DEFAULT FALSE,
    reversed_by_voucher UUID REFERENCES accounting.vouchers(id),
    -- Audit columns
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    deleted_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID NOT NULL REFERENCES users(id),
    updated_by          UUID NOT NULL REFERENCES users(id),
    UNIQUE (branch_id, fiscal_year_id, voucher_number)
);

CREATE TABLE accounting.voucher_entries (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_id          UUID NOT NULL REFERENCES accounting.vouchers(id) ON DELETE CASCADE,
    account_id          UUID NOT NULL REFERENCES accounting.accounts(id),
    entry_type          VARCHAR(6) NOT NULL CHECK (entry_type IN ('Debit','Credit')),
    amount              NUMERIC(18,4) NOT NULL CHECK (amount > 0),
    narration           TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID NOT NULL REFERENCES users(id)
);
```

---

## Triggers

### Auto Update `updated_at`

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Applied to every table
CREATE TRIGGER trg_members_updated_at
    BEFORE UPDATE ON members
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### Financial Transaction Audit Trigger

```sql
CREATE OR REPLACE FUNCTION audit_saving_transactions()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit.transaction_audit (
        table_name, operation, record_id, old_data, new_data,
        changed_by, changed_at
    ) VALUES (
        'saving_transactions', TG_OP, NEW.id,
        to_jsonb(OLD), to_jsonb(NEW),
        NEW.created_by, NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## Indexing Strategy

```sql
-- Members
CREATE INDEX idx_members_branch_id    ON members(branch_id);
CREATE INDEX idx_members_phone        ON members(phone_primary);
CREATE INDEX idx_members_citizenship  ON members(citizenship_number);
CREATE INDEX idx_members_status       ON members(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_members_search       ON members USING GIN (
    to_tsvector('simple', first_name || ' ' || last_name));

-- Loans
CREATE INDEX idx_loans_member_id      ON loans(member_id);
CREATE INDEX idx_loans_branch_status  ON loans(branch_id, status);
CREATE INDEX idx_loans_overdue        ON loans(maturity_date_ad) WHERE status = 'Active';

-- Saving Transactions (high volume — partition by month)
CREATE INDEX idx_saving_txn_account   ON saving_transactions(account_id, created_at DESC);
CREATE INDEX idx_saving_txn_date      ON saving_transactions(transaction_date_ad);

-- Audit logs (partition by month)
CREATE INDEX idx_audit_user_action    ON audit.audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_module         ON audit.audit_logs(module, created_at DESC);
```

---

## Partitioning

High-volume tables are partitioned by month for performance:

```sql
-- Audit logs partitioned by month
CREATE TABLE audit.audit_logs (
    id          UUID NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL,
    ...
) PARTITION BY RANGE (created_at);

CREATE TABLE audit.audit_logs_2081_01
    PARTITION OF audit.audit_logs
    FOR VALUES FROM ('2081-01-01') TO ('2081-02-01');  -- Nepali BS month
```

---

## Row-Level Security (Branch Isolation)

```sql
-- Enable RLS on multi-branch tables
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE saving_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;

-- Policy: users see only their branch's data
-- (branch_id stored in PostgreSQL session variable by app)
CREATE POLICY branch_isolation ON members
    USING (
        branch_id = current_setting('app.current_branch_id')::UUID
        OR current_setting('app.is_head_office')::BOOLEAN = TRUE
    );
```

---

## Data Migration Strategy

For new installations migrating from legacy systems:

1. **Extract** — Export CSV/Excel from legacy system
2. **Transform** — Map legacy fields to SahakariMS schema, validate, clean
3. **Validate** — Run business rule checks (balance reconciliation)
4. **Load** — Import via migration scripts with transaction rollback on error
5. **Verify** — Compare totals: opening balances, member count, loan outstanding
6. **Parallel Run** — Run both systems in parallel for 1 month
7. **Cut-over** — Freeze legacy system, finalize import, go live
