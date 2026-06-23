SELECT 'Members' AS table_name, COUNT(*) AS rows FROM "Members"
UNION ALL SELECT 'Loans', COUNT(*) FROM "Loans"
UNION ALL SELECT 'SavingAccounts', COUNT(*) FROM "SavingAccounts"
UNION ALL SELECT 'SavingTransactions', COUNT(*) FROM "SavingTransactions"
UNION ALL SELECT 'LoanEmiSchedules', COUNT(*) FROM "LoanEmiSchedules"
UNION ALL SELECT 'Users (kept)', COUNT(*) FROM "Users"
UNION ALL SELECT 'LoanProducts (kept)', COUNT(*) FROM "LoanProducts"
UNION ALL SELECT 'SavingSchemes (kept)', COUNT(*) FROM "SavingSchemes"
UNION ALL SELECT 'Branches (kept)', COUNT(*) FROM "Branches";
