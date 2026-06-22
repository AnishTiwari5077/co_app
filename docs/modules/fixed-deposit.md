# SahakariMS — Module: Fixed Deposits

## Overview

The Fixed Deposit module manages member term deposits with guaranteed interest rates. FDs are the highest-interest saving product offered by cooperatives and are a key source of member trust and asset growth.

---

## FD Types

| Type | Description | Typical Rate |
|------|-------------|-------------|
| Regular FD | Standard fixed term deposit | 10–13% |
| Senior Citizen FD | Special rate for 60+ members | +0.5% bonus |
| Women FD | Special scheme for women | +0.5% bonus |
| Reinvestment FD | Interest compounded quarterly | Compound rate |

---

## FD Lifecycle

```
Application → Created → Active → Matured → Closed
                                      ↘ Auto-Renewed (if enabled)
                   ↘ Premature Closure (penalty applies)
```

---

## FD Account Number Format

```
FD-{BRANCH_CODE}-{YEAR_BS}-{SEQUENCE}
Example: FD-KTM-2081-00089
```

---

## Creating an FD

```json
POST /api/v1/savings/fd
{
  "memberId": "uuid",
  "schemeId": "uuid",
  "principal": 500000.00,
  "tenureMonths": 12,
  "interestMode": "Monthly",
  "interestCreditAccountId": "uuid",
  "autoRenew": false,
  "nomineeId": "uuid"
}

Response:
{
  "fdNumber": "FD-KTM-2081-00089",
  "principal": 500000.00,
  "interestRate": 12.0,
  "tenureMonths": 12,
  "openingDate": "2081-04-15",
  "maturityDate": "2082-04-15",
  "monthlyInterest": 5000.00,
  "maturityAmount": 560000.00,
  "autoRenew": false
}

Accounting Entry:
  Dr  Cash in Hand               500,000
  Cr  Fixed Deposit Account      500,000
```

---

## Interest Calculation

```
Simple Interest:
  Interest = Principal × Rate × Tenure / (12 × 100)

NPR 5,00,000 @ 12% for 12 months:
  Annual Interest = 5,00,000 × 12 / 100 = NPR 60,000
  Monthly Interest = 60,000 / 12 = NPR 5,000

Monthly Interest Posting:
  Dr  FD Interest Expense        5,000
  Cr  FD Interest Payable        5,000

  When credited to account:
  Dr  FD Interest Payable        5,000
  Cr  Member Savings Account     5,000
```

---

## Premature Closure

```
Normal rate: 12% p.a.
Penalty: 2% (deducted from earned interest only)
Effective rate: 10%

Closed after 8 months (240 days):

Normal interest = 5,00,000 × 12% × 240/365 = NPR 39,452.05
Effective interest = 5,00,000 × 10% × 240/365 = NPR 32,876.71
Penalty = NPR 6,575.34

Payout = 5,00,000 + 32,876.71 = NPR 5,32,876.71

Accounting:
  Dr  Fixed Deposit Account      5,00,000.00
  Dr  FD Interest Payable          32,876.71
  Dr  FD Premature Penalty (Exp)    6,575.34
  Cr  Cash in Hand               5,32,876.71
  Cr  Penalty Income               6,575.34
```

---

## Maturity Processing (Hangfire Job)

```csharp
// Background/Jobs/FdMaturityJob.cs
[DisableConcurrentExecution(300)]
public class FdMaturityJob
{
    public async Task ExecuteAsync()
    {
        var today = DateOnly.FromDateTime(DateTime.Today);
        var maturingFDs = await _fdRepo.GetMaturingTodayAsync(today);

        foreach (var fd in maturingFDs)
        {
            try
            {
                if (fd.AutoRenew)
                {
                    // Create new FD with same terms, same principal
                    await _fdService.AutoRenewAsync(fd.Id);
                    _logger.LogInformation("FD {FdNumber} auto-renewed", fd.FdNumber);
                }
                else
                {
                    // Credit maturity amount to linked savings account
                    await _fdService.MatureAsync(fd.Id);

                    // Send maturity notification
                    await _notificationService.SendFdMaturityNotificationAsync(fd);

                    _logger.LogInformation("FD {FdNumber} matured. Amount: {Amount}",
                        fd.FdNumber, fd.MaturityAmount);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing FD maturity for {FdId}", fd.Id);
                // Don't throw — process remaining FDs
            }
        }
    }
}
```

---

## FD Certificate

```
FIXED DEPOSIT CERTIFICATE
══════════════════════════════════════════════

Certificate No: FDC-KTM-2081-00089
Branch: Kathmandu Main Branch

This certifies that

  RAM BAHADUR SHRESTHA
  Member Code: KTM-2081-00001
  Citizenship No: 01-01-75-12345

has deposited with us

  Principal Amount:    NPR 5,00,000.00
  Interest Rate:       12.00% per annum
  Tenure:              12 months
  Opening Date:        2081-04-15
  Maturity Date:       2082-04-15
  Monthly Interest:    NPR 5,000.00
  Maturity Amount:     NPR 5,60,000.00

Interest credited to: SAV-KTM-2081-456 (monthly)

Auto-renewal: No

[QR code for verification]      Branch Manager Signature
══════════════════════════════════════════════
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/savings/fd` | SAVINGS_VIEW | List all FDs |
| POST | `/savings/fd` | SAVINGS_VIEW | Create new FD |
| GET | `/savings/fd/{id}` | SAVINGS_VIEW | FD details |
| GET | `/savings/fd/{id}/certificate` | SAVINGS_VIEW | Download FD certificate |
| POST | `/savings/fd/{id}/close-premature` | SAVINGS_CLOSE | Premature closure |
| POST | `/savings/fd/{id}/close-mature` | SAVINGS_CLOSE | Maturity closure |
| POST | `/savings/fd/{id}/renew` | SAVINGS_VIEW | Manual renewal |
| GET | `/savings/fd/maturing-soon` | SAVINGS_VIEW | FDs maturing in 30 days |
