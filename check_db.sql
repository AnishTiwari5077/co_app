SELECT "Id", "AccountCode", "AccountName", "CurrentBalance" FROM "ChartOfAccounts" WHERE "AccountCode" IN ('100', '1000', '60000000000000');
SELECT "Id", "VoucherNumber", "Status", "IsBalanced" FROM "Vouchers";
SELECT "AccountId", "EntryType", "Amount" FROM "VoucherEntries";
