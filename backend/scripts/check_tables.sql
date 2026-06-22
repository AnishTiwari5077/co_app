SELECT 
  (SELECT COUNT(*) FROM "Members") as members,
  (SELECT COUNT(*) FROM "Loans") as loans,
  (SELECT COUNT(*) FROM "SavingAccounts") as saving_accounts,
  (SELECT COUNT(*) FROM "SavingTransactions") as saving_txns;
