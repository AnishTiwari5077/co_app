# SahakariMS — Full Table Specifications (DDL)

All tables use PostgreSQL 16 syntax. Standard audit columns are omitted from each table for brevity but are always present (see `database-design.md`).

---

## Schema Setup

```sql
CREATE SCHEMA IF NOT EXISTS accounting;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS hr;
CREATE SCHEMA IF NOT EXISTS inventory;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- for fuzzy text search
```

---

## public.branches

```sql
CREATE TABLE branches (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_code     VARCHAR(10) NOT NULL UNIQUE,
    branch_name     VARCHAR(200) NOT NULL,
    branch_name_np  VARCHAR(200),
    address         TEXT,
    district        VARCHAR(100),
    municipality    VARCHAR(100),
    phone           VARCHAR(20),
    email           VARCHAR(200),
    manager_id      UUID,                    -- populated after user creation
    is_head_office  BOOLEAN     NOT NULL DEFAULT FALSE,
    status          VARCHAR(20) NOT NULL DEFAULT 'Active'
                    CHECK (status IN ('Active','Inactive','Closed')),
    established_date DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    updated_by      UUID
);
```

---

## public.users

```sql
CREATE TABLE users (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID        REFERENCES branches(id),
    employee_code   VARCHAR(20) UNIQUE,
    full_name       VARCHAR(200) NOT NULL,
    email           VARCHAR(200) NOT NULL UNIQUE,
    username        VARCHAR(100) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    phone           VARCHAR(15),
    photo_url       TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'Active'
                    CHECK (status IN ('Active','Inactive','Locked')),
    is_two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    two_factor_secret     VARCHAR(100),
    failed_login_count    INTEGER NOT NULL DEFAULT 0,
    locked_until          TIMESTAMPTZ,
    last_login_at         TIMESTAMPTZ,
    password_changed_at   TIMESTAMPTZ,
    must_change_password  BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at      TIMESTAMPTZ,
    deleted_by      UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    updated_by      UUID
);
```

---

## public.roles

```sql
CREATE TABLE roles (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    role_code       VARCHAR(50) NOT NULL UNIQUE,
    role_name       VARCHAR(100) NOT NULL,
    description     TEXT,
    is_system_role  BOOLEAN     NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    updated_by      UUID
);

INSERT INTO roles (role_code, role_name, is_system_role) VALUES
    ('ADMIN',        'Administrator', TRUE),
    ('MANAGER',      'Manager',       TRUE),
    ('ACCOUNTANT',   'Accountant',    TRUE),
    ('CASHIER',      'Cashier',       TRUE),
    ('LOAN_OFFICER', 'Loan Officer',  TRUE),
    ('COLLECTOR',    'Collector',     TRUE),
    ('AUDITOR',      'Auditor',       TRUE),
    ('MEMBER',       'Member',        TRUE);
```

---

## public.permissions

```sql
CREATE TABLE permissions (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_code VARCHAR(100) NOT NULL UNIQUE,
    module          VARCHAR(50) NOT NULL,
    action          VARCHAR(50) NOT NULL,
    description     TEXT,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE
);

-- Sample permissions
INSERT INTO permissions (permission_code, module, action, description) VALUES
    ('MEMBERS_VIEW',     'MEMBERS',    'VIEW',    'View member profiles'),
    ('MEMBERS_CREATE',   'MEMBERS',    'CREATE',  'Register new members'),
    ('MEMBERS_EDIT',     'MEMBERS',    'EDIT',    'Edit member information'),
    ('MEMBERS_APPROVE',  'MEMBERS',    'APPROVE', 'Approve pending memberships'),
    ('SAVINGS_DEPOSIT',  'SAVINGS',    'DEPOSIT', 'Perform cash deposits'),
    ('SAVINGS_WITHDRAW', 'SAVINGS',    'WITHDRAW','Perform cash withdrawals'),
    ('LOANS_VIEW',       'LOANS',      'VIEW',    'View loan information'),
    ('LOANS_APPLY',      'LOANS',      'APPLY',   'Submit loan applications'),
    ('LOANS_APPROVE',    'LOANS',      'APPROVE', 'Approve loan applications'),
    ('LOANS_DISBURSE',   'LOANS',      'DISBURSE','Disburse approved loans'),
    ('ACCOUNTING_POST',  'ACCOUNTING', 'POST',    'Post journal vouchers'),
    ('REPORTS_EXPORT',   'REPORTS',    'EXPORT',  'Export financial reports'),
    ('USERS_CREATE',     'USERS',      'CREATE',  'Create system users'),
    ('AUDIT_VIEW',       'AUDIT',      'VIEW',    'View audit logs');
```

