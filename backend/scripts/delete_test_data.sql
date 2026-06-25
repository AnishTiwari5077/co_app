-- =============================================================================
-- DELETE ALL TEST DATA
-- Removes all records tagged with 'TEST-' prefix that were inserted by
-- insert_test_data.sql. Safe — does NOT touch real member data.

--   psql ... -f backend/scripts/delete_test_data.sql

-- =============================================================================

DO $$
DECLARE
  v_members_deleted INT;
  v_loans_deleted   INT;
  v_accounts_deleted INT;
  v_txns_deleted    INT;
BEGIN
  RAISE NOTICE 'Deleting test data...';

  -- 0. Delete bulk stress-test transactions (BULKTXN- tagged)
  DELETE FROM "SavingTransactions" WHERE "ReceiptNumber" LIKE 'BULKTXN-%';
  RAISE NOTICE 'Bulk transactions deleted.';

  -- 1. Delete loan payments for test loans
  DELETE FROM "LoanPayments"
  WHERE "LoanId" IN (
    SELECT "Id" FROM "Loans" WHERE "LoanNumber" LIKE 'TEST-LN-%'
  );

  -- 2. Delete EMI schedules for test loans
  DELETE FROM "LoanEmiSchedules"
  WHERE "LoanId" IN (
    SELECT "Id" FROM "Loans" WHERE "LoanNumber" LIKE 'TEST-LN-%'
  );

  -- 3. Delete loan guarantors & collaterals for test loans
  DELETE FROM "LoanGuarantors"
  WHERE "LoanId" IN (
    SELECT "Id" FROM "Loans" WHERE "LoanNumber" LIKE 'TEST-LN-%'
  );
  DELETE FROM "LoanCollaterals"
  WHERE "LoanId" IN (
    SELECT "Id" FROM "Loans" WHERE "LoanNumber" LIKE 'TEST-LN-%'
  );

  -- 4. Delete test loans
  DELETE FROM "Loans" WHERE "LoanNumber" LIKE 'TEST-LN-%';
  GET DIAGNOSTICS v_loans_deleted = ROW_COUNT;

  -- 5. Delete saving transactions for test accounts
  DELETE FROM "SavingTransactions"
  WHERE "AccountId" IN (
    SELECT sa."Id"
    FROM "SavingAccounts" sa
    INNER JOIN "Members" m ON m."Id" = sa."MemberId"
    WHERE m."MemberCode" LIKE 'TEST-%'
  );
  GET DIAGNOSTICS v_txns_deleted = ROW_COUNT;

  -- 6. Delete saving accounts for test members
  DELETE FROM "SavingAccounts"
  WHERE "MemberId" IN (
    SELECT "Id" FROM "Members" WHERE "MemberCode" LIKE 'TEST-%'
  );
  GET DIAGNOSTICS v_accounts_deleted = ROW_COUNT;

  -- 7. Delete test members themselves
  DELETE FROM "Members" WHERE "MemberCode" LIKE 'TEST-%';
  GET DIAGNOSTICS v_members_deleted = ROW_COUNT;

  RAISE NOTICE '✅ Test data deleted:';
  RAISE NOTICE '   Members:      %', v_members_deleted;
  RAISE NOTICE '   Saving Accs:  %', v_accounts_deleted;
  RAISE NOTICE '   Transactions: %', v_txns_deleted;
  RAISE NOTICE '   Loans:        %', v_loans_deleted;
END;
$$;

-- Verify nothing is left
SELECT
  (SELECT COUNT(*) FROM "Members"           WHERE "MemberCode" LIKE 'TEST-%') AS test_members_remaining,
  (SELECT COUNT(*) FROM "Loans"             WHERE "LoanNumber"  LIKE 'TEST-LN-%') AS test_loans_remaining;
