# SahakariMS — API: Loan API

## Base URL
`/api/v1/loans`

All endpoints require `Authorization: Bearer {token}`.

---

## Loan Application

### POST /loans
Submit a new loan application.

**Permission:** `LOANS_APPLY`

**Request:**
```json
{
  "memberId": "uuid",
  "productId": "uuid",
  "requestedAmount": 500000.00,
  "tenureMonths": 60,
  "purpose": "Business expansion — grocery store",
  "guarantors": [
    { "memberId": "uuid", "relationship": "Friend" }
  ],
  "collaterals": [
    {
      "type": "Land",
      "description": "Kathmandu-4, Plot 123",
      "estimatedValue": 2000000.00,
      "ownerName": "Ram Shrestha"
    }
  ],
  "disbursementAccountId": "uuid"
}
```

**Response 201:**
```json
{
  "id": "uuid",
  "loanNumber": "LN-KTM-2081-00089",
  "status": "Pending",
  "requestedAmount": 500000.00,
  "tenureMonths": 60,
  "estimatedEmi": 11634.00,
  "submittedAt": "2081-04-15T09:32:11Z"
}
```

---

### GET /loans
List loans with filtering.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `memberId` | uuid | Filter by member |
| `status` | string | Pending \| Active \| Overdue \| Closed |
| `npaClassification` | string | Standard \| Watchlist \| Substandard \| Doubtful \| Loss |
| `overdueDaysMin` | int | Min overdue days |
| `fromDate` | string | Disbursement from date |
| `search` | string | Loan number or member name |
| `page` | int | |
| `pageSize` | int | |

**Response 200:**
```json
{
  "items": [
    {
      "id": "uuid",
      "loanNumber": "LN-KTM-2081-00089",
      "member": { "id": "uuid", "fullName": "Ram Shrestha", "code": "KTM-2081-00001" },
      "productName": "Business Loan",
      "principalAmount": 500000.00,
      "outstandingBalance": 450000.00,
      "interestRate": 14.0,
      "status": "Active",
      "npaClassification": "Standard",
      "nextEmiDate": "2081-05-15",
      "nextEmiAmount": 11634.00,
      "overdueDays": 0
    }
  ],
  "totalCount": 423,
  "totalOutstanding": 78500000.00
}
```

---

### GET /loans/{id}
Full loan details including schedule.

**Response 200:**
```json
{
  "id": "uuid",
  "loanNumber": "LN-KTM-2081-00089",
  "member": { ... },
  "product": { "name": "Business Loan", "interestMethod": "ReducingBalance" },
  "principalAmount": 500000.00,
  "outstandingBalance": 450000.00,
  "interestRate": 14.0,
  "penaltyRate": 2.0,
  "tenureMonths": 60,
  "disbursedAmount": 500000.00,
  "disbursedDate": "2081-04-15",
  "maturityDate": "2086-04-15",
  "status": "Active",
  "npaClassification": "Standard",
  "accruedPenalty": 0.00,
  "totalInterestPaid": 5833.00,
  "totalPrincipalPaid": 5801.00,
  "guarantors": [ { "memberName": "Sita Tamang", "relationship": "Friend" } ],
  "collaterals": [ { "type": "Land", "estimatedValue": 2000000 } ],
  "schedule": [
    {
      "emiNumber": 1,
      "dueDateBs": "2081-05-15",
      "emiAmount": 11634.00,
      "principalAmount": 5801.00,
      "interestAmount": 5833.00,
      "status": "Pending"
    }
  ]
}
```

---

### POST /loans/{id}/approve
Approve a loan application.

**Permission:** `LOANS_APPROVE`

**Request:**
```json
{
  "approvedAmount": 500000.00,
  "approvedInterestRate": 14.0,
  "approvedTenureMonths": 60,
  "remarks": "Good collateral. Credit history clean."
}
```

**Response 200:**
```json
{ "status": "Approved", "approvedAt": "2081-04-15T10:15:00Z" }
```

---

### POST /loans/{id}/reject
Reject with reason.

**Permission:** `LOANS_APPROVE`

**Request:**
```json
{ "reason": "Insufficient income to support EMI." }
```

---

### POST /loans/{id}/disburse
Disburse approved loan.

**Permission:** `LOANS_DISBURSE`

**Request:**
```json
{
  "disbursementMode": "AccountCredit",
  "disbursementAccountId": "uuid",
  "narration": "Business loan disbursement",
  "processingFee": 5000.00
}
```

**Response 200:**
```json
{
  "status": "Active",
  "disbursedAmount": 500000.00,
  "netDisbursed": 495000.00,
  "disbursedDate": "2081-04-15",
  "firstEmiDate": "2081-05-15",
  "emiAmount": 11634.00
}
```

---

### POST /loans/{id}/payment
Record an EMI payment.

**Permission:** `LOANS_PAYMENT`

**Request:**
```json
{
  "amount": 11634.00,
  "paymentMode": "Cash",
  "narration": "EMI payment April 2081",
  "receiptNumber": null
}
```

**Response 201:**
```json
{
  "transactionId": "uuid",
  "receiptNumber": "RCP-KTM-2081-04589",
  "amount": 11634.00,
  "principalPaid": 5801.00,
  "interestPaid": 5833.00,
  "penaltyPaid": 0.00,
  "outstandingBalance": 444199.00,
  "nextEmiDate": "2081-06-15"
}
```

---

### GET /loans/{id}/schedule
Full EMI schedule with payment status.

---

### POST /loans/{id}/reschedule
**Permission:** `LOANS_RESCHEDULE`

```json
{
  "newTenureMonths": 72,
  "newInterestRate": 14.0,
  "reason": "Business affected by flood"
}
```

---

### GET /loans/{id}/noc
Download loan closure NOC as PDF.

**Permission:** `LOANS_VIEW`

Only available when loan status is `Closed`.

---

### GET /loans/overdue
List overdue loans with overdue days.

### GET /loans/npa
List NPA loans grouped by classification.

### GET /loans/disbursements-today
Summary of today's disbursements.
