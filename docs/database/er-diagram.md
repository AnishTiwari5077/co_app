# SahakariMS — Entity Relationship Diagram

## Legend

```
┌─────────────────┐
│   TABLE_NAME    │
├─────────────────┤
│ PK id           │  ← Primary Key
│ FK branch_id    │  ← Foreign Key
│    column_name  │
└─────────────────┘

─────────── One-to-Many
══════════  One-to-One
──── ─ ─── Optional (nullable FK)
```

---

## Module 1: Identity & Access

```
┌──────────────┐        ┌──────────────┐        ┌──────────────────┐
│   branches   │        │    users     │        │     roles        │
├──────────────┤        ├──────────────┤        ├──────────────────┤
│PK id         │◄───────│FK branch_id  │        │PK id             │
│   code       │        │PK id         │        │   name           │
│   name       │        │   full_name  │        │   description    │
│   address    │        │   email      │        │   is_system_role │
│   phone      │        │   username   │        └──────────────────┘
│   status     │        │   password   │               ▲
└──────────────┘        │   status     │               │
                        └──────────────┘        ┌──────────────────┐
                               │                │   user_roles     │
                               │◄───────────────│FK user_id        │
                               │                │FK role_id        │
                               │                └──────────────────┘
                               │
                        ┌──────────────┐        ┌──────────────────┐
                        │role_permissions│      │   permissions    │
                        ├──────────────┤        ├──────────────────┤
                        │FK role_id    │───────►│PK id             │
                        │FK perm_id    │        │   module         │
                        └──────────────┘        │   action         │
                                                │   description    │
                                                └──────────────────┘
```

---

## Module 2: Member Management

```
┌──────────────┐
│   members    │
├──────────────┤
│PK id         │──────────────────────────────────────────────────┐
│FK branch_id  │                                                  │
│   member_code│                                                  │
│   first_name │                                                  │
│   last_name  │         ┌────────────────────┐                  │
│   citizenship│         │ member_family_details│                 │
│   phone      │         ├────────────────────┤                  │
│   status     │◄────────│FK member_id        │                  │
│   kyc_verified         │   relation         │                  │
└──────────────┘         │   full_name        │                  │
       │                 │   occupation       │                  │
       │                 └────────────────────┘                  │
       │                                                         │
       │         ┌──────────────────┐                           │
       ├────────►│  member_nominees │                           │
       │         ├──────────────────┤                           │
       │         │FK member_id      │                           │
       │         │   full_name      │                           │
       │         │   relation       │                           │
       │         │   is_primary     │                           │
       │         └──────────────────┘                           │
       │                                                         │
       │         ┌──────────────────┐                           │
       └────────►│ member_documents │                           │
                 ├──────────────────┤                           │
                 │FK member_id      │                           │
                 │   doc_type       │                           │
                 │   doc_number     │                           │
                 │   file_url       │                           │
                 │   verified       │                           │
                 └──────────────────┘                           │
                                                                │
                 ┌──────────────────┐                           │
                 │  share_accounts  │◄──────────────────────────┘
                 ├──────────────────┤
                 │PK id             │
                 │FK member_id      │
                 │   shares_held    │
                 │   total_value    │
                 └──────────────────┘
                          │
                 ┌────────┴──────────┐
                 │  share_transactions│
                 ├───────────────────┤
                 │FK share_account_id│
                 │   txn_type        │
                 │   quantity        │
                 │   amount          │
                 └───────────────────┘
```

---

## Module 3: Savings & Deposits

```
┌─────────────────┐        ┌────────────────────┐
│  saving_schemes │        │   saving_accounts  │
├─────────────────┤        ├────────────────────┤
│PK id            │◄───────│FK scheme_id        │
│   scheme_code   │        │FK member_id ───────┼──► members
│   scheme_name   │        │PK id               │
│   account_type  │        │   account_number   │
│   interest_rate │        │   current_balance  │
│   min_balance   │        │   accrued_interest │
│   is_active     │        │   status           │
└─────────────────┘        └────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
         ┌──────────▼──────┐ ┌─────▼──────┐ ┌────▼────────────┐
         │saving_transactions│ │fixed_deposits│ │recurring_deposits│
         ├─────────────────┤ ├────────────┤ ├────────────────┤
         │FK account_id    │ │FK account_id│ │FK account_id   │
         │   txn_type      │ │   fd_number │ │   rd_number    │
         │   amount        │ │   principal │ │   monthly_amt  │
         │   balance_after │ │   interest  │ │   tenure       │
         │   txn_date_ad   │ │   maturity  │ │   installments │
         │   receipt_number│ │   status    │ │   paid_count   │
         └─────────────────┘ └────────────┘ └────────────────┘
```

