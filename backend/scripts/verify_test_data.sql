SELECT
  (SELECT COUNT(*) FROM "Members" WHERE "MemberCode" LIKE 'TEST-%') AS test_members,
  (SELECT COUNT(*) FROM "SavingAccounts" sa
   JOIN "Members" m ON m."Id" = sa."MemberId"
   WHERE m."MemberCode" LIKE 'TEST-%') AS saving_accounts,
  (SELECT COUNT(*) FROM "SavingTransactions" st
   JOIN "SavingAccounts" sa ON sa."Id" = st."AccountId"
   JOIN "Members" m ON m."Id" = sa."MemberId"
   WHERE m."MemberCode" LIKE 'TEST-%') AS transactions,
  (SELECT COUNT(*) FROM "SavingTransactions" st
   JOIN "SavingAccounts" sa ON sa."Id" = st."AccountId"
   JOIN "Members" m ON m."Id" = sa."MemberId"
   WHERE m."MemberCode" LIKE 'TEST-%'
     AND st."TransactionType" = 'Withdrawal') AS withdrawals,
  (SELECT COUNT(*) FROM "Loans" WHERE "LoanNumber" LIKE 'TEST-LN-%') AS loans;
