# SahakariMS — Module: Branches

## Overview

The Branch module manages multi-branch operations. SahakariMS supports a single head office with unlimited subordinate branches. All data is branch-isolated via Row Level Security.

---

## Branch Hierarchy

```
Head Office (Super Admin access to all branches)
    │
    ├── Branch: Kathmandu Main (KTM)
    │       └── Sub-branch: Lalitpur (LTP)
    ├── Branch: Pokhara (PKR)
    ├── Branch: Birtamode (BRT)
    └── Branch: Dhangadhi (DNG)
```

---

## Branch Data Model

```sql
CREATE TABLE branches (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id       UUID REFERENCES branches(id),   -- NULL for head office
    branch_code     VARCHAR(10) NOT NULL UNIQUE,    -- KTM, PKR, BRT
    branch_name     VARCHAR(200) NOT NULL,
    branch_name_np  VARCHAR(400),                   -- Nepali name
    branch_type     VARCHAR(20) NOT NULL,            -- HeadOffice | MainBranch | SubBranch
    address_province VARCHAR(50),
    address_district VARCHAR(100),
    address_municipality VARCHAR(100),
    address_ward    VARCHAR(10),
    address_street  VARCHAR(200),
    phone           VARCHAR(15),
    email           VARCHAR(100),
    manager_user_id UUID REFERENCES users(id),
    established_date_ad DATE,
    established_date_bs VARCHAR(10),
    license_number  VARCHAR(50),       -- CoopReg or branch license
    pan_number      VARCHAR(20),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Row Level Security (Branch Isolation)

```sql
-- Enable RLS on all tables
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE saving_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their branch's data
CREATE POLICY branch_isolation ON members
    USING (branch_id = current_setting('app.current_branch_id', TRUE)::UUID
        OR current_setting('app.is_head_office', TRUE)::BOOLEAN = TRUE);

-- Head office staff bypass RLS to see all branches
-- Set in application middleware:
-- SET LOCAL app.is_head_office = 'true'; (for admin users)
-- SET LOCAL app.current_branch_id = '{uuid}'; (for branch users)
```

---

## Inter-Branch Transfers

Members can sometimes be transferred between branches (e.g., they moved cities):

```
POST /api/v1/branches/members/{memberId}/transfer
{
  "fromBranchId": "uuid",
  "toBranchId": "uuid",
  "reason": "Member relocated to Pokhara",
  "effectiveDate": "2081-04-15"
}

Rules:
  - All savings balance transfers to new branch
  - Active loans stay at originating branch until closure
  - New member code issued at target branch
  - Old code cross-referenced in member record
  - Accounting inter-branch transfer entry created
```

---

## Inter-Branch Accounting

Each branch maintains its own books. Head office consolidates:

```
Inter-branch lending:
  Head Office sends NPR 50 lakh to Pokhara branch

  Head Office books:
    Dr  Due from Pokhara Branch (Asset)    5,000,000
    Cr  Cash at Bank                       5,000,000

  Pokhara Branch books:
    Dr  Cash at Bank                       5,000,000
    Cr  Due to Head Office (Liability)     5,000,000
```

---

## Branch Settings

Each branch can configure:

```json
{
  "branchId": "uuid",
  "settings": {
    "minSharesForMembership": 10,
    "shareValue": 100,
    "maxSharesPerMember": 1000,
    "cashWithdrawalLimit": 200000,
    "largeWithdrawalThreshold": 100000,
    "largeWithdrawalApprover": "Manager",
    "workingDays": ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri"],
    "openingHour": "09:00",
    "closingHour": "17:00",
    "interestPostingDay": 30,
    "currencySymbol": "NPR",
    "fiscalYearStartMonth": 4,
    "fiscalYearStartDay": 1
  }
}
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/branches` | Any | List all branches |
| POST | `/branches` | BRANCHES_MANAGE | Create new branch |
| GET | `/branches/{id}` | Any | Branch details |
| PUT | `/branches/{id}` | BRANCHES_MANAGE | Update branch |
| POST | `/branches/{id}/deactivate` | ADMIN | Deactivate branch |
| GET | `/branches/{id}/settings` | SETTINGS_VIEW | Branch settings |
| PUT | `/branches/{id}/settings` | SETTINGS_EDIT | Update settings |
| POST | `/branches/{id}/members/{memberId}/transfer` | ADMIN | Transfer member |
| GET | `/branches/performance` | ADMIN | Multi-branch performance |