---

## public.user_roles

```sql
CREATE TABLE user_roles (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id     UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id),
    PRIMARY KEY (user_id, role_id)
);
```

---

## public.role_permissions

```sql
CREATE TABLE role_permissions (
    role_id       UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    granted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by    UUID REFERENCES users(id),
    PRIMARY KEY (role_id, permission_id)
);
```

---

## public.refresh_tokens

```sql
CREATE TABLE refresh_tokens (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash      VARCHAR(255) NOT NULL UNIQUE,
    device_id       VARCHAR(100),
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    expires_at      TIMESTAMPTZ NOT NULL,
    is_revoked      BOOLEAN     NOT NULL DEFAULT FALSE,
    revoked_at      TIMESTAMPTZ,
    revoked_reason  VARCHAR(100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## public.members

```sql
CREATE TABLE members (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id               UUID        NOT NULL REFERENCES branches(id),
    member_code             VARCHAR(20) NOT NULL UNIQUE,
    first_name              VARCHAR(100) NOT NULL,
    middle_name             VARCHAR(100),
    last_name               VARCHAR(100) NOT NULL,
    first_name_np           VARCHAR(100),
    middle_name_np          VARCHAR(100),
    last_name_np            VARCHAR(100),
    gender                  VARCHAR(10) NOT NULL CHECK (gender IN ('Male','Female','Other')),
    date_of_birth_ad        DATE        NOT NULL,
    date_of_birth_bs        VARCHAR(10) NOT NULL,
    blood_group             VARCHAR(5),
    citizenship_number      VARCHAR(50),
    citizenship_issued_date DATE,
    citizenship_issued_district VARCHAR(100),
    pan_number              VARCHAR(20),
    passport_number         VARCHAR(20),
    voter_id                VARCHAR(30),
    phone_primary           VARCHAR(15) NOT NULL,
    phone_secondary         VARCHAR(15),
    email                   VARCHAR(200),
    address_province        VARCHAR(100),
    address_district        VARCHAR(100) NOT NULL,
    address_municipality    VARCHAR(100) NOT NULL,
    address_ward            VARCHAR(5),
    address_tole            VARCHAR(200),
    permanent_address       TEXT,
    photo_url               TEXT,
    signature_url           TEXT,
    fingerprint_data        TEXT,           -- AES-256 encrypted biometric template
    occupation              VARCHAR(100),
    employer_name           VARCHAR(200),
    monthly_income          NUMERIC(18,4),
    education               VARCHAR(50),
    marital_status          VARCHAR(20)     CHECK (marital_status IN ('Single','Married','Divorced','Widowed')),
    membership_date_ad      DATE,
    membership_date_bs      VARCHAR(10),
    membership_fee          NUMERIC(18,4)   NOT NULL DEFAULT 0,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'Pending'
                            CHECK (status IN ('Pending','Active','Inactive','Suspended','Closed')),
    kyc_verified            BOOLEAN         NOT NULL DEFAULT FALSE,
    kyc_verified_at         TIMESTAMPTZ,
    kyc_verified_by         UUID            REFERENCES users(id),
    approved_by             UUID            REFERENCES users(id),
    approved_at             TIMESTAMPTZ,
    closed_at               TIMESTAMPTZ,
    close_reason            TEXT,
    remarks                 TEXT,
    is_deleted              BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at              TIMESTAMPTZ,
    deleted_by              UUID            REFERENCES users(id),
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NOT NULL REFERENCES users(id),
    updated_by              UUID            NOT NULL REFERENCES users(id)
);
```

---

## public.member_nominees

```sql
CREATE TABLE member_nominees (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id       UUID        NOT NULL REFERENCES members(id),
    full_name       VARCHAR(200) NOT NULL,
    relation        VARCHAR(50) NOT NULL,
    date_of_birth_ad DATE,
    citizenship_number VARCHAR(50),
    phone           VARCHAR(15),
    address         TEXT,
    share_percent   NUMERIC(5,2) NOT NULL DEFAULT 100,
    is_primary      BOOLEAN     NOT NULL DEFAULT TRUE,
    photo_url       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID        NOT NULL REFERENCES users(id),
    updated_by      UUID        NOT NULL REFERENCES users(id)
);
```

---

## public.member_documents

```sql
CREATE TABLE member_documents (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id       UUID        NOT NULL REFERENCES members(id),
    doc_type        VARCHAR(50) NOT NULL
                    CHECK (doc_type IN ('Citizenship','PAN','Passport','VoterID','Photo','Other')),
    doc_number      VARCHAR(100),
    file_url        TEXT        NOT NULL,
    file_name       VARCHAR(255),
    file_size_bytes INTEGER,
    mime_type       VARCHAR(100),
    issued_date     DATE,
    expiry_date     DATE,
    is_verified     BOOLEAN     NOT NULL DEFAULT FALSE,
    verified_by     UUID        REFERENCES users(id),
    verified_at     TIMESTAMPTZ,
    remarks         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID        NOT NULL REFERENCES users(id)
);
```

---

## public.share_accounts

```sql
CREATE TABLE share_accounts (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID        NOT NULL REFERENCES branches(id),
    member_id       UUID        NOT NULL REFERENCES members(id) UNIQUE,
    shares_held     INTEGER     NOT NULL DEFAULT 0,
    share_value     NUMERIC(18,4) NOT NULL DEFAULT 0,  -- per share
    total_value     NUMERIC(18,4) NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'Active'
                    CHECK (status IN ('Active','Closed')),
    is_deleted      BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at      TIMESTAMPTZ,
    deleted_by      UUID        REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID        NOT NULL REFERENCES users(id),
    updated_by      UUID        NOT NULL REFERENCES users(id)
);
```

---

## public.saving_schemes

```sql
CREATE TABLE saving_schemes (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID        REFERENCES branches(id),  -- NULL = global
    scheme_code         VARCHAR(20) NOT NULL UNIQUE,
    scheme_name         VARCHAR(200) NOT NULL,
    scheme_name_np      VARCHAR(200),
    account_type        VARCHAR(30) NOT NULL
                        CHECK (account_type IN (
                            'Regular','Child','Women','Daily','Monthly',
                            'RecurringDeposit','FixedDeposit','Special'
                        )),
    interest_rate       NUMERIC(6,4) NOT NULL DEFAULT 0,
    min_balance         NUMERIC(18,4) NOT NULL DEFAULT 0,
    max_balance         NUMERIC(18,4),
    min_deposit         NUMERIC(18,4) NOT NULL DEFAULT 0,
    withdrawal_allowed  BOOLEAN     NOT NULL DEFAULT TRUE,
    interest_frequency  VARCHAR(20) NOT NULL DEFAULT 'Monthly'
                        CHECK (interest_frequency IN ('Daily','Monthly','Quarterly','Yearly','OnMaturity')),
    tenure_months       INTEGER,            -- For RD/FD
    penalty_rate        NUMERIC(6,4) NOT NULL DEFAULT 0,
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID        NOT NULL REFERENCES users(id),
    updated_by          UUID        NOT NULL REFERENCES users(id)
);
```

---

## public.saving_accounts

```sql
CREATE TABLE saving_accounts (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID        NOT NULL REFERENCES branches(id),
    account_number      VARCHAR(20) NOT NULL UNIQUE,
    member_id           UUID        NOT NULL REFERENCES members(id),
    scheme_id           UUID        NOT NULL REFERENCES saving_schemes(id),
    account_type        VARCHAR(30) NOT NULL,
    current_balance     NUMERIC(18,4) NOT NULL DEFAULT 0,
    accrued_interest    NUMERIC(18,4) NOT NULL DEFAULT 0,
    interest_rate       NUMERIC(6,4) NOT NULL,
    open_date_ad        DATE        NOT NULL,
    open_date_bs        VARCHAR(10) NOT NULL,
    close_date_ad       DATE,
    maturity_date_ad    DATE,
    maturity_amount     NUMERIC(18,4),
    status              VARCHAR(20) NOT NULL DEFAULT 'Active'
                        CHECK (status IN ('Active','Frozen','Dormant','Closed')),
    freeze_reason       TEXT,
    nominee_id          UUID        REFERENCES member_nominees(id),
    last_transaction_at TIMESTAMPTZ,
    last_interest_posted_at TIMESTAMPTZ,
    remarks             TEXT,
    is_deleted          BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    deleted_by          UUID        REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID        NOT NULL REFERENCES users(id),
    updated_by          UUID        NOT NULL REFERENCES users(id)
);
```

---

## public.saving_transactions

```sql
CREATE TABLE saving_transactions (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID        NOT NULL REFERENCES branches(id),
    account_id          UUID        NOT NULL REFERENCES saving_accounts(id),
    txn_type            VARCHAR(30) NOT NULL
                        CHECK (txn_type IN (
                            'Deposit','Withdrawal','Interest','PenaltyDebit',
                            'Transfer','AccountClose','Opening'
                        )),
    txn_mode            VARCHAR(20) NOT NULL DEFAULT 'Cash'
                        CHECK (txn_mode IN ('Cash','Cheque','Transfer','Online')),
    amount              NUMERIC(18,4) NOT NULL CHECK (amount > 0),
    balance_before      NUMERIC(18,4) NOT NULL,
    balance_after       NUMERIC(18,4) NOT NULL,
    transaction_date_ad DATE        NOT NULL,
    transaction_date_bs VARCHAR(10) NOT NULL,
    receipt_number      VARCHAR(30) UNIQUE,
    cheque_number       VARCHAR(30),
    voucher_id          UUID        REFERENCES accounting.vouchers(id),
    narration           TEXT,
    collected_by        UUID        REFERENCES users(id),  -- for collector app
    gps_lat             NUMERIC(10,7),  -- collector GPS
    gps_lng             NUMERIC(10,7),
    is_reversed         BOOLEAN     NOT NULL DEFAULT FALSE,
    reversed_by_txn_id  UUID        REFERENCES saving_transactions(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID        NOT NULL REFERENCES users(id)
);
```

---

## public.loan_products

```sql
CREATE TABLE loan_products (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID        REFERENCES branches(id),
    product_code        VARCHAR(20) NOT NULL UNIQUE,
    product_name        VARCHAR(200) NOT NULL,
    loan_type           VARCHAR(30) NOT NULL
                        CHECK (loan_type IN (
                            'Personal','Agriculture','Business','Gold',
                            'Vehicle','Education','Micro','Others'
                        )),
    min_amount          NUMERIC(18,4) NOT NULL,
    max_amount          NUMERIC(18,4) NOT NULL,
    min_tenure_months   INTEGER     NOT NULL,
    max_tenure_months   INTEGER     NOT NULL,
    interest_rate       NUMERIC(6,4) NOT NULL,
    interest_method     VARCHAR(20) NOT NULL DEFAULT 'ReducingBalance'
                        CHECK (interest_method IN ('FlatRate','ReducingBalance')),
    penalty_rate        NUMERIC(6,4) NOT NULL DEFAULT 0,
    processing_fee_pct  NUMERIC(5,2) NOT NULL DEFAULT 0,
    requires_guarantor  BOOLEAN     NOT NULL DEFAULT TRUE,
    requires_collateral BOOLEAN     NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID        NOT NULL REFERENCES users(id),
    updated_by          UUID        NOT NULL REFERENCES users(id)
);
```

---

## public.loans

```sql
CREATE TABLE loans (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id               UUID        NOT NULL REFERENCES branches(id),
    loan_number             VARCHAR(30) NOT NULL UNIQUE,
    member_id               UUID        NOT NULL REFERENCES members(id),
    loan_product_id         UUID        NOT NULL REFERENCES loan_products(id),
    applied_amount          NUMERIC(18,4) NOT NULL,
    approved_amount         NUMERIC(18,4),
    disbursed_amount        NUMERIC(18,4),
    outstanding_balance     NUMERIC(18,4) NOT NULL DEFAULT 0,
    interest_rate           NUMERIC(6,4) NOT NULL,
    interest_method         VARCHAR(20) NOT NULL,
    tenure_months           INTEGER     NOT NULL,
    emi_amount              NUMERIC(18,4),
    disbursement_date_ad    DATE,
    disbursement_date_bs    VARCHAR(10),
    first_emi_date_ad       DATE,
    maturity_date_ad        DATE,
    loan_purpose            TEXT,
    disbursement_account_id UUID        REFERENCES saving_accounts(id),
    status                  VARCHAR(30) NOT NULL DEFAULT 'Pending'
                            CHECK (status IN (
                                'Pending','UnderReview','Approved','Rejected',
                                'Disbursed','Active','Overdue','NPA',
                                'Rescheduled','WrittenOff','Closed'
                            )),
    penalty_rate            NUMERIC(6,4) NOT NULL DEFAULT 0,
    npa_classification      VARCHAR(20)
                            CHECK (npa_classification IN (
                                'Standard','Watchlist','Substandard','Doubtful','Loss'
                            )),
    npa_classified_at       TIMESTAMPTZ,
    total_paid_principal    NUMERIC(18,4) NOT NULL DEFAULT 0,
    total_paid_interest     NUMERIC(18,4) NOT NULL DEFAULT 0,
    total_paid_penalty      NUMERIC(18,4) NOT NULL DEFAULT 0,
    processing_fee          NUMERIC(18,4) NOT NULL DEFAULT 0,
    approved_by             UUID        REFERENCES users(id),
    approved_at             TIMESTAMPTZ,
    rejection_reason        TEXT,
    disbursed_by            UUID        REFERENCES users(id),
    closure_date_ad         DATE,
    closure_reason          TEXT,
    remarks                 TEXT,
    is_deleted              BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at              TIMESTAMPTZ,
    deleted_by              UUID        REFERENCES users(id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID        NOT NULL REFERENCES users(id),
    updated_by              UUID        NOT NULL REFERENCES users(id)
);
```

---

## public.loan_schedules

```sql
CREATE TABLE loan_schedules (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id             UUID        NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    emi_number          INTEGER     NOT NULL,
    due_date_ad         DATE        NOT NULL,
    due_date_bs         VARCHAR(10) NOT NULL,
    principal_amount    NUMERIC(18,4) NOT NULL,
    interest_amount     NUMERIC(18,4) NOT NULL,
    emi_amount          NUMERIC(18,4) NOT NULL,
    opening_balance     NUMERIC(18,4) NOT NULL,
    closing_balance     NUMERIC(18,4) NOT NULL,
    paid_amount         NUMERIC(18,4) NOT NULL DEFAULT 0,
    paid_principal      NUMERIC(18,4) NOT NULL DEFAULT 0,
    paid_interest       NUMERIC(18,4) NOT NULL DEFAULT 0,
    paid_penalty        NUMERIC(18,4) NOT NULL DEFAULT 0,
    paid_date_ad        DATE,
    status              VARCHAR(20) NOT NULL DEFAULT 'Pending'
                        CHECK (status IN ('Pending','Paid','PartiallyPaid','Overdue','Waived')),
    overdue_days        INTEGER     NOT NULL DEFAULT 0,
    UNIQUE (loan_id, emi_number)
);
```

---

## public.loan_payments

```sql
CREATE TABLE loan_payments (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID        NOT NULL REFERENCES branches(id),
    loan_id             UUID        NOT NULL REFERENCES loans(id),
    schedule_id         UUID        REFERENCES loan_schedules(id),
    receipt_number      VARCHAR(30) NOT NULL UNIQUE,
    payment_date_ad     DATE        NOT NULL,
    payment_date_bs     VARCHAR(10) NOT NULL,
    payment_mode        VARCHAR(20) NOT NULL DEFAULT 'Cash',
    total_amount        NUMERIC(18,4) NOT NULL,
    principal_amount    NUMERIC(18,4) NOT NULL,
    interest_amount     NUMERIC(18,4) NOT NULL,
    penalty_amount      NUMERIC(18,4) NOT NULL DEFAULT 0,
    outstanding_after   NUMERIC(18,4) NOT NULL,
    voucher_id          UUID        REFERENCES accounting.vouchers(id),
    narration           TEXT,
    is_reversed         BOOLEAN     NOT NULL DEFAULT FALSE,
    reversed_at         TIMESTAMPTZ,
    reversed_by         UUID        REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID        NOT NULL REFERENCES users(id)
);
```

---

## accounting.accounts

```sql
CREATE TABLE accounting.accounts (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID        NOT NULL REFERENCES branches(id),
    fiscal_year_id  UUID        REFERENCES accounting.fiscal_years(id),
    parent_id       UUID        REFERENCES accounting.accounts(id),
    account_code    VARCHAR(20) NOT NULL,
    account_name    VARCHAR(200) NOT NULL,
    account_name_np VARCHAR(200),
    account_type    VARCHAR(20) NOT NULL
                    CHECK (account_type IN ('Asset','Liability','Equity','Revenue','Expense')),
    account_level   INTEGER     NOT NULL DEFAULT 1 CHECK (account_level BETWEEN 1 AND 5),
    is_leaf         BOOLEAN     NOT NULL DEFAULT TRUE,
    is_system       BOOLEAN     NOT NULL DEFAULT FALSE,
    opening_debit   NUMERIC(18,4) NOT NULL DEFAULT 0,
    opening_credit  NUMERIC(18,4) NOT NULL DEFAULT 0,
    current_debit   NUMERIC(18,4) NOT NULL DEFAULT 0,
    current_credit  NUMERIC(18,4) NOT NULL DEFAULT 0,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID        NOT NULL REFERENCES users(id),
    updated_by      UUID        NOT NULL REFERENCES users(id),
    UNIQUE (branch_id, account_code)
);
```

---

## accounting.fiscal_years

```sql
CREATE TABLE accounting.fiscal_years (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID        NOT NULL REFERENCES branches(id),
    year_name_bs    VARCHAR(20) NOT NULL,   -- e.g. "2081/82"
    year_name_ad    VARCHAR(20),            -- e.g. "2024/25"
    start_date_ad   DATE        NOT NULL,
    end_date_ad     DATE        NOT NULL,
    is_current      BOOLEAN     NOT NULL DEFAULT FALSE,
    is_closed       BOOLEAN     NOT NULL DEFAULT FALSE,
    closed_at       TIMESTAMPTZ,
    closed_by       UUID        REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID        NOT NULL REFERENCES users(id),
    UNIQUE (branch_id, year_name_bs)
);
```

---

## audit.audit_logs

```sql
CREATE TABLE audit.audit_logs (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID        REFERENCES branches(id),
    user_id         UUID        REFERENCES users(id),
    module          VARCHAR(50) NOT NULL,
    action          VARCHAR(100) NOT NULL,
    entity_type     VARCHAR(50),
    entity_id       UUID,
    description     TEXT,
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    request_path    TEXT,
    response_status INTEGER,
    duration_ms     INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

CREATE TABLE audit.audit_logs_2081
    PARTITION OF audit.audit_logs
    FOR VALUES FROM ('2024-04-14') TO ('2025-04-13');

CREATE TABLE audit.audit_logs_2082
    PARTITION OF audit.audit_logs
    FOR VALUES FROM ('2025-04-14') TO ('2026-04-13');
```

---

## audit.login_history

```sql
CREATE TABLE audit.login_history (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(id),
    login_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    logout_at       TIMESTAMPTZ,
    ip_address      VARCHAR(45),
    device_type     VARCHAR(30),
    device_info     TEXT,
    browser         VARCHAR(100),
    os              VARCHAR(100),
    success         BOOLEAN     NOT NULL,
    failure_reason  VARCHAR(100),
    session_duration INTEGER     -- seconds
);
```

---

## public.notifications

```sql
CREATE TABLE notifications (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID        REFERENCES branches(id),
    member_id       UUID        REFERENCES members(id),
    user_id         UUID        REFERENCES users(id),
    channel         VARCHAR(20) NOT NULL CHECK (channel IN ('SMS','Email','Push')),
    title           VARCHAR(200),
    body            TEXT        NOT NULL,
    reference_type  VARCHAR(50),
    reference_id    UUID,
    status          VARCHAR(20) NOT NULL DEFAULT 'Pending'
                    CHECK (status IN ('Pending','Sent','Delivered','Failed')),
    sent_at         TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    failure_reason  TEXT,
    retry_count     INTEGER     NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## public.settings

```sql
CREATE TABLE settings (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID        REFERENCES branches(id),  -- NULL = global
    setting_key     VARCHAR(100) NOT NULL,
    setting_value   TEXT,
    data_type       VARCHAR(20) NOT NULL DEFAULT 'String'
                    CHECK (data_type IN ('String','Integer','Decimal','Boolean','JSON')),
    description     TEXT,
    is_encrypted    BOOLEAN     NOT NULL DEFAULT FALSE,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by      UUID        REFERENCES users(id),
    UNIQUE (branch_id, setting_key)
);

-- Default settings
INSERT INTO settings (setting_key, setting_value, data_type, description) VALUES
    ('SHARE_VALUE',          '100',      'Decimal', 'Value per share in NPR'),
    ('MIN_SHARES',           '10',       'Integer', 'Minimum shares for membership'),
    ('EMI_GRACE_DAYS',       '7',        'Integer', 'Grace days before penalty'),
    ('OTP_TTL_MINUTES',      '5',        'Integer', 'OTP validity in minutes'),
    ('MAX_FAILED_LOGINS',    '5',        'Integer', 'Max failed logins before lockout'),
    ('SESSION_TIMEOUT_MIN',  '30',       'Integer', 'Session inactivity timeout'),
    ('SMS_GATEWAY',          'Sparrow',  'String',  'Primary SMS gateway'),
    ('BACKUP_TIME',          '02:00',    'String',  'Daily backup time (HH:MM)'),
    ('FISCAL_YEAR_START_BS', '04-01',    'String',  'Fiscal year start (MM-DD in BS)');
```
