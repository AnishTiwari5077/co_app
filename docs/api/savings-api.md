# SahakariMS — API: Savings API

## Base URL
`/api/v1/savings`

All endpoints require `Authorization: Bearer {token}`.

---

## Savings Accounts

### GET /savings/accounts
List all savings accounts for the branch.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `page` | int | Page number (default: 1) |
| `pageSize` | int | Results per page (max: 100) |
| `memberId` | uuid | Filter by member |
| `schemeId` | uuid | Filter by scheme |
| `accountType` | string | Regular \| FixedDeposit \| RecurringDeposit |
| `status` | string | Active \| Dormant \| Frozen \| Closed |
| `search` | string | Account number or member name |

**Response 200:**
```json
{
  "items": [
    {
      "id": "uuid",
      "accountNumber": "SAV-KTM-2081-00456",
      "accountType": "Regular",
      "schemeName": "Regular Savings",
      "interestRate": 7.5,
      "currentBalance": 45238.00,
      "member": {
        "id": "uuid",
        "memberCode": "KTM-2081-00001",
        "fullName": "Ram Bahadur Shrestha",
        "phone": "9841234567"
      },
      "status": "Active",
      "openedDateBs": "2081-01-15",
      "lastTransactionDate": "2081-04-15"
    }
  ],
  "totalCount": 523,
  "page": 1,
  "pageSize": 20
}
```

---

### POST /savings/accounts
Open a new savings account.

**Permission:** `SAVINGS_VIEW`

**Request:**
```json
{
  "memberId": "uuid",
  "schemeId": "uuid",
  "openingBalance": 1000.00,
  "depositMode": "Cash",
  "narration": "Account opening"
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "accountNumber": "SAV-KTM-2081-00523",
  "currentBalance": 1000.00,
  "interestRate": 7.5,
  "openedDateBs": "2081-04-15"
}
```

---

### GET /savings/accounts/{id}
Get full account details.

**Response 200:**
```json
{
  "id": "uuid",
  "accountNumber": "SAV-KTM-2081-00456",
  "accountType": "Regular",
  "scheme": {
    "id": "uuid",
    "name": "Regular Savings",
    "interestRate": 7.5,
    "minimumBalance": 100.00
  },
  "member": { "id": "uuid", "memberCode": "...", "fullName": "..." },
  "currentBalance": 45238.00,
  "totalDeposits": 120000.00,
  "totalWithdrawals": 80000.00,
  "accruedInterest": 238.00,
  "status": "Active",
  "openedDateAd": "2024-04-28",
  "openedDateBs": "2081-01-15",
  "lastTransactionDate": "2081-04-15"
}
```

---

### POST /savings/accounts/{id}/deposit

**Permission:** `SAVINGS_DEPOSIT`

**Request:**
```json
{
  "amount": 5000.00,
  "depositMode": "Cash",
  "narration": "Monthly savings",
  "chequeNumber": null,
  "collectedBy": null
}
```

**Response 201:**
```json
{
  "transactionId": "uuid",
  "receiptNumber": "RCP-KTM-2081-04567",
  "amount": 5000.00,
  "balanceBefore": 40238.00,
  "balanceAfter": 45238.00,
  "transactionDateBs": "2081-04-15",
  "processedBy": "Sita Rana"
}
```

**Errors:**
- `400` — Amount ≤ 0, below minimum deposit, account not active
- `403` — Insufficient permission

---

### POST /savings/accounts/{id}/withdraw

**Permission:** `SAVINGS_WITHDRAW`

**Request:**
```json
{
  "amount": 2000.00,
  "withdrawalMode": "Cash",
  "narration": "Personal expenses",
  "approvalId": null
}
```

**Response 201:** Same structure as deposit

**Errors:**
- `400` — Insufficient balance, account frozen or not active
- `403` — Amount exceeds limit, requires manager approval

---

### GET /savings/accounts/{id}/statement

**Permission:** `SAVINGS_VIEW`

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `fromDate` | string (BS) | From date (BS format: 2081-01-01) |
| `toDate` | string (BS) | To date |
| `format` | string | json \| pdf |

**Response (JSON):**
```json
{
  "accountNumber": "SAV-KTM-2081-00456",
  "memberName": "Ram Bahadur Shrestha",
  "period": { "from": "2081-01-01", "to": "2081-04-15" },
  "openingBalance": 10000.00,
  "closingBalance": 45238.00,
  "totalDeposits": 40000.00,
  "totalWithdrawals": 5000.00,
  "interestEarned": 238.00,
  "transactions": [
    {
      "date": "2081-01-15",
      "type": "Deposit",
      "amount": 10000.00,
      "balance": 20000.00,
      "narration": "Cash deposit",
      "receipt": "RCP-KTM-2081-00123"
    }
  ]
}
```

---

## Fixed Deposits

### GET /savings/fd
List all FDs. Query params: `memberId`, `status`, `maturingIn` (days).

### POST /savings/fd
Create FD. See [fixed-deposit.md](../modules/fixed-deposit.md).

### POST /savings/fd/{id}/close-premature
Close FD before maturity. Response includes penalty breakdown.

---

## Schemes

### GET /savings/schemes
List configured saving schemes.

### POST /savings/schemes
**Permission:** `SAVING_SCHEMES_MANAGE`
Create a new saving scheme with rate and rules.

---

## Interest Operations

### GET /savings/interest/pending
Preview interest amounts that would be posted if posting runs now.

### POST /savings/interest/post
**Permission:** `SAVINGS_INTEREST`
Post monthly interest to all active accounts in the branch.

**Request:**
```json
{
  "postingDateBs": "2081-04-30",
  "dryRun": false
}
```
