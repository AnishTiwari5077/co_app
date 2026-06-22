# SahakariMS — Module: Members

## Overview

The Member module is the foundation of SahakariMS. Every financial product (savings, loans, shares) is linked to a member. This module manages the full member lifecycle from registration to closure.

---

## Member Lifecycle

```
Registration → Pending → KYC Upload → KYC Review → Approved → Active
                                                 ↘ Rejected → (Re-submit)
Active → Suspended → Reactivated → Active
Active → Closed (no outstanding balances)
```

---

## Member Code Format

```
{BRANCH_CODE}-{BS_YEAR}-{SEQUENCE}

Examples:
  KTM-2081-00001   ← First member at Kathmandu branch, fiscal year 2081
  PKR-2081-00045   ← 45th member at Pokhara branch, fiscal year 2081
  BRT-2082-00001   ← First member at Birtamode branch, fiscal year 2082
```

---

## Data Model

### Core Fields

| Field | Type | Rules |
|-------|------|-------|
| `first_name` | VARCHAR(100) | Required |
| `last_name` | VARCHAR(100) | Required |
| `gender` | ENUM | Male / Female / Other |
| `date_of_birth_ad` | DATE | Required, must be ≥ 18 years ago |
| `date_of_birth_bs` | VARCHAR(10) | Auto-converted from AD |
| `citizenship_number` | VARCHAR(50) | Unique, format: XX-XX-XX-XXXXX |
| `pan_number` | VARCHAR(20) | Optional, stored encrypted |
| `phone_primary` | VARCHAR(15) | Required, Nepal format: 9XXXXXXXXX |
| `address_district` | VARCHAR(100) | Required |
| `address_municipality` | VARCHAR(100) | Required |
| `status` | ENUM | Pending / Active / Inactive / Suspended / Closed |
| `kyc_verified` | BOOLEAN | False until verified by manager |

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/members` | MEMBERS_VIEW | List all members (paginated, searchable) |
| POST | `/members` | MEMBERS_CREATE | Register a new member |
| GET | `/members/{id}` | MEMBERS_VIEW | Get full member profile |
| PUT | `/members/{id}` | MEMBERS_EDIT | Update member information |
| POST | `/members/{id}/kyc-verify` | MEMBERS_APPROVE | Mark KYC as verified |
| POST | `/members/{id}/approve` | MEMBERS_APPROVE | Approve pending membership |
| POST | `/members/{id}/suspend` | MEMBERS_EDIT | Suspend an active member |
| POST | `/members/{id}/reactivate` | MEMBERS_APPROVE | Reactivate a suspended member |
| POST | `/members/{id}/close` | MEMBERS_CLOSE | Close a member account |
| GET | `/members/{id}/statement` | MEMBERS_VIEW | Get full member statement |
| GET | `/members/{id}/documents` | MEMBERS_VIEW | List uploaded documents |
| POST | `/members/{id}/documents` | MEMBERS_EDIT | Upload a document |
| GET | `/members/{id}/nominees` | MEMBERS_VIEW | Get nominees |
| POST | `/members/{id}/nominees` | MEMBERS_EDIT | Add/update nominees |
| GET | `/members/search` | MEMBERS_VIEW | Quick search by name/code/phone |
| GET | `/members/export` | REPORTS_EXPORT | Export member list (Excel/PDF) |
| GET | `/members/copomis` | REPORTS_EXPORT | COPOMIS format export |

---

## Flutter UI Screens

### Member List Screen

- Searchable, filterable list with infinite scroll
- Filter chips: All / Active / Pending / Suspended
- Each card shows: photo, name, code, phone, status badge, savings balance
- FAB: Register new member
- Pull to refresh

### Member Registration Form

- Multi-step form (5 steps):
  1. **Personal Info** — Name, DOB, Gender, Blood group
  2. **Contact & Address** — Phone, Email, Province, District, Municipality
  3. **Identity Documents** — Citizenship number, PAN, upload docs
  4. **Photo & Signature** — Camera capture or gallery
  5. **Family & Nominees** — Spouse, children, nominee details
- Real-time validation per field
- BS date picker for DOB
- Auto-convert BS ↔ AD dates

### Member Profile Screen

- Header: Photo, name, member code, status badge
- Tab bar:
  - **Overview** — KYC status, address, contact
  - **Accounts** — Share account + all savings accounts
  - **Loans** — Active and closed loans
  - **Transactions** — Recent 30 transactions
  - **Documents** — Uploaded KYC documents
- Action buttons: Edit, Suspend, Approve (based on role)

### KYC Verification Screen

- Document viewer (image / PDF)
- Approve / Reject with reason
- Before/after comparison with stored data

---

## Business Rules

| Rule | Description |
|------|-------------|
| MEM-001 | Age ≥ 18 years at registration |
| MEM-002 | Citizenship number unique across system |
| MEM-003 | Member must hold ≥ 10 shares to be Active |
| MEM-004 | Cannot close with outstanding loan balance |
| MEM-005 | Cannot close with non-zero savings balance |
| MEM-006 | KYC must be verified before first loan |
| MEM-009 | Nominee percentages must sum to 100% |
| MEM-010 | Suspended members cannot transact |

---

## COPOMIS Integration

COPOMIS (Cooperative Portfolio and Management Information System) is the Nepal government's regulatory reporting platform.

### Required Data

```xml
<Member>
  <MemberCode>KTM-2081-00001</MemberCode>
  <FullName>Ram Bahadur Shrestha</FullName>
  <Gender>Male</Gender>
  <DateOfBirth>1985-06-15</DateOfBirth>
  <CitizenshipNo>01-01-75-12345</CitizenshipNo>
  <PhoneNumber>9841234567</PhoneNumber>
  <Municipality>Kathmandu Metropolitan City</Municipality>
  <Ward>15</Ward>
  <MembershipDate>2081-04-01</MembershipDate>
  <SharesHeld>100</SharesHeld>
  <ShareValue>10000</ShareValue>
  <TotalSavings>50000</TotalSavings>
  <OutstandingLoan>0</OutstandingLoan>
  <Status>Active</Status>
</Member>
```

COPOMIS export is triggered from Reports → COPOMIS Export and generates an XML file for upload to the municipality portal.

---

## Member Statement

The member statement consolidates all financial activity across all accounts:

```
MEMBER STATEMENT
================
Member: Ram Bahadur Shrestha (KTM-2081-00001)
Period: 2081-01-01 to 2081-04-15
Generated: 2081-04-15

SAVINGS ACCOUNTS:
SAV-2081-00123 (Regular Savings) — Balance: NPR 45,000.00
  2081-04-01  Deposit (Cash)        +10,000.00     45,000.00
  2081-04-10  Withdrawal (Cash)      -5,000.00     40,000.00
  2081-04-15  Interest Credit           +238.00     45,238.00

FIXED DEPOSITS:
FD-2081-00045 — NPR 200,000 @ 12% for 12 months
  Maturity: 2082-04-15
  Monthly Interest: NPR 2,000.00

LOANS:
LN-2081-00067 (Business Loan) — Outstanding: NPR 450,000.00
  Next EMI Due: 2081-05-01 — NPR 11,634.00

SHARES:
100 shares × NPR 100 = NPR 10,000.00
```
