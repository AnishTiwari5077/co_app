-- =============================================================================
-- Insert 1000 Deposits + 1000 Withdrawals for ONE member
-- Target: first TEST- member found in the DB
-- Run:   psql ... -f insert_bulk_transactions.sql
-- Clean: included in delete_test_data.sql (tagged BULKTXN-)
-- =============================================================================

DO $$
DECLARE
  v_account_id   UUID;
  v_branch_id    UUID;
  v_account_no   TEXT;
  v_member_name  TEXT;
  v_fy           INT := 2083;

  i              INT;
  v_bal          NUMERIC := 0;
  v_dep_amt      NUMERIC;
  v_wth_amt      NUMERIC;
  v_rcpt_seq     BIGINT;
  v_rcpt         TEXT;
BEGIN
  -- Pick the first TEST- member's saving account
  SELECT
    sa."Id", sa."BranchId", sa."AccountNumber", sa."CurrentBalance",
    m."FirstName" || ' ' || m."LastName"
  INTO
    v_account_id, v_branch_id, v_account_no, v_bal, v_member_name
  FROM "SavingAccounts" sa
  JOIN "Members" m ON m."Id" = sa."MemberId"
  WHERE m."MemberCode" LIKE 'TEST-%'
    AND sa."Status" = 'Active'
    AND sa."IsDeleted" = false
  ORDER BY sa."CreatedAt"
  LIMIT 1;

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'No TEST- member found. Run insert_test_data.sql first.';
  END IF;

  RAISE NOTICE 'Inserting 2000 transactions for: % (Account: %)', v_member_name, v_account_no;

  -- ── 1000 Deposits ────────────────────────────────────────────────────────────
  FOR i IN 1..1000 LOOP
    v_rcpt_seq := nextval('receipt_number_seq');
    v_rcpt     := 'BULKTXN-DEP-' || LPAD(i::TEXT, 5, '0');
    v_dep_amt  := (500 + (i * 317 % 49500))::NUMERIC;  -- NPR 500 - 50,000
    v_bal      := v_bal + v_dep_amt;

    INSERT INTO "SavingTransactions" (
      "Id","AccountId","BranchId","TransactionType","Amount",
      "BalanceAfter","DepositMode","ReceiptNumber","Narration",
      "TransactionDate","ProcessedBy","IsReversed",
      "CreatedAt","UpdatedAt","IsDeleted"
    ) VALUES (
      gen_random_uuid(), v_account_id, v_branch_id,
      'Deposit', v_dep_amt, v_bal,
      CASE (i % 4)
        WHEN 0 THEN 'Cash'
        WHEN 1 THEN 'Cheque'
        WHEN 2 THEN 'Online'
        ELSE 'Transfer'
      END,
      v_rcpt,
      'Bulk deposit #' || i || ' - stress test',
      NOW() - ((1000 - i + 5) || ' hours')::INTERVAL,
      NULL, false,
      NOW() - ((1000 - i + 5) || ' hours')::INTERVAL,
      NOW() - ((1000 - i + 5) || ' hours')::INTERVAL,
      false
    );

    IF i % 100 = 0 THEN
      RAISE NOTICE 'Deposits: %/1000 done. Balance: NPR %', i, v_bal;
    END IF;
  END LOOP;

  -- ── 1000 Withdrawals ─────────────────────────────────────────────────────────
  FOR i IN 1..1000 LOOP
    v_rcpt_seq := nextval('receipt_number_seq');
    v_rcpt     := 'BULKTXN-WTH-' || LPAD(i::TEXT, 5, '0');

    -- Keep withdrawal small enough to never hit zero (max 30% of current balance)
    v_wth_amt  := LEAST(
      (200 + (i * 211 % 9800))::NUMERIC,   -- NPR 200 - 10,000
      GREATEST(0, v_bal * 0.3)              -- never exceed 30% of balance
    );

    IF v_wth_amt <= 0 THEN
      v_wth_amt := 200;  -- minimum fallback
    END IF;

    v_bal := v_bal - v_wth_amt;

    INSERT INTO "SavingTransactions" (
      "Id","AccountId","BranchId","TransactionType","Amount",
      "BalanceAfter","DepositMode","ReceiptNumber","Narration",
      "TransactionDate","ProcessedBy","IsReversed",
      "CreatedAt","UpdatedAt","IsDeleted"
    ) VALUES (
      gen_random_uuid(), v_account_id, v_branch_id,
      'Withdrawal', v_wth_amt, v_bal,
      CASE (i % 3)
        WHEN 0 THEN 'Cash'
        WHEN 1 THEN 'Cheque'
        ELSE 'Online'
      END,
      v_rcpt,
      'Bulk withdrawal #' || i || ' - stress test',
      NOW() - ((i % 200) || ' minutes')::INTERVAL,
      NULL, false,
      NOW() - ((i % 200) || ' minutes')::INTERVAL,
      NOW() - ((i % 200) || ' minutes')::INTERVAL,
      false
    );

    IF i % 100 = 0 THEN
      RAISE NOTICE 'Withdrawals: %/1000 done. Balance: NPR %', i, v_bal;
    END IF;
  END LOOP;

  -- Update final account balance
  UPDATE "SavingAccounts"
  SET "CurrentBalance" = v_bal, "UpdatedAt" = NOW()
  WHERE "Id" = v_account_id;

  RAISE NOTICE '✅ Done!';
  RAISE NOTICE '   Member:        %',  v_member_name;
  RAISE NOTICE '   Account:       %',  v_account_no;
  RAISE NOTICE '   Deposits:      1000';
  RAISE NOTICE '   Withdrawals:   1000';
  RAISE NOTICE '   Final Balance: NPR %', v_bal;
  RAISE NOTICE '   Receipt tags:  BULKTXN-DEP-##### and BULKTXN-WTH-#####';
  RAISE NOTICE '   To delete run: delete_test_data.sql';
END;
$$;

-- Quick verify
SELECT
  "TransactionType",
  COUNT(*)          AS count,
  MIN("Amount")     AS min_amt,
  MAX("Amount")     AS max_amt,
  SUM("Amount")     AS total
FROM "SavingTransactions"
WHERE "ReceiptNumber" LIKE 'BULKTXN-%'
GROUP BY "TransactionType"
ORDER BY "TransactionType";
