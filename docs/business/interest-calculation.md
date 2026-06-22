# SahakariMS — Interest Calculation

## Overview

Interest calculation is the most critical financial operation in a cooperative. SahakariMS implements industry-standard methods for savings interest, fixed deposit interest, and loan interest.

---

## 1. Savings Interest (Daily Product Method)

The **daily product method** is the standard approach used by Nepal's cooperatives and banks.

### Formula

```
Daily Interest = (Daily Closing Balance × Annual Rate) / (365 × 100)
Monthly Interest = Sum of Daily Interest for all days in the month
```

### Example

| Date | Opening | Deposit | Withdrawal | Closing | Daily Interest (7.5% p.a.) |
|------|---------|---------|-----------|---------|---------------------------|
| 2081-04-01 | 0 | 10,000 | 0 | 10,000 | 10,000 × 7.5 / (365 × 100) = 2.0548 |
| 2081-04-02 | 10,000 | 5,000 | 0 | 15,000 | 15,000 × 7.5 / (365 × 100) = 3.0822 |
| 2081-04-03 | 15,000 | 0 | 3,000 | 12,000 | 12,000 × 7.5 / (365 × 100) = 2.4658 |
| ... | ... | ... | ... | ... | ... |

**Monthly Interest Total** = Sum of all daily interest = Posted to account on last day of month

### Implementation

```csharp
public class InterestCalculationService : IInterestCalculationService
{
    public decimal CalculateDailyInterest(decimal balance, decimal annualRatePercent, bool isLeapYear)
    {
        if (balance <= 0 || annualRatePercent <= 0) return 0;
        int daysInYear = isLeapYear ? 366 : 365;
        return Math.Round(balance * annualRatePercent / (daysInYear * 100), 4);
    }

    public decimal CalculateMonthlyInterest(
        IEnumerable<DailyBalance> dailyBalances,
        decimal annualRatePercent,
        int year)
    {
        bool isLeapYear = DateTime.IsLeapYear(year);
        return dailyBalances.Sum(db => CalculateDailyInterest(db.Balance, annualRatePercent, isLeapYear));
    }
}
```

### Interest Posting Frequencies

| Frequency | When Posted |
|-----------|-------------|
| Monthly | Last day of each calendar month |
| Quarterly | Last day of Poush, Chaitra, Ashadh, Ashwin (BS) |
| Yearly | Last day of Chaitra (BS fiscal year end) |
| On Maturity | Only when RD/FD matures |

---

## 2. Fixed Deposit Interest

### Formula

```
Total Interest = Principal × Annual Rate × Tenure (days) / (365 × 100)
```

For monthly interest payment:
```
Monthly Interest = Principal × Annual Rate / (12 × 100)
```

### Example

```
Principal:     NPR 500,000
Rate:          12% per annum
Tenure:        365 days

Total Interest = 500,000 × 12 × 365 / (365 × 100)
              = 500,000 × 12 / 100
              = NPR 60,000

Monthly Interest = 500,000 × 12 / (12 × 100)
                 = NPR 5,000/month
```

### Premature Closure Penalty

```
Penalty Rate = 1% to 2% (configurable per scheme)
Effective Rate = FD Rate - Penalty Rate
Actual Interest = Principal × Effective Rate × Actual Tenure / (365 × 100)
Penalty Amount = (Normal Interest - Actual Interest)
```

### Implementation

```csharp
public decimal CalculateFDInterest(
    decimal principal,
    decimal annualRatePercent,
    DateTime startDate,
    DateTime maturityDate)
{
    int days = (maturityDate - startDate).Days;
    bool isLeapYear = DateTime.IsLeapYear(startDate.Year);
    int daysInYear = isLeapYear ? 366 : 365;
    return Math.Round(principal * annualRatePercent * days / (daysInYear * 100), 2);
}

public PrematureClosureResult CalculatePrematureClosure(
    FixedDeposit fd,
    DateTime closureDate,
    decimal penaltyRatePercent)
{
    decimal effectiveRate = fd.InterestRate - penaltyRatePercent;
    effectiveRate = Math.Max(effectiveRate, 0);

    decimal actualInterest = CalculateFDInterest(
        fd.Principal, effectiveRate, fd.OpenDate, closureDate);

    decimal normalInterest = CalculateFDInterest(
        fd.Principal, fd.InterestRate, fd.OpenDate, closureDate);

    return new PrematureClosureResult
    {
        Principal = fd.Principal,
        ActualInterest = actualInterest,
        PenaltyAmount = normalInterest - actualInterest,
        NetPayable = fd.Principal + actualInterest
    };
}
```

---

## 3. Loan Interest

### Method A: Reducing Balance (Recommended)

The outstanding principal reduces with each EMI payment, so interest is calculated on the reducing balance.

#### EMI Formula

```
EMI = P × r × (1 + r)^n / ((1 + r)^n - 1)

Where:
  P = Principal (loan amount)
  r = Monthly interest rate = Annual Rate / (12 × 100)
  n = Tenure in months
```

#### Example

```
Principal (P):  NPR 500,000
Annual Rate:    14%
Tenure (n):     60 months
Monthly Rate (r): 14 / (12 × 100) = 0.011667

EMI = 500,000 × 0.011667 × (1.011667)^60 / ((1.011667)^60 - 1)
    = 500,000 × 0.011667 × 1.9739 / (1.9739 - 1)
    = 500,000 × 0.023027 / 0.9739
    = NPR 11,633.79 per month
```

