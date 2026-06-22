# SahakariMS — Module: Reports

## Overview

The Reports module provides financial, operational, and regulatory reports for management, auditors, and Nepal Department of Cooperatives compliance. All reports can be exported as PDF or Excel.

---

## Report Categories

| Category | Reports |
|----------|---------|
| **Daily Operations** | Daily Collection, Cash Position, Today's Transactions |
| **Member** | Member List, KYC Status, COPOMIS Export |
| **Savings** | Account-wise Balance, Interest Posting, Dormant Accounts |
| **Loans** | Loan Outstanding, Defaulters, NPA, Disbursement |
| **Accounting** | Trial Balance, Balance Sheet, P&L, General Ledger |
| **Regulatory** | COPOMIS, PEARLS Ratios, NRB Format |
| **Audit** | Transaction Audit, User Activity |

---

## Daily Collection Report

Shows all transactions processed on a specific date.

```
DAILY COLLECTION REPORT
Branch: Kathmandu Main | Date: 2081-04-15

DEPOSITS
─────────────────────────────────────────────────────────
Time     Member Code   Member Name         Account      Amount
09:15    KTM-081-001   Ram Shrestha        SAV-KTM-456  5,000
09:32    KTM-081-045   Sita Tamang         SAV-KTM-123  2,500
10:01    KTM-081-102   Hari Prasad         SAV-KTM-789  10,000
...
                       Total Deposits:              2,45,000.00

WITHDRAWALS
─────────────────────────────────────────────────────────
...
                       Total Withdrawals:             85,000.00

LOAN REPAYMENTS
─────────────────────────────────────────────────────────
...
                       Total Loan Repayments:         65,000.00

SUMMARY
─────────────────────────────────────────────────────────
Total Cash Inflow:                              3,10,000.00
Total Cash Outflow:                               85,000.00
Net Cash Movement:                             +2,25,000.00
```

---

## Loan Outstanding Report

```
LOAN OUTSTANDING REPORT
Branch: Kathmandu Main | As of: 2081-04-15

Loan No.      Member          Type       Disbursed   Outstanding   EMI Due      Status
LN-2081-001   Ram Shrestha    Business   5,00,000    4,50,000      2081-05-01   Active
LN-2081-002   Sita Tamang     Personal   1,00,000      89,000      2081-05-01   Active
LN-2081-003   Hari Prasad     Business   2,00,000    1,80,000      2081-04-30   Overdue (5 days)
...

SUMMARY
Total Active Loans:       423
Total Outstanding:   NPR 7,85,00,000
Total Overdue:       NPR    45,00,000 (5.7%)
NPA Amount:          NPR    18,00,000 (2.3%)
```

---

## Defaulters Report

Members with overdue EMIs, sorted by overdue amount:

```
DEFAULTERS LIST
As of: 2081-04-15

Member         Loan No.    Overdue  EMI Count   Overdue Amt  Last Payment
Hari Prasad    LN-081-003  5 days   1           11,634       2081-03-01
Kamal Thapa    LN-081-045  95 days  3           34,902       2080-12-15
Ramesh BK      LN-081-089  370 days 12+         NPA-Loss     2079-12-01
```

---

## COPOMIS Export

Nepal Department of Cooperatives requires quarterly COPOMIS data submission.

### Generated Format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<COPOMIS>
  <Header>
    <CooperativeCode>NP-LPR-001234</CooperativeCode>
    <CooperativeName>Sahakari Bachat Tatha Rin Sanstha</CooperativeName>
    <ReportPeriod>2081-Q4</ReportPeriod>
    <GeneratedAt>2081-04-15</GeneratedAt>
  </Header>
  <Members>
    <Member>
      <Code>KTM-2081-00001</Code>
      <Name>Ram Bahadur Shrestha</Name>
      <Gender>M</Gender>
      <DOB>1985-06-15</DOB>
      <CitizenshipNo>01-01-75-12345</CitizenshipNo>
      <SharesHeld>100</SharesHeld>
      <ShareValue>10000</ShareValue>
      <TotalSavings>45000</TotalSavings>
      <LoanOutstanding>0</LoanOutstanding>
      <Status>A</Status>
    </Member>
    ...
  </Members>
  <Portfolio>
    <TotalMembers>1250</TotalMembers>
    <ActiveMembers>1180</ActiveMembers>
    <ShareCapital>12500000</ShareCapital>
    <TotalSavings>45000000</TotalSavings>
    <TotalLoans>78000000</TotalLoans>
    <NPAAmount>1800000</NPAAmount>
    <NPAPercent>2.31</NPAPercent>
  </Portfolio>
