# SahakariMS — API Specification

## Base URL

```
Production:  https://api.sahakarims.np/api/v1
Staging:     https://staging-api.sahakarims.np/api/v1
Development: http://localhost:5000/api/v1
```

## Authentication

All protected endpoints require a JWT Bearer token:

```
Authorization: Bearer <access_token>
```

## Standard Response Format

### Success Response

```json
{
  "success": true,
  "data": { ... },
  "message": "Operation completed successfully",
  "timestamp": "2081-04-15T10:30:00Z"
}
```

### Paginated Response

```json
{
  "success": true,
  "data": [ ... ],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 245,
    "totalPages": 13
  }
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "MEMBER_NOT_FOUND",
    "message": "Member with ID abc123 was not found.",
    "details": [ ]
  },
  "correlationId": "x-corr-abc123"
}
```

### Validation Error

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "One or more validation errors occurred.",
    "details": [
      { "field": "phoneNumber", "message": "Invalid Nepal phone number format." },
      { "field": "citizenshipNumber", "message": "Citizenship number is required." }
    ]
  }
}
```

---

## HTTP Status Codes

| Code | Usage |
|------|-------|
| `200 OK` | Successful GET, PUT, PATCH |
| `201 Created` | Successful POST creating a resource |
| `204 No Content` | Successful DELETE |
| `400 Bad Request` | Validation errors |
| `401 Unauthorized` | Missing or invalid JWT |
| `403 Forbidden` | Insufficient permissions |
| `404 Not Found` | Resource not found |
| `409 Conflict` | Duplicate resource (e.g. member already exists) |
| `422 Unprocessable Entity` | Business rule violation |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Unexpected server error |

---

## Authentication Endpoints

### POST /auth/login

Login with username and password.

**Request:**
```json
{
  "username": "cashier01@sahakarims.np",
  "password": "MySecurePassword@123",
  "deviceId": "device-uuid-123"
}
```

**Response 200:**
```json
{
  "accessToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "requiresTwoFactor": false,
  "user": {
    "id": "uuid",
    "fullName": "Ram Bahadur Shrestha",
    "email": "cashier01@sahakarims.np",
    "branchId": "uuid",
    "branchName": "Kathmandu Main Branch",
    "roles": ["Cashier"],
    "permissions": ["SAVINGS_DEPOSIT", "SAVINGS_WITHDRAW", "CASH_COUNTER"]
  }
}
```

### POST /auth/refresh-token

Rotate refresh token and get new access token.

**Request:**
```json
{ "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4..." }
```

**Response 200:**
```json
{
  "accessToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "bmV3IHJlZnJlc2ggdG9rZW4...",
  "expiresIn": 900
}
```

### POST /auth/logout

```json
{ "refreshToken": "..." }
```

### POST /auth/send-otp

```json
{ "phoneNumber": "9841234567", "purpose": "Login" }
```

### POST /auth/verify-otp

```json
{ "phoneNumber": "9841234567", "otp": "123456", "purpose": "Login" }
```

### POST /auth/change-password

```json
{
  "currentPassword": "OldPass@123",
  "newPassword": "NewPass@123",
  "confirmPassword": "NewPass@123"
}
```

---

## Member Endpoints

### GET /members

List all members (paginated).

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `page` | int | Page number (default: 1) |
| `pageSize` | int | Results per page (default: 20, max: 100) |
| `search` | string | Search by name, code, citizenship, phone |
| `status` | string | Filter by status (Active, Pending, Inactive) |
| `branchId` | uuid | Filter by branch |

**Response 200:**
```json
{
  "data": [
    {
      "id": "uuid",
      "memberCode": "KTM-2081-00123",
      "fullName": "Sita Devi Tamang",
      "phone": "9845678901",
      "status": "Active",
      "totalSavings": 45000.00,
      "totalLoan": 100000.00,
      "joinedDate": "2081-04-01",
      "photoUrl": "https://..."
    }
  ],
  "pagination": { "page": 1, "pageSize": 20, "totalCount": 245 }
}
```

### POST /members

Register a new member.

**Request:**
```json
{
  "firstName": "Sita",
  "middleName": "Devi",
  "lastName": "Tamang",
  "gender": "Female",
  "dateOfBirthAd": "1985-06-15",
  "citizenshipNumber": "23-01-75-12345",
  "phoneNumber": "9845678901",
  "email": "sita@example.com",
  "addressDistrict": "Lalitpur",
  "addressMunicipality": "Lalitpur Metropolitan City",
  "addressWard": "5",
  "addressTole": "Pulchowk",
  "occupation": "Business",
  "branchId": "uuid"
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "memberCode": "KTM-2081-00124",
  "status": "Pending",
  "createdAt": "2081-04-15T10:30:00Z"
}
```

### GET /members/{id}

Get full member profile.

**Response 200:**
```json
{
  "id": "uuid",
  "memberCode": "KTM-2081-00124",
  "firstName": "Sita",
  "lastName": "Tamang",
  "gender": "Female",
  "dateOfBirthAd": "1985-06-15",
  "citizenshipNumber": "23-01-75-12345",
  "phone": "9845678901",
  "status": "Active",
  "kycVerified": true,
  "photoUrl": "https://...",
  "shareAccount": { "sharesHeld": 100, "totalValue": 10000 },
  "savingAccounts": [ { ... } ],
  "loans": [ { ... } ],
  "nominees": [ { ... } ],
  "familyDetails": [ { ... } ]
}
```

### PUT /members/{id}

Update member profile.

### POST /members/{id}/kyc-verify

Mark member KYC as verified.

```json
{ "verifiedAt": "2081-04-15T10:30:00Z", "remarks": "Documents verified" }
```

### POST /members/{id}/approve

Approve pending membership.

### POST /members/{id}/suspend

Suspend an active member.

```json
{ "reason": "Loan default — legal proceedings" }
```

### GET /members/{id}/statement

Get full member statement (all accounts).

**Query:** `?fromDate=2081-01-01&toDate=2081-04-15&format=json`

---

## Savings Endpoints

### GET /savings/accounts

List savings accounts.

**Query:** `memberId`, `accountType`, `status`, `page`, `pageSize`

### POST /savings/accounts

Open a new savings account.

```json
{
  "memberId": "uuid",
  "schemeId": "uuid",
  "openingDeposit": 1000.00,
  "nomineeId": "uuid"
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "accountNumber": "SAV-2081-00456",
  "currentBalance": 1000.00,
  "interestRate": 7.50,
  "openDate": "2081-04-15"
}
```

### GET /savings/accounts/{id}

Get account details with recent transactions.

### POST /savings/accounts/{id}/deposit

```json
{
  "amount": 5000.00,
  "depositMode": "Cash",
  "narration": "Regular savings deposit",
  "collectedBy": "uuid"
}
```

**Response 200:**
```json
{
  "transactionId": "uuid",
  "receiptNumber": "RCP-2081-01234",
  "amount": 5000.00,
  "balanceAfter": 15000.00,
  "transactionDate": "2081-04-15"
}
```

### POST /savings/accounts/{id}/withdraw

```json
{
  "amount": 2000.00,
  "withdrawalMode": "Cash",
  "narration": "Emergency withdrawal",
  "verifiedById": "uuid"
}
```

### GET /savings/accounts/{id}/statement

Get account statement.

**Query:** `?fromDate=&toDate=&format=json|pdf|excel`

### POST /savings/accounts/{id}/freeze

```json
{ "reason": "Legal hold — court order #2081/123" }
```

### POST /savings/accounts/{id}/unfreeze

### POST /savings/accounts/{id}/close

```json
{ "reason": "Member request", "closeToAccountId": "uuid" }
```

---

## Loan Endpoints

### POST /loans

Submit a loan application.

```json
{
  "memberId": "uuid",
  "loanProductId": "uuid",
  "requestedAmount": 500000.00,
  "tenureMonths": 60,
  "loanPurpose": "Business expansion — retail shop",
  "disbursementAccountId": "uuid",
  "guarantors": [
    { "memberId": "uuid", "shareAmount": 50000 }
  ],
  "collaterals": [
    {
      "type": "Land",
      "description": "2 Ropani land at Lalitpur",
      "estimatedValue": 3000000
    }
  ]
}
```

### GET /loans/{id}

Get loan details.

**Response 200:**
```json
{
  "id": "uuid",
  "loanNumber": "LN-2081-00456",
  "memberId": "uuid",
  "memberName": "Ram Bahadur Shrestha",
  "loanType": "Business",
  "disbursedAmount": 500000.00,
  "outstandingBalance": 450000.00,
  "interestRate": 14.0,
  "emiAmount": 11635.00,
  "tenure": 60,
  "status": "Active",
  "nextEmiDate": "2081-05-01",
  "nextEmiAmount": 11635.00,
  "overdueAmount": 0,
  "npaClassification": "Standard"
}
```

### GET /loans/{id}/schedule

Get full EMI schedule.

### POST /loans/{id}/approve

```json
{
  "approvedAmount": 500000.00,
  "approvalRemarks": "All documents verified. Approved."
}
```

### POST /loans/{id}/disburse

```json
{
  "disbursedAmount": 500000.00,
  "disbursementMode": "AccountCredit",
  "disbursementDate": "2081-04-15"
}
```

### POST /loans/{id}/payment

Make an EMI payment.

```json
{
  "amount": 11635.00,
  "paymentMode": "Cash",
  "paymentDate": "2081-05-01",
  "narration": "EMI payment for May 2081"
}
```

**Response 200:**
```json
{
  "receiptNumber": "RCP-2081-05001",
  "paidPrincipal": 5135.00,
  "paidInterest": 6500.00,
  "paidPenalty": 0,
  "outstandingBalance": 444865.00,
  "nextEmiDate": "2081-06-01"
}
```

### POST /loans/{id}/reschedule

```json
{
  "newTenureMonths": 72,
  "reason": "Member financial hardship",
  "approvedBy": "uuid"
}
```

---

## Accounting Endpoints

### GET /accounting/accounts

Get chart of accounts.

### POST /accounting/vouchers

Create a journal voucher.

```json
{
  "voucherType": "Journal",
  "voucherDate": "2081-04-15",
  "narration": "Year-end depreciation entry",
  "entries": [
    { "accountId": "uuid", "entryType": "Debit",  "amount": 50000, "narration": "Depreciation expense" },
    { "accountId": "uuid", "entryType": "Credit", "amount": 50000, "narration": "Accumulated depreciation" }
  ]
}
```

### GET /accounting/trial-balance

**Query:** `fiscalYearId`, `asOfDate`, `branchId`

**Response 200:**
```json
{
  "asOfDate": "2081-04-15",
  "branchName": "Kathmandu Main",
  "accounts": [
    {
      "accountCode": "1001",
      "accountName": "Cash in Hand",
      "accountType": "Asset",
      "debitBalance": 250000.00,
      "creditBalance": 0
    }
  ],
  "totalDebit": 5000000.00,
  "totalCredit": 5000000.00,
  "isBalanced": true
}
```

### GET /accounting/balance-sheet

**Query:** `fiscalYearId`, `asOfDate`, `branchId`

### GET /accounting/profit-loss

**Query:** `fiscalYearId`, `fromDate`, `toDate`, `branchId`

---

## Reports Endpoints

### GET /reports/daily-collection

**Query:** `date`, `branchId`, `collectorId`

### GET /reports/loan-outstanding

**Query:** `branchId`, `asOfDate`, `loanType`, `status`

### GET /reports/defaulters

**Query:** `branchId`, `overdueDays` (30, 60, 90, 180, 365+)

### GET /reports/fd-maturity

**Query:** `branchId`, `fromDate`, `toDate`

### GET /reports/copomis

**Query:** `branchId`, `fiscalYear`, `format=xml|excel`

Export COPOMIS data for municipality submission.

---

## Dashboard Endpoints

### GET /dashboard/summary

**Response 200:**
```json
{
  "totalMembers": 1250,
  "activeLoans": 423,
  "totalSavingsBalance": 45000000.00,
  "totalLoanOutstanding": 78000000.00,
  "todayDeposits": 250000.00,
  "todayWithdrawals": 120000.00,
  "loanRecoveryRate": 94.5,
  "npaPercent": 2.3,
  "newMembersThisMonth": 12,
  "cashPosition": 850000.00
}
```

---

## Rate Limiting

| User Type | Requests per Minute |
|-----------|-------------------|
| Regular User | 300 |
| Cashier | 600 |
| Admin | 1000 |
| Mobile App (Member) | 60 |
| Collector App | 120 |
| Reports (bulk) | 20 |

Rate limit headers included in every response:
```
X-RateLimit-Limit: 300
X-RateLimit-Remaining: 245
X-RateLimit-Reset: 1719000000
```
