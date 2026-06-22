# SahakariMS — Module: Dashboard

## Overview

The Dashboard is the first screen users see after login. It provides a real-time operational overview tailored to the user's role and branch. Data refreshes every 60 seconds and is cached in Redis.

---

## Role-Based Dashboard Views

### Admin / Head Office View

```
┌─────────────────────────────────────────────────────────────┐
│                   SAHAKARIMS DASHBOARD                       │
│                 Fiscal Year 2081/82                          │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│  Members │  Savings │  Loans   │   Cash   │  Profit (YTD)   │
│  1,250   │ NPR 4.5Cr│ NPR 7.8Cr│ NPR 8.5L │  NPR 24.5L      │
│  +12 MTD │  ↑2.3%   │  ↑1.1%   │          │                 │
├──────────┴──────────┴──────────┴──────────┴─────────────────┤
│                                                             │
│  Branch-wise Performance (Bar Chart)                        │
│  ┌─────┬─────┬─────┬─────┐                                 │
│  │ KTM │ PKR │ BRT │ DNG │                                  │
│  │████ │███  │██   │████ │   ← Loan recovery rate          │
│  └─────┴─────┴─────┴─────┘                                 │
│                                                             │
├─────────────────────────┬───────────────────────────────────┤
│  NPA Summary            │   Recent Alerts                   │
│  Standard:  95.2%       │  ⚠ KTM: 3 loans overdue 90+ days │
│  Watchlist:  2.5%       │  ⚠ PKR: FD maturity tomorrow      │
│  Substandard: 1.3%      │  ℹ New member approval pending    │
│  Doubtful:   0.7%       │                                   │
│  Loss:       0.3%       │                                   │
└─────────────────────────┴───────────────────────────────────┘
```

### Branch Manager View

```
Today's Summary (Kathmandu Branch — 2081-04-15)

Total Deposits:          NPR 2,45,000
Total Withdrawals:       NPR  85,000
Net Collection:          NPR 1,60,000
Loan Repayments:         NPR  65,000
Cash Position:           NPR 8,50,000

Pending Approvals:
  • Member approvals:  3
  • Loan approvals:    2
  • Large withdrawal:  1

Today's EMI Due:        45 members — NPR 5,23,530 expected

Alerts:
  ⚠ 5 EMIs overdue (> 30 days)
  ⚠ 1 FD matures in 3 days
```

### Cashier View

```
CASH COUNTER STATUS
Session: Open since 09:00 AM

Cash Position
  Opening:    NPR 1,50,000
  Deposits:   NPR 2,45,000
  Withdrawals:  NPR 85,000
  EMI:          NPR 65,000
  Expected:   NPR 3,75,000

Today: 67 transactions processed

Quick links:
  [New Deposit] [Withdrawal] [EMI Payment] [Counter Close]
```

---

## Backend Implementation

```csharp
// Application/Dashboard/Queries/GetDashboardSummaryQueryHandler.cs
public class GetDashboardSummaryQueryHandler
    : IRequestHandler<GetDashboardSummaryQuery, DashboardSummaryDto>
{
    private readonly IDistributedCache _cache;
    private readonly IDashboardRepository _repo;

    public async Task<DashboardSummaryDto> Handle(
        GetDashboardSummaryQuery query, CancellationToken ct)
    {
        // Cache key per branch per minute
        var cacheKey = $"dashboard:branch:{query.BranchId}:{DateTime.UtcNow:yyyyMMddHHmm}";

        var cached = await _cache.GetStringAsync(cacheKey, ct);
        if (cached is not null)
            return JsonSerializer.Deserialize<DashboardSummaryDto>(cached)!;

        // Fetch from DB (optimized single query)
        var summary = await _repo.GetBranchSummaryAsync(query.BranchId, ct);

        // Cache for 60 seconds
        await _cache.SetStringAsync(cacheKey,
            JsonSerializer.Serialize(summary),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(60) },
            ct);

        return summary;
    }
}
```

