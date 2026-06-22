# SahakariMS — API: Reports API

## Base URL
`/api/v1/reports`

All endpoints require `Authorization: Bearer {token}` and `REPORTS_VIEW_BASIC` or `REPORTS_VIEW_FINANCIAL` permission.

---

## Daily Reports

### GET /reports/daily-collection
Today's complete collection summary.

**Permission:** `REPORTS_VIEW_BASIC`

**Response 200:**
```json
{
  "reportDate": "2081-04-15",
  "branchName": "Kathmandu Main Branch",
  "savings": {
    "totalDeposits": 245000.00,
    "totalWithdrawals": 85000.00,
    "netCollection": 160000.00,
    "transactionCount": 54,
    "newAccountsOpened": 3
  },
  "loans": {
    "emiCollected": 65000.00,
    "penaltyCollected": 2500.00,
    "loansDisbursed": 500000.00,
    "newLoanCount": 1,
    "emiCollectionCount": 12
  },
  "shares": {
    "sharesCollected": 10000.00,
    "newShareHolders": 2
  },
  "cashPosition": {
    "openingBalance": 150000.00,
    "totalReceipts": 322500.00,
    "totalPayments": 585000.00,
    "closingBalance": 375000.00
  },
  "generatedAt": "2081-04-15T17:00:00Z"
}
```

**Query Parameters:** `date` (BS format, default: today), `format` (json | pdf)

---

### GET /reports/cashier-session
Cashier session report for a specific session.

**Query Parameters:** `sessionId` | `cashierUserId` + `date`

---

## Loan Reports

### GET /reports/loan-outstanding
Loan portfolio outstanding report.

**Permission:** `REPORTS_VIEW_BASIC`

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `asOfDateBs` | string | Balance as of date (default: today) |
| `npaClassification` | string | Filter by NPA class |
| `productId` | uuid | Filter by product |
| `overdueDaysMin` | int | Min overdue days |
| `format` | string | json \| pdf \| excel |

**Response 200:**
```json
{
  "asOfDate": "2081-04-15",
  "summary": {
    "totalLoans": 423,
    "totalOutstanding": 78500000.00,
    "totalOverdue": 1200000.00,
    "totalNPA": 800000.00,
    "npaPercent": 1.02
  },
  "npaBreakdown": {
    "standard": { "count": 400, "amount": 77000000 },
    "watchlist": { "count": 15, "amount": 700000 },
    "substandard": { "count": 5, "amount": 300000 },
    "doubtful": { "count": 2, "amount": 200000 },
    "loss": { "count": 1, "amount": 300000 }
  },
  "loans": [
    {
      "loanNumber": "LN-KTM-2081-00089",
      "memberName": "Ram Shrestha",
      "product": "Business Loan",
      "principal": 500000,
      "outstanding": 450000,
      "overdueDays": 0,
      "npaClass": "Standard",
      "nextEmiDate": "2081-05-15"
    }
  ]
}
```

---

### GET /reports/defaulter-list
Members with overdue loans.

**Query Parameters:** `minOverdueDays` (default: 1), `format`

---

### GET /reports/loan-maturity
Loans maturing in next 30/60/90 days.

**Query Parameters:** `daysAhead` (30 | 60 | 90)

---

## Financial Reports

### GET /reports/trial-balance

**Permission:** `REPORTS_VIEW_FINANCIAL`

**Query Parameters:** `asOfDateBs`, `format`

---

### GET /reports/balance-sheet

**Permission:** `REPORTS_VIEW_FINANCIAL`

**Response 200 (abbreviated):**
```json
{
  "asOfDate": "2081-04-15",
  "assets": {
    "currentAssets": {
      "cashInHand": 850000,
      "cashAtBank": 5200000,
      "loanReceivables": 78500000,
      "totalCurrentAssets": 84550000
    },
    "fixedAssets": { ... },
    "totalAssets": 90000000
  },
  "liabilities": {
    "memberSavings": 45000000,
    "fixedDeposits": 30000000,
    "shareCapital": 12500000,
    "otherLiabilities": 2500000,
    "totalLiabilities": 90000000
  },
  "isBalanced": true
}
```

---

### GET /reports/profit-loss

**Permission:** `REPORTS_VIEW_FINANCIAL`

**Query Parameters:** `fromDateBs`, `toDateBs`, `format`

---

### GET /reports/member-savings-summary
Summary of all savings by scheme type.

---

## COPOMIS Report

### GET /reports/copomis

**Permission:** `REPORTS_COPOMIS`

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `fiscalYear` | string | e.g., "2081-82" |
| `quarter` | int | 1, 2, 3, or 4 |
| `format` | string | xml \| preview |

**Response (XML):** As per DoC COPOMIS schema.

---

## Audit Reports

### GET /reports/audit-trail

**Permission:** `REPORTS_AUDIT`

**Query Parameters:** `userId`, `module`, `action`, `fromDate`, `toDate`, `format`

---

## Report Export Formats

All major reports support multiple formats:

| Format | Content-Type | Notes |
|--------|-------------|-------|
| `json` | application/json | Default, for UI rendering |
| `pdf` | application/pdf | iText7 — branded PDF |
| `excel` | application/vnd.openxmlformats-officedocument.spreadsheetml.sheet | EPPlus |
| `csv` | text/csv | For data import/export |
| `xml` | application/xml | COPOMIS only |

Large reports (> 1000 rows) are generated as background jobs:

```json
POST /reports/loan-outstanding?format=excel
→ 202 Accepted
{
  "jobId": "uuid",
  "estimatedCompletionSeconds": 30,
  "statusUrl": "/reports/jobs/uuid"
}

GET /reports/jobs/{jobId}
→ { "status": "Completed", "downloadUrl": "/reports/download/uuid" }
```
