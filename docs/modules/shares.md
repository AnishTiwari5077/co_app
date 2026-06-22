# SahakariMS — Module: Shares

## Overview

The Share module manages member share capital — the ownership stake every cooperative member must purchase. Shares represent both equity and voting rights in the cooperative.

---

## Share Capital Rules

| Rule | Details |
|------|---------|
| Minimum shares | Configurable per branch (default: 10 shares to become Active) |
| Share face value | Configurable (commonly NPR 100 per share) |
| Maximum shares | Configurable (default: 1,000 shares per member) |
| Refund on exit | Shares refunded when member closes (after deductions) |
| Dividend | Annual dividend paid on shares from surplus |
| Non-transferable | Shares cannot be sold to third parties (only transferred) |

---

## Share Account Number Format

```
SHA-{BRANCH_CODE}-{MEMBER_CODE}

Example: SHA-KTM-KTM-2081-00001
```

Each member has exactly one share account (opened at membership).

---

## Share Purchase

```
POST /api/v1/shares/accounts/{memberId}/purchase
{
  "numberOfShares": 50,
  "amountPerShare": 100.00,
  "paymentMode": "Cash",
  "narration": "Initial share purchase"
}

Total Amount = 50 × 100 = NPR 5,000

Accounting Entry:
  Dr  Cash in Hand              5,000.00
  Cr  Share Capital (Equity)    5,000.00

Response:
{
  "totalShares": 50,
  "totalShareValue": 5000.00,
  "receiptNumber": "RCP-SHA-KTM-2081-001",
  "certificate": "SHC-KTM-2081-00001-001"   // Certificate number
}
```

---

## Share Certificate

Share certificates are issued for every purchase and can be printed as PDF:

```
═══════════════════════════════════════════
         SHARE CERTIFICATE
         {CooperativeName}
═══════════════════════════════════════════

Certificate No: SHC-KTM-2081-00001-001
Issue Date: 2081-04-15

This is to certify that

  RAM BAHADUR SHRESTHA
  Member Code: KTM-2081-00001

is the holder of

  FIFTY (50) SHARES
  at NPR 100.00 per share
  Total Value: NPR 5,000.00

Authorized Signatory: ___________________
                      Branch Manager

[QR Code for verification]
═══════════════════════════════════════════
```

---

## Share Refund

When a member exits (account closure):

```
Refund Rules:
1. All loans must be closed first
2. All savings must be withdrawn or transferred
3. Any penalties/dues deducted from share value
4. Net amount paid to member

POST /api/v1/shares/accounts/{memberId}/refund
{
  "reason": "Member exit",
  "sharesToRefund": 50,
  "deductions": [
    { "reason": "Outstanding dues", "amount": 500 }
  ]
}

Accounting Entry:
  Dr  Share Capital             5,000.00
  Cr  Cash in Hand              4,500.00
  Cr  Other Income (dues)         500.00
```

---

## Dividend Calculation

At year end, the cooperative pays dividend on share capital:

```
Example:
  Surplus available for dividend: NPR 5,00,000
  Dividend rate declared: 15%

Member: Ram Shrestha
  Shares held: 50
  Share value: NPR 5,000
  Dividend = 5,000 × 15% = NPR 750.00

This is posted as:
  Dr  Dividend Expense         NPR 750
  Cr  Member Savings Account   NPR 750  (credited to savings)
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/shares/accounts` | SHARES_VIEW | List all share accounts |
| GET | `/shares/accounts/{memberId}` | SHARES_VIEW | Member's share account |
| POST | `/shares/accounts/{memberId}/purchase` | SHARES_PURCHASE | Buy shares |
| POST | `/shares/accounts/{memberId}/refund` | SHARES_REFUND | Refund shares |
| POST | `/shares/accounts/{memberId}/transfer` | SHARES_TRANSFER | Transfer shares |
| GET | `/shares/accounts/{memberId}/certificate` | SHARES_CERTIFICATE | Download PDF certificate |
| POST | `/shares/dividend/calculate` | SHARES_DIVIDEND | Preview dividend calculation |
| POST | `/shares/dividend/post` | SHARES_DIVIDEND | Post dividend to all members |
| GET | `/shares/summary` | SHARES_VIEW | Total share capital summary |