```sql
-- Optimized dashboard query (runs in < 50ms on typical dataset)
SELECT
    (SELECT COUNT(*) FROM members WHERE branch_id = @branchId AND status = 'Active' AND is_deleted = FALSE) AS active_members,
    (SELECT COUNT(*) FROM members WHERE branch_id = @branchId AND created_at >= date_trunc('month', NOW()) AND is_deleted = FALSE) AS new_members_month,
    (SELECT COALESCE(SUM(current_balance), 0) FROM saving_accounts WHERE branch_id = @branchId AND status = 'Active' AND is_deleted = FALSE) AS total_savings,
    (SELECT COALESCE(SUM(outstanding_balance), 0) FROM loans WHERE branch_id = @branchId AND status IN ('Active','Overdue') AND is_deleted = FALSE) AS total_loan_outstanding,
    (SELECT COALESCE(SUM(amount), 0) FROM saving_transactions WHERE branch_id = @branchId AND txn_type = 'Deposit' AND transaction_date_ad = CURRENT_DATE) AS today_deposits,
    (SELECT COALESCE(SUM(amount), 0) FROM saving_transactions WHERE branch_id = @branchId AND txn_type = 'Withdrawal' AND transaction_date_ad = CURRENT_DATE) AS today_withdrawals,
    (SELECT COUNT(*) FROM loans WHERE branch_id = @branchId AND status = 'Overdue' AND is_deleted = FALSE) AS overdue_loans,
    (SELECT COUNT(*) FROM members WHERE branch_id = @branchId AND status = 'Pending' AND is_deleted = FALSE) AS pending_member_approvals,
    (SELECT COUNT(*) FROM loans WHERE branch_id = @branchId AND status IN ('Pending','UnderReview') AND is_deleted = FALSE) AS pending_loan_approvals;
```

---

## Charts and Visualizations

### Monthly Transaction Volume (Line Chart)

```dart
// lib/dashboard/widgets/monthly_volume_chart.dart
LineChartData _buildChartData(List<MonthlyVolume> data) {
  return LineChartData(
    gridData: FlGridData(show: true, drawVerticalLine: false),
    borderData: FlBorderData(show: false),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, _) => Text(
            data[value.toInt()].month,
            style: AppTextStyles.labelSmall,
          ),
        ),
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: data.asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), e.value.deposits / 100000)).toList(),
        color: AppColors.creditAmount,
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
      LineChartBarData(
        spots: data.asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), e.value.withdrawals / 100000)).toList(),
        color: AppColors.debitAmount,
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
    ],
  );
}
```

### NPA Donut Chart

```dart
PieChartData _buildNPAChart(NPASummary npa) {
  return PieChartData(
    sections: [
      PieChartSectionData(
        value: npa.standardPercent,
        title: '${npa.standardPercent.toStringAsFixed(1)}%',
        color: AppColors.success,
        radius: 60,
      ),
      PieChartSectionData(
        value: npa.watchlistPercent,
        color: AppColors.warning,
        radius: 55,
      ),
      PieChartSectionData(
        value: npa.substandardPercent,
        color: Colors.orange,
        radius: 55,
      ),
      PieChartSectionData(
        value: npa.doubtfulPercent,
        color: Colors.deepOrange,
        radius: 55,
      ),
      PieChartSectionData(
        value: npa.lossPercent,
        color: AppColors.error,
        radius: 50,
      ),
    ],
    centerSpaceRadius: 40,
  );
}
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/dashboard/summary` | Any | Branch dashboard summary |
| GET | `/dashboard/head-office` | ADMIN | Multi-branch overview |
| GET | `/dashboard/cashier` | CASHIER | Cashier counter view |
| GET | `/dashboard/charts/monthly-volume` | Any | Monthly transaction chart data |
| GET | `/dashboard/charts/npa` | LOANS_VIEW | NPA breakdown |
| GET | `/dashboard/alerts` | Any | Alerts and notifications |
| GET | `/dashboard/pending-approvals` | MANAGER | Items awaiting approval |
| GET | `/dashboard/today-emi` | LOANS_VIEW | Today's due EMIs |