</COPOMIS>
```

---

## PEARLS Ratios

PEARLS (Protection, Effective Financial Structure, Asset Quality, Rates of Return, Liquidity, Signs of Growth) is the standard cooperative health monitoring system.

| Ratio | Formula | Ideal Range |
|-------|---------|-------------|
| P1 — Loan Loss Provision | LLP / Delinquent Loans | ≥ 100% |
| E1 — Net Loans / Total Assets | Loans / Assets | 70-80% |
| A1 — Delinquent Loans | Overdue > 30d / Total Loans | < 5% |
| A2 — NPA % | NPA / Total Loans | < 3% |
| R7 — Operating Expense Ratio | Op. Exp / Avg. Assets | < 5% |
| L1 — Liquid Assets | Liquid / Total Savings | ≥ 15% |
| L2 — Short-term Liabilities Coverage | Liquid / STL | ≥ 100% |
| S1 — Member Growth | New Members / Total | > 5% |
| S11 — Institutional Capital | Reserves / Total Assets | ≥ 10% |

---

## PDF Report Generation (Backend)

```csharp
public class PdfReportService : IPdfReportService
{
    public async Task<byte[]> GenerateLoanOutstandingReportAsync(
        Guid branchId, DateOnly asOfDate)
    {
        var data = await _reportRepo.GetLoanOutstandingAsync(branchId, asOfDate);

        using var stream = new MemoryStream();
        var document = new PdfDocument(new PdfWriter(stream));
        var pdf = new Document(document, PageSize.A4.Rotate());

        // Header
        pdf.Add(new Paragraph("LOAN OUTSTANDING REPORT")
            .SetFont(PdfFontFactory.CreateFont(StandardFonts.HELVETICA_BOLD))
            .SetFontSize(16)
            .SetTextAlignment(TextAlignment.CENTER));

        pdf.Add(new Paragraph($"Branch: {data.BranchName} | As of: {asOfDate:yyyy-MM-dd}")
            .SetFontSize(10)
            .SetTextAlignment(TextAlignment.CENTER));

        // Table
        var table = new Table(UnitValue.CreatePercentArray(new[] { 15f, 20f, 15f, 15f, 15f, 10f, 10f }))
            .UseAllAvailableWidth();

        // Table headers
        foreach (var header in new[] { "Loan No.", "Member", "Type", "Disbursed", "Outstanding", "EMI Due", "Status" })
        {
            table.AddHeaderCell(new Cell().Add(new Paragraph(header)
                .SetFont(PdfFontFactory.CreateFont(StandardFonts.HELVETICA_BOLD))));
        }

        foreach (var loan in data.Loans)
        {
            table.AddCell(loan.LoanNumber);
            table.AddCell(loan.MemberName);
            table.AddCell(loan.LoanType);
            table.AddCell(loan.DisbursedAmount.ToNPR());
            table.AddCell(loan.OutstandingBalance.ToNPR());
            table.AddCell(loan.NextEmiDate?.ToString("yyyy-MM-dd") ?? "—");
            table.AddCell(new Cell().Add(new Paragraph(loan.Status)
                .SetFontColor(GetStatusColor(loan.Status))));
        }

        pdf.Add(table);
        pdf.Close();
        return stream.ToArray();
    }
}
```

---

## Excel Export (EPPlus)

```csharp
public async Task<byte[]> GenerateMemberExcelAsync(Guid branchId)
{
    ExcelPackage.LicenseContext = LicenseContext.NonCommercial;
    using var package = new ExcelPackage();
    var sheet = package.Workbook.Worksheets.Add("Members");

    // Headers
    var headers = new[] { "Code", "Name", "Gender", "Phone", "Status", "KYC", "Joined", "Savings", "Loan" };
    for (int i = 0; i < headers.Length; i++)
        sheet.Cells[1, i + 1].Value = headers[i];

    // Style header row
    var headerRange = sheet.Cells[1, 1, 1, headers.Length];
    headerRange.Style.Font.Bold = true;
    headerRange.Style.Fill.PatternType = ExcelFillStyle.Solid;
    headerRange.Style.Fill.BackgroundColor.SetColor(Color.DarkBlue);
    headerRange.Style.Font.Color.SetColor(Color.White);

    // Data
    var members = await _memberRepo.GetAllAsync(branchId);
    int row = 2;
    foreach (var m in members)
    {
        sheet.Cells[row, 1].Value = m.MemberCode;
        sheet.Cells[row, 2].Value = m.FullName;
        sheet.Cells[row, 3].Value = m.Gender.ToString();
        sheet.Cells[row, 4].Value = m.PhonePrimary;
        sheet.Cells[row, 5].Value = m.Status.ToString();
        sheet.Cells[row, 6].Value = m.KycVerified ? "Yes" : "No";
        sheet.Cells[row, 7].Value = m.MembershipDateAd?.ToString("yyyy-MM-dd");
        sheet.Cells[row, 8].Value = m.TotalSavings;
        sheet.Cells[row, 9].Value = m.TotalLoanOutstanding;
        row++;
    }

    sheet.Cells.AutoFitColumns();
    return package.GetAsByteArray();
}
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/reports/daily-collection` | REPORTS_VIEW | Daily collection report |
| GET | `/reports/loan-outstanding` | REPORTS_VIEW | Loan outstanding |
| GET | `/reports/defaulters` | REPORTS_VIEW | Defaulters list |
| GET | `/reports/npa` | REPORTS_VIEW | NPA report |
| GET | `/reports/fd-maturity` | REPORTS_VIEW | FD maturity schedule |
| GET | `/reports/interest-income` | REPORTS_VIEW | Interest income report |
| GET | `/reports/trial-balance` | REPORTS_VIEW | Trial balance |
| GET | `/reports/balance-sheet` | REPORTS_VIEW | Balance sheet |
| GET | `/reports/profit-loss` | REPORTS_VIEW | P&L statement |
| GET | `/reports/cash-position` | REPORTS_VIEW | Cash position |
| GET | `/reports/member-list` | REPORTS_EXPORT | Member list (Excel) |
| GET | `/reports/copomis` | REPORTS_EXPORT | COPOMIS XML |
| GET | `/reports/pearls` | REPORTS_VIEW | PEARLS ratios |
