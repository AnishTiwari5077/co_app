-- ═══════════════════════════════════════════════════════════════════════════════
-- Seed: Fiscal Year + Chart of Accounts
-- Nepali cooperative standard accounts
-- Run once: psql -U postgres -d sahakari_db -f seed_accounting.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 1. Fiscal Year 2082/83 BS (Jul 17 2025 – Jul 15 2026) ────────────────────
INSERT INTO "FiscalYears" (
    "Id", "YearCode", "StartDate", "EndDate",
    "IsCurrent", "IsClosed",
    "CreatedAt", "UpdatedAt", "IsDeleted"
)
VALUES (
    gen_random_uuid(),
    '2082-83',
    '2025-07-17',
    '2026-07-15',
    TRUE,
    FALSE,
    NOW(), NOW(), FALSE
)
ON CONFLICT DO NOTHING;

-- ── 2. Chart of Accounts ──────────────────────────────────────────────────────
-- Format: AccountCode | AccountName | AccountType | AccountGroup | AllowDirectPosting | IsControl

-- ── ASSETS ────────────────────────────────────────────────────────────────────
INSERT INTO "ChartOfAccounts"
    ("Id","AccountCode","AccountName","AccountNameNp","AccountType","AccountGroup",
     "IsControl","AllowDirectPosting","CurrentBalance","IsActive","IsDeleted","CreatedAt","UpdatedAt")
VALUES
-- Cash & Bank
(gen_random_uuid(),'1001','Cash in Hand','हातमा नगद','Asset','Cash & Bank',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'1002','Cash at Bank','बैंकमा नगद','Asset','Cash & Bank',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'1003','Petty Cash','साना नगद','Asset','Cash & Bank',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),

-- Loans & Receivables
(gen_random_uuid(),'1101','Loan Receivable - Members','सदस्य कर्जा','Asset','Loans & Receivables',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'1102','Interest Receivable','ब्याज प्राप्य','Asset','Loans & Receivables',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'1103','Penalty Receivable','जरिवाना प्राप्य','Asset','Loans & Receivables',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),

-- Other Assets
(gen_random_uuid(),'1201','Fixed Assets','स्थिर सम्पत्ति','Asset','Fixed Assets',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'1202','Prepaid Expenses','अग्रिम खर्च','Asset','Other Assets',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),

-- ── LIABILITIES ───────────────────────────────────────────────────────────────
-- Member Savings
(gen_random_uuid(),'2001','Member Savings - Regular','नियमित बचत','Liability','Member Savings',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'2002','Member Savings - Fixed Deposit','मुद्दती बचत','Liability','Member Savings',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'2003','Member Savings - Recurring','आवधिक बचत','Liability','Member Savings',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),

-- Other Liabilities
(gen_random_uuid(),'2101','Interest Payable on Savings','बचतमा देय ब्याज','Liability','Other Liabilities',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'2102','Tax Payable (TDS)','कर देय (TDS)','Liability','Other Liabilities',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'2103','Accrued Expenses','उपार्जित खर्च','Liability','Other Liabilities',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),

-- ── EQUITY ────────────────────────────────────────────────────────────────────
(gen_random_uuid(),'3001','Share Capital','शेयर पुँजी','Equity','Capital',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'3002','Retained Earnings','संचित मुनाफा','Equity','Capital',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'3003','General Reserve','सामान्य जगेडा','Equity','Capital',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),

-- ── INCOME ────────────────────────────────────────────────────────────────────
(gen_random_uuid(),'4001','Interest Income on Loans','कर्जामा ब्याज आय','Income','Interest Income',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'4002','Penalty Income','जरिवाना आय','Income','Fee Income',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'4003','Membership Fee Income','सदस्यता शुल्क आय','Income','Fee Income',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'4004','Processing Fee Income','प्रशोधन शुल्क','Income','Fee Income',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'4005','Miscellaneous Income','विविध आय','Income','Other Income',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),

-- ── EXPENSES ──────────────────────────────────────────────────────────────────
(gen_random_uuid(),'5001','Interest Expense on Savings','बचतमा ब्याज खर्च','Expense','Finance Cost',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'5002','Salary & Allowances','तलब भत्ता','Expense','Staff Cost',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'5003','Office Rent','कार्यालय भाडा','Expense','Operating Expense',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'5004','Stationery & Printing','लेखन सामग्री','Expense','Operating Expense',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'5005','Telephone & Internet','टेलिफोन/इन्टरनेट','Expense','Operating Expense',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'5006','Electricity Charges','बिजुली खर्च','Expense','Operating Expense',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'5007','Depreciation','ह्रास','Expense','Operating Expense',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'5008','Loan Loss Provision','कर्जा नोक्सान व्यवस्था','Expense','Provision',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW()),
(gen_random_uuid(),'5009','Miscellaneous Expense','विविध खर्च','Expense','Operating Expense',FALSE,TRUE,0,TRUE,FALSE,NOW(),NOW())
ON CONFLICT DO NOTHING;

-- ── Verify ────────────────────────────────────────────────────────────────────
SELECT 'Fiscal Years' AS table_name, COUNT(*) FROM "FiscalYears" WHERE "IsDeleted" = FALSE
UNION ALL
SELECT 'Chart of Accounts', COUNT(*) FROM "ChartOfAccounts" WHERE "IsDeleted" = FALSE;
