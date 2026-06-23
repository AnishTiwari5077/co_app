-- =============================================================================
-- Seed: Saving Schemes
-- Table: "SavingSchemes"
-- Run: psql -U postgres -d sahakari_ms -f seed_saving_schemes.sql
-- =============================================================================

-- Idempotent: skip if schemes already exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM "SavingSchemes" WHERE "IsDeleted" = false LIMIT 1) THEN
    RAISE NOTICE 'SavingSchemes already seeded — skipping.';
    RETURN;
  END IF;

  -- ─── 1. Regular Savings (साधारण बचत) ──────────────────────────────────────
  INSERT INTO "SavingSchemes" (
    "Id", "SchemeCode", "SchemeName", "SchemeType",
    "InterestRate", "InterestCalculation", "InterestPosting",
    "MinimumBalance", "MinimumDeposit",
    "MinTenureMonths", "MaxTenureMonths",
    "WithdrawalAllowed", "WithdrawalNoticeDays",
    "IsActive", "IsDeleted",
    "CreatedAt", "UpdatedAt"
  ) VALUES (
    gen_random_uuid(), 'REG-001', 'साधारण बचत (Regular Savings)', 'Regular',
    6.00, 'Daily', 'Quarterly',
    500, 100,
    NULL, NULL,
    true, 0,
    true, false,
    NOW(), NOW()
  );

  -- ─── 2. Junior Savings (बाल बचत) ──────────────────────────────────────────
  INSERT INTO "SavingSchemes" (
    "Id", "SchemeCode", "SchemeName", "SchemeType",
    "InterestRate", "InterestCalculation", "InterestPosting",
    "MinimumBalance", "MinimumDeposit",
    "MinTenureMonths", "MaxTenureMonths",
    "WithdrawalAllowed", "WithdrawalNoticeDays",
    "IsActive", "IsDeleted",
    "CreatedAt", "UpdatedAt"
  ) VALUES (
    gen_random_uuid(), 'JNR-001', 'बाल बचत (Junior Savings)', 'Regular',
    7.00, 'Daily', 'Quarterly',
    200, 50,
    NULL, NULL,
    true, 0,
    true, false,
    NOW(), NOW()
  );

  -- ─── 3. Fixed Deposit - 6 Months (६ महिने मुद्दती) ───────────────────────
  INSERT INTO "SavingSchemes" (
    "Id", "SchemeCode", "SchemeName", "SchemeType",
    "InterestRate", "InterestCalculation", "InterestPosting",
    "MinimumBalance", "MinimumDeposit",
    "MinTenureMonths", "MaxTenureMonths",
    "WithdrawalAllowed", "WithdrawalNoticeDays",
    "IsActive", "IsDeleted",
    "CreatedAt", "UpdatedAt"
  ) VALUES (
    gen_random_uuid(), 'FD-006', '६ महिने मुद्दती (FD 6 Months)', 'FixedDeposit',
    9.50, 'Daily', 'Monthly',
    0, 5000,
    6, 6,
    false, 7,
    true, false,
    NOW(), NOW()
  );

  -- ─── 4. Fixed Deposit - 1 Year (१ वर्षे मुद्दती) ─────────────────────────
  INSERT INTO "SavingSchemes" (
    "Id", "SchemeCode", "SchemeName", "SchemeType",
    "InterestRate", "InterestCalculation", "InterestPosting",
    "MinimumBalance", "MinimumDeposit",
    "MinTenureMonths", "MaxTenureMonths",
    "WithdrawalAllowed", "WithdrawalNoticeDays",
    "IsActive", "IsDeleted",
    "CreatedAt", "UpdatedAt"
  ) VALUES (
    gen_random_uuid(), 'FD-012', '१ वर्षे मुद्दती (FD 1 Year)', 'FixedDeposit',
    11.00, 'Daily', 'Monthly',
    0, 5000,
    12, 12,
    false, 15,
    true, false,
    NOW(), NOW()
  );

  -- ─── 5. Fixed Deposit - 2 Years (२ वर्षे मुद्दती) ────────────────────────
  INSERT INTO "SavingSchemes" (
    "Id", "SchemeCode", "SchemeName", "SchemeType",
    "InterestRate", "InterestCalculation", "InterestPosting",
    "MinimumBalance", "MinimumDeposit",
    "MinTenureMonths", "MaxTenureMonths",
    "WithdrawalAllowed", "WithdrawalNoticeDays",
    "IsActive", "IsDeleted",
    "CreatedAt", "UpdatedAt"
  ) VALUES (
    gen_random_uuid(), 'FD-024', '२ वर्षे मुद्दती (FD 2 Years)', 'FixedDeposit',
    12.00, 'Daily', 'Monthly',
    0, 10000,
    24, 24,
    false, 30,
    true, false,
    NOW(), NOW()
  );

  -- ─── 6. Recurring Deposit - Monthly (मासिक बचत) ──────────────────────────
  INSERT INTO "SavingSchemes" (
    "Id", "SchemeCode", "SchemeName", "SchemeType",
    "InterestRate", "InterestCalculation", "InterestPosting",
    "MinimumBalance", "MinimumDeposit",
    "MinTenureMonths", "MaxTenureMonths",
    "WithdrawalAllowed", "WithdrawalNoticeDays",
    "IsActive", "IsDeleted",
    "CreatedAt", "UpdatedAt"
  ) VALUES (
    gen_random_uuid(), 'RD-001', 'मासिक आवर्ती बचत (Monthly Recurring)', 'RecurringDeposit',
    8.50, 'Daily', 'Yearly',
    0, 500,
    12, 60,
    false, 30,
    true, false,
    NOW(), NOW()
  );

  -- ─── 7. Senior Citizen Savings (जेष्ठ नागरिक बचत) ───────────────────────
  INSERT INTO "SavingSchemes" (
    "Id", "SchemeCode", "SchemeName", "SchemeType",
    "InterestRate", "InterestCalculation", "InterestPosting",
    "MinimumBalance", "MinimumDeposit",
    "MinTenureMonths", "MaxTenureMonths",
    "WithdrawalAllowed", "WithdrawalNoticeDays",
    "IsActive", "IsDeleted",
    "CreatedAt", "UpdatedAt"
  ) VALUES (
    gen_random_uuid(), 'SR-001', 'जेष्ठ नागरिक बचत (Senior Citizen)', 'Regular',
    8.00, 'Daily', 'Quarterly',
    500, 500,
    NULL, NULL,
    true, 0,
    true, false,
    NOW(), NOW()
  );

  RAISE NOTICE 'SavingSchemes seeded successfully — 7 schemes inserted.';
END;
$$;

-- Verify
SELECT "SchemeCode", "SchemeName", "SchemeType", "InterestRate", "MinimumDeposit"
FROM "SavingSchemes"
WHERE "IsDeleted" = false
ORDER BY "SchemeType", "SchemeCode";