---

## Module 4: Loan Management

```
┌──────────────────┐        ┌─────────────┐
│  loan_products   │        │    loans    │
├──────────────────┤        ├─────────────┤
│PK id             │◄───────│FK product_id│
│   product_code   │        │FK member_id ┼──► members
│   product_name   │        │FK branch_id ┼──► branches
│   loan_type      │        │PK id        │
│   max_amount     │        │   loan_num  │
│   interest_rate  │        │   applied_  │
│   max_tenure     │        │   amount    │
│   penalty_rate   │        │   status    │
└──────────────────┘        │   outstanding│
                            │   balance   │
                            └─────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
    ┌─────────▼──────┐  ┌──────────▼────┐  ┌──────────▼──────┐
    │  loan_schedules │  │ loan_payments │  │ loan_guarantors │
    ├────────────────┤  ├───────────────┤  ├─────────────────┤
    │FK loan_id      │  │FK loan_id     │  │FK loan_id       │
    │   emi_number   │  │   paid_amount │  │FK member_id ────┼──► members
    │   due_date_ad  │  │   principal   │  │   relation      │
    │   principal    │  │   interest    │  │   share_amount  │
    │   interest     │  │   penalty     │  │   status        │
    │   balance      │  │   receipt_num │  └─────────────────┘
    │   status       │  │   paid_date   │
    └────────────────┘  └───────────────┘
              │
    ┌─────────▼──────┐
    │   collaterals  │
    ├────────────────┤
    │FK loan_id      │
    │   type         │ (Land, Gold, Vehicle, Building)
    │   description  │
    │   estimated_val│
    │   verified     │
    └────────────────┘
```

---

## Module 5: Accounting

```
┌──────────────────┐        ┌──────────────────┐
│   fiscal_years   │        │     accounts     │
├──────────────────┤        ├──────────────────┤
│PK id             │        │PK id             │
│FK branch_id      │        │FK branch_id      │
│   year_name_bs   │        │FK parent_id ─────┼──► accounts (self-ref)
│   start_date_ad  │        │   account_code   │
│   end_date_ad    │        │   account_name   │
│   is_current     │        │   account_type   │ (Asset/Liability/Equity/Revenue/Expense)
│   is_closed      │        │   level          │ (1-5)
└──────────────────┘        │   is_leaf        │
        │                   │   opening_balance│
        │                   └──────────────────┘
        │                            │
        ▼                            │
┌──────────────────┐                 │
│    vouchers      │                 │
├──────────────────┤                 │
│PK id             │                 │
│FK branch_id      │                 │
│FK fiscal_year_id │                 │
│   voucher_number │                 │
│   voucher_type   │                 │
│   voucher_date   │                 │
│   narration      │                 │
│   total_amount   │                 │
│   is_posted      │                 │
└──────────────────┘                 │
        │                            │
        ▼                            │
┌──────────────────┐                 │
│  voucher_entries │                 │
├──────────────────┤                 │
│FK voucher_id     │                 │
│FK account_id ────┼─────────────────┘
│   entry_type     │ (Debit/Credit)
│   amount         │
│   narration      │
└──────────────────┘
```

---

## Module 6: Cash Counter

