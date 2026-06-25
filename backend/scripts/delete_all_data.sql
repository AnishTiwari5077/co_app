DO 
DECLARE v_count INT;
BEGIN
  RAISE NOTICE 'Starting full data wipe...';
  DELETE FROM "LoanPayments"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'LoanPayments: %', v_count;
  DELETE FROM "LoanEmiSchedules"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'LoanEmiSchedules: %', v_count;
  DELETE FROM "LoanGuarantors"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'LoanGuarantors: %', v_count;
  DELETE FROM "LoanCollaterals"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'LoanCollaterals: %', v_count;
  DELETE FROM "Loans"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'Loans: %', v_count;
  DELETE FROM "SavingTransactions"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'SavingTransactions: %', v_count;
  DELETE FROM "SavingAccounts"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'SavingAccounts: %', v_count;
  DELETE FROM "ShareAccounts"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'ShareAccounts: %', v_count;
  DELETE FROM "MemberNominees"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'MemberNominees: %', v_count;
  DELETE FROM "Members"; GET DIAGNOSTICS v_count = ROW_COUNT; RAISE NOTICE 'Members: %', v_count;
  RAISE NOTICE 'Done!';
END;
;
SELECT (SELECT COUNT(*) FROM "Members") AS members, (SELECT COUNT(*) FROM "Loans") AS loans, (SELECT COUNT(*) FROM "SavingAccounts") AS saving_accounts;