#### EMI Schedule (First 3 months)

| Month | Opening | Interest | Principal | EMI | Closing |
|-------|---------|---------|----------|-----|---------|
| 1 | 500,000 | 5,833.33 | 5,800.46 | 11,633.79 | 494,199.54 |
| 2 | 494,199.54 | 5,765.66 | 5,868.13 | 11,633.79 | 488,331.41 |
| 3 | 488,331.41 | 5,697.20 | 5,936.59 | 11,633.79 | 482,394.82 |

#### Implementation

```csharp
public List<LoanScheduleItem> GenerateReducingBalanceSchedule(
    decimal principal,
    decimal annualRatePercent,
    int tenureMonths,
    DateTime firstEmiDate)
{
    decimal monthlyRate = annualRatePercent / (12 * 100);
    decimal emi = CalculateEMI(principal, monthlyRate, tenureMonths);
    decimal balance = principal;
    var schedule = new List<LoanScheduleItem>();

    for (int i = 1; i <= tenureMonths; i++)
    {
        decimal interest = Math.Round(balance * monthlyRate, 4);
        decimal principalPortion = Math.Round(emi - interest, 4);

        // Last EMI adjustment for rounding
        if (i == tenureMonths)
            principalPortion = balance;

        schedule.Add(new LoanScheduleItem
        {
            EmiNumber = i,
            DueDate = firstEmiDate.AddMonths(i - 1),
            OpeningBalance = balance,
            InterestAmount = interest,
            PrincipalAmount = principalPortion,
            EmiAmount = i == tenureMonths ? interest + principalPortion : emi,
            ClosingBalance = balance - principalPortion
        });

        balance -= principalPortion;
    }

    return schedule;
}

private decimal CalculateEMI(decimal principal, decimal monthlyRate, int tenure)
{
    double r = (double)monthlyRate;
    double factor = Math.Pow(1 + r, tenure);
    return Math.Round((decimal)(principal * (decimal)r * (decimal)factor / (decimal)(factor - 1)), 2);
}
```

### Method B: Flat Rate

Interest is calculated on the original principal throughout the tenure.

```
Monthly Interest = Principal × Annual Rate / (12 × 100)
Monthly Principal = Principal / Tenure Months
Monthly EMI = Monthly Principal + Monthly Interest
```

#### Example

```
Principal:  NPR 500,000
Rate:       14% flat
Tenure:     60 months

Monthly Interest:  500,000 × 14 / (12 × 100) = 5,833.33
Monthly Principal: 500,000 / 60 = 8,333.33
Monthly EMI:       8,333.33 + 5,833.33 = 14,166.67

Note: Flat rate EMI is higher than reducing balance for same rate.
Effective annual rate of 14% flat ≈ 26-27% reducing balance.
```

---

## 4. Penalty Interest

Penalty interest is charged when EMI payment is delayed beyond the grace period.

### Formula

```
Penalty per Day = Overdue Amount × Penalty Rate / (365 × 100)
Total Penalty = Penalty per Day × Overdue Days

Grace Period: 7 days (configurable)
Penalty Rate: e.g., 2% per annum above loan rate
```

### Example

```
EMI Due Date:    2081-04-01
Payment Date:    2081-04-20
Overdue Days:    20 - 7 (grace) = 13 days
Overdue Amount:  NPR 11,633.79
Penalty Rate:    2% p.a.

Daily Penalty = 11,633.79 × 2 / (365 × 100) = 0.6374
Total Penalty = 0.6374 × 13 = NPR 8.29
```

---

## 5. Share Dividend Calculation

```
Dividend = (Shares Held × Share Value × Dividend Rate × Days Held) / (365 × 100)

Or simplified if rate is per share:
Dividend = Shares Held × Dividend Amount Per Share
```

### Example

```
Member holds: 500 shares
Share Value:  NPR 100 per share
Dividend Rate: 15% per annum
Held all year: 365 days

Dividend = 500 × 100 × 15 × 365 / (365 × 100)
         = 500 × 100 × 15 / 100
         = NPR 7,500
```

---

## 6. Auto Interest Posting Job

The background job runs at midnight and:

1. Fetches all active savings accounts with monthly interest frequency
2. For each account, calculates the day's interest
3. Accumulates in `accrued_interest` field
4. On the last day of the month, posts accrued interest to the account
5. Creates an accounting voucher for each posting
6. Sends SMS notification to member

```csharp
// Hangfire background job
[DisableConcurrentExecution(timeoutInSeconds: 300)]
public class DailyInterestAccrualJob
{
    public async Task ExecuteAsync()
    {
        var activeAccounts = await _savingRepo.GetActiveAccountsForInterestAsync();

        foreach (var account in activeAccounts)
        {
            var dailyInterest = _interestService.CalculateDailyInterest(
                account.CurrentBalance,
                account.InterestRate,
                DateTime.IsLeapYear(DateTime.Today.Year));

            await _savingRepo.AccrueInterestAsync(account.Id, dailyInterest);

            // Post on last day of month
            if (IsLastDayOfMonth(DateTime.Today))
            {
                await _interestService.PostMonthlyInterestAsync(account.Id);
            }
        }
    }
}
```