```
┌───────────────────────┐        ┌──────────────────────┐
│ cash_counter_sessions │        │   cash_transactions  │
├───────────────────────┤        ├──────────────────────┤
│PK id                  │◄───────│FK session_id         │
│FK branch_id           │        │FK branch_id          │
│FK cashier_id ─────────┼──►users│   txn_type           │
│   session_date_ad     │        │   amount             │
│   opening_amount      │        │   member_id          │
│   closing_amount      │        │   account_id         │
│   difference          │        │   receipt_number     │
│   status              │        └──────────────────────┘
└───────────────────────┘
          │
          ▼
┌───────────────────────┐
│    vault_transfers    │
├───────────────────────┤
│FK from_session_id     │
│FK to_session_id       │
│   amount              │
│   direction           │ (ToVault, FromVault)
│   approved_by         │
└───────────────────────┘
```

---

## Module 7: Audit

```
┌──────────────────────┐        ┌────────────────────────┐
│     audit_logs       │        │   transaction_audit    │
├──────────────────────┤        ├────────────────────────┤
│PK id                 │        │PK id                   │
│FK user_id ───────────┼──►users│   table_name           │
│   module             │        │   operation (I/U/D)    │
│   action             │        │   record_id            │
│   entity_type        │        │   old_data JSONB       │
│   entity_id          │        │   new_data JSONB       │
│   ip_address         │        │   changed_by           │
│   browser_agent      │        │   changed_at           │
│   description        │        └────────────────────────┘
│   created_at         │
└──────────────────────┘

┌──────────────────────┐
│    login_history     │
├──────────────────────┤
│PK id                 │
│FK user_id ───────────┼──►users
│   login_at           │
│   logout_at          │
│   ip_address         │
│   device_info        │
│   success            │
│   failure_reason     │
└──────────────────────┘
```

---

## Module 8: Notifications

```
┌──────────────────────┐        ┌──────────────────────┐
│    notifications     │        │      sms_logs        │
├──────────────────────┤        ├──────────────────────┤
│PK id                 │        │PK id                 │
│FK member_id ─────────┼──►members│  phone_number      │
│FK user_id            │        │   message            │
│   type (SMS/Email/   │        │   gateway            │
│         Push)        │        │   status             │
│   title              │        │   gateway_reference  │
│   body               │        │   sent_at            │
│   reference_type     │        │   delivered_at       │
│   reference_id       │        │   cost               │
│   is_read            │        └──────────────────────┘
│   sent_at            │
│   delivered_at       │
└──────────────────────┘
```

---

## Complete Table Inventory

| # | Table | Schema | Rows (Est.) |
|---|-------|--------|------------|
| 1 | branches | public | < 100 |
| 2 | users | public | < 1,000 |
| 3 | roles | public | < 20 |
| 4 | permissions | public | < 200 |
| 5 | user_roles | public | < 2,000 |
| 6 | role_permissions | public | < 2,000 |
| 7 | refresh_tokens | public | < 10,000 |
| 8 | members | public | 1K–100K |
| 9 | member_nominees | public | 1K–100K |
| 10 | member_documents | public | 3K–300K |
| 11 | member_family_details | public | 3K–300K |
| 12 | share_accounts | public | 1K–100K |
| 13 | share_transactions | public | 10K–1M |
| 14 | saving_schemes | public | < 50 |
| 15 | saving_accounts | public | 2K–200K |
| 16 | saving_transactions | public | 100K–10M |
| 17 | fixed_deposits | public | 1K–50K |
| 18 | recurring_deposits | public | 1K–50K |
| 19 | loan_products | public | < 20 |
| 20 | loans | public | 1K–50K |
| 21 | loan_schedules | public | 12K–600K |
| 22 | loan_payments | public | 24K–600K |
| 23 | loan_guarantors | public | 2K–100K |
| 24 | collaterals | public | 1K–50K |
| 25 | accounts | accounting | < 500 |
| 26 | fiscal_years | accounting | < 20 |
| 27 | vouchers | accounting | 10K–500K |
| 28 | voucher_entries | accounting | 20K–1M |
| 29 | cash_counter_sessions | public | 5K–50K |
| 30 | audit_logs | audit | 1M+ (partitioned) |
| 31 | transaction_audit | audit | 500K+ (partitioned) |
| 32 | login_history | audit | 100K+ (partitioned) |
| 33 | notifications | public | 500K+ |
| 34 | sms_logs | public | 500K+ |
