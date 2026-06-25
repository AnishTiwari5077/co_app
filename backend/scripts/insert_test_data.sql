-- =============================================================================
-- TEST DATA: 1000 Members + Saving Accounts + Sample Loans
-- Run:  psql ... -f insert_test_data.sql
-- Clean: psql ... -f delete_test_data.sql
-- Tag:  All test rows have MemberCode starting with 'TEST-'
-- =============================================================================

DO $$
DECLARE
  v_branch_id   UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_branch_code TEXT := 'HO';
  v_fy          INT  := 2083;

  -- Nepali first names
  first_names   TEXT[] := ARRAY[
    'Aarav','Aayush','Abhishek','Aditya','Ajay','Amit','Anish','Ankit','Anup','Arjun',
    'Ashish','Asmita','Atul','Bibek','Bikash','Binod','Bishnu','Bimal','Chandra','Deepak',
    'Dipa','Dipesh','Ganga','Ganesh','Gaurav','Gita','Hari','Hemanta','Indra','Ishwor',
    'Janak','Janaki','Kamal','Kiran','Krishna','Kumar','Laxmi','Lochan','Manoj','Maya',
    'Milan','Mohan','Nabin','Nagendra','Narayan','Nisha','Nishan','Pawan','Prabesh','Prakash',
    'Prashant','Pratima','Priya','Purna','Rabindra','Raghu','Rajesh','Ram','Ramesh','Ravi',
    'Reena','Ritu','Robin','Rohan','Sabina','Samir','Sanjay','Sanjiv','Santa','Sapana',
    'Sarina','Shambhu','Shiva','Shreya','Sita','Subash','Subin','Sudip','Sujan','Suman',
    'Sunita','Suresh','Surya','Susma','Tej','Tikaram','Umesh','Usha','Yam','Yogesh'
  ];

  -- Nepali last names
  last_names    TEXT[] := ARRAY[
    'Adhikari','Aryal','Bajracharya','Basnet','Bhandari','Bhattarai','Bista','Bohara',
    'Chaudhary','Dangol','Dahal','Dhakal','Gautam','Ghimire','Gurung','Joshi','Karki',
    'Khatri','Koirala','Lama','Limbu','Magar','Maharjan','Mishra','Nepal','Oli','Pandey',
    'Parajuli','Pathak','Paudel','Pradhan','Pun','Rai','Raut','Regmi','Rijal','Sapkota',
    'Shah','Sharma','Shrestha','Silwal','Subedi','Tamang','Thapa','Tiwari','Upreti','Yadav'
  ];

  -- Nepal districts
  districts     TEXT[] := ARRAY[
    'Kathmandu','Lalitpur','Bhaktapur','Chitwan','Pokhara','Kaski',
    'Rupandehi','Palpa','Syangja','Nawalparasi','Gorkha','Lamjung',
    'Tanahu','Makwanpur','Sindhuli','Kavrepalanchok','Dolakha','Sindhupalchok'
  ];

  -- Municipalities
  municipalities TEXT[] := ARRAY[
    'Budhanilkantha','Kirtipur','Chandragiri','Tokha','Gokarneshwor',
    'Kageshwori Manohara','Nagarjun','Tarakeshwor','Tarkeshwor',
    'Bharatpur','Ratnanagar','Kalika','Rapti','Rapti Sonari',
    'Pokhara Lekhnath','Lekhnath','Annapurna','Rupa',
    'Siddharthanagar','Butwal','Devdaha','Tilottama','Sainamaina',
    'Sunwal','Palungtar','Suryabinayak','Madhyapur Thimi'
  ];

  -- Occupations
  occupations   TEXT[] := ARRAY[
    'Farmer','Teacher','Business','Government Service','Private Service',
    'Self Employed','Doctor','Engineer','Lawyer','Banker',
    'Nurse','Driver','Carpenter','Electrician','Plumber'
  ];

  -- Saving scheme IDs (fetched below)
  v_reg_scheme_id UUID;
  v_jnr_scheme_id UUID;

  -- Loop vars
  i             INT;
  v_member_id   UUID;
  v_first       TEXT;
  v_last        TEXT;
  v_gender      TEXT;
  v_phone       TEXT;
  v_alt_phone   TEXT;
  v_dob         DATE;
  v_district    TEXT;
  v_mun         TEXT;
  v_occupation  TEXT;
  v_employer    TEXT;
  v_income      NUMERIC;
  v_citizen_no  TEXT;
  v_pan_no      TEXT;
  v_seq         BIGINT;
  v_member_code TEXT;
  v_acc_id      UUID;
  v_acc_no      TEXT;
  v_acc_seq     BIGINT;
  v_loan_id     UUID;
  v_loan_no     TEXT;
  v_loan_seq    BIGINT;
  v_loan_prod   UUID;

BEGIN
  -- Fetch scheme IDs
  SELECT "Id" INTO v_reg_scheme_id FROM "SavingSchemes" WHERE "SchemeCode" = 'REG-001' AND "IsDeleted" = false LIMIT 1;
  SELECT "Id" INTO v_jnr_scheme_id FROM "SavingSchemes" WHERE "SchemeCode" = 'JNR-001' AND "IsDeleted" = false LIMIT 1;
  SELECT "Id" INTO v_loan_prod     FROM "LoanProducts"  WHERE "ProductCode" = 'PL-001'  AND "IsDeleted" = false LIMIT 1;

  IF v_reg_scheme_id IS NULL THEN
    RAISE EXCEPTION 'REG-001 saving scheme not found. Run seed_saving_schemes.sql first.';
  END IF;

  RAISE NOTICE 'Starting insert of 1000 test members...';

  FOR i IN 1..1000 LOOP
    v_member_id  := gen_random_uuid();
    v_first      := first_names[1 + ((i * 7)   % array_length(first_names, 1))];
    v_last       := last_names [1 + ((i * 13)  % array_length(last_names,  1))];
    v_gender     := CASE WHEN i % 3 = 0 THEN 'Female' ELSE 'Male' END;
    v_phone      := '98' || LPAD(((40000000 + i * 97) % 60000000)::TEXT, 8, '0');
    v_alt_phone  := CASE WHEN i % 5 = 0 THEN '97' || LPAD(((30000000 + i * 53) % 70000000)::TEXT, 8, '0') ELSE NULL END;
    v_dob        := DATE '1970-01-01' + ((i * 13 + 3000) % 18000); -- Ages ~18-60
    v_district   := districts    [1 + (i % array_length(districts,    1))];
    v_mun        := municipalities[1 + (i % array_length(municipalities, 1))];
    v_occupation := occupations  [1 + (i % array_length(occupations,  1))];
    v_employer   := CASE WHEN i % 4 != 0 THEN v_occupation || ' at ' || v_district ELSE NULL END;
    v_income     := (5000 + (i * 317 % 95000))::NUMERIC;
    v_citizen_no := v_district || '-' || LPAD(i::TEXT, 6, '0');
    v_pan_no     := CASE WHEN i % 3 = 0 THEN LPAD((100000000 + i * 7)::TEXT, 9, '0') ELSE NULL END;

    -- Member code with test prefix
    v_seq        := nextval('member_code_seq');
    v_member_code := 'TEST-' || v_branch_code || '-' || v_fy || '-' || LPAD(v_seq::TEXT, 5, '0');

    -- Insert member
    INSERT INTO "Members" (
      "Id","BranchId","MemberCode","FirstName","MiddleName","LastName","Gender",
      "DateOfBirthAd","CitizenshipNumber","CitizenshipIssuedDistrict","CitizenshipIssuedDate",
      "PanNumber","PhoneNumber","AlternatePhone",
      "AddressDistrict","AddressMunicipality","AddressWard","AddressTole",
      "Occupation","EmployerName","MonthlyIncome",
      "Status","KycVerified","MembershipDate",
      "CreatedAt","UpdatedAt","IsDeleted"
    ) VALUES (
      v_member_id, v_branch_id, v_member_code, v_first,
      CASE WHEN i % 4 = 0 THEN 'Prasad' ELSE NULL END,
      v_last, v_gender,
      v_dob, v_citizen_no, v_district,
      v_dob + 18, -- issued date ~18th birthday
      v_pan_no, v_phone, v_alt_phone,
      v_district, v_mun, (1 + i % 32)::TEXT, v_mun || ' Tole-' || (i % 9 + 1),
      v_occupation, v_employer, v_income,
      'Active', true, CURRENT_DATE - (i % 730),
      NOW() - (i % 365 || ' days')::INTERVAL,
      NOW() - (i % 365 || ' days')::INTERVAL,
      false
    );

    -- ── Saving Account (every member gets one) ───────────────────────────────
    v_acc_id  := gen_random_uuid();
    v_acc_seq := nextval('account_number_seq');
    v_acc_no  := 'SAV-' || v_fy || '-' || LPAD(v_acc_seq::TEXT, 5, '0');

    INSERT INTO "SavingAccounts" (
      "Id","MemberId","BranchId","SchemeId","AccountNumber",
      "CurrentBalance","InterestAccrued","Status",
      "OpenDate","IsFrozen",
      "CreatedAt","UpdatedAt","IsDeleted"
    ) VALUES (
      v_acc_id, v_member_id, v_branch_id,
      CASE WHEN i % 10 = 0 THEN v_jnr_scheme_id ELSE v_reg_scheme_id END,
      v_acc_no,
      (500 + (i * 1237 % 200000))::NUMERIC, 0, 'Active',
      CURRENT_DATE - (i % 720),
      false,
      NOW() - (i % 365 || ' days')::INTERVAL,
      NOW() - (i % 365 || ' days')::INTERVAL,
      false
    );

    -- ── Saving Transactions (4-8 per account: mix of deposits & withdrawals) ──
    DECLARE
      v_txn_count INT := 4 + (i % 5);       -- 4 to 8 transactions
      j           INT;
      v_bal       NUMERIC := 500;             -- start low, build up via deposits
      v_txn_amt   NUMERIC;
      v_txn_type  TEXT;
      v_rcpt      TEXT;
      v_rcpt_seq  BIGINT;
      v_deposit_modes TEXT[] := ARRAY['Cash','Cheque','Online','Transfer'];
      v_withdraw_modes TEXT[] := ARRAY['Cash','Cheque','Online'];
    BEGIN
      FOR j IN 1..v_txn_count LOOP
        v_rcpt_seq := nextval('receipt_number_seq');
        v_rcpt     := 'RCP-' || v_fy || '-' || LPAD(v_rcpt_seq::TEXT, 5, '0');

        -- First 2 are always deposits (to build balance), rest alternate
        IF j <= 2 THEN
          v_txn_type := 'Deposit';
          v_txn_amt  := (2000 + (i * j * 317 % 48000))::NUMERIC;
          v_bal      := v_bal + v_txn_amt;

          INSERT INTO "SavingTransactions" (
            "Id","AccountId","BranchId","TransactionType","Amount",
            "BalanceAfter","DepositMode","ReceiptNumber","Narration",
            "TransactionDate","ProcessedBy","IsReversed",
            "CreatedAt","UpdatedAt","IsDeleted"
          ) VALUES (
            gen_random_uuid(), v_acc_id, v_branch_id,
            'Deposit', v_txn_amt, v_bal,
            v_deposit_modes[1 + (j % array_length(v_deposit_modes, 1))],
            v_rcpt, 'Deposit #' || j || ' - test data',
            NOW() - ((v_txn_count - j + i % 60) || ' days')::INTERVAL,
            NULL, false,
            NOW() - ((v_txn_count - j + i % 60) || ' days')::INTERVAL,
            NOW() - ((v_txn_count - j + i % 60) || ' days')::INTERVAL,
            false
          );

        ELSIF j % 3 = 0 THEN
          -- Withdrawal (only if balance allows minimum NPR 500 remaining)
          v_txn_amt := LEAST((500 + (i * j * 211 % 20000))::NUMERIC, v_bal - 500);
          IF v_txn_amt > 0 THEN
            v_bal := v_bal - v_txn_amt;

            INSERT INTO "SavingTransactions" (
              "Id","AccountId","BranchId","TransactionType","Amount",
              "BalanceAfter","DepositMode","ReceiptNumber","Narration",
              "TransactionDate","ProcessedBy","IsReversed",
              "CreatedAt","UpdatedAt","IsDeleted"
            ) VALUES (
              gen_random_uuid(), v_acc_id, v_branch_id,
              'Withdrawal', v_txn_amt, v_bal,
              v_withdraw_modes[1 + (j % array_length(v_withdraw_modes, 1))],
              v_rcpt, 'Withdrawal #' || (j/3) || ' - test data',
              NOW() - ((v_txn_count - j + i % 50) || ' days')::INTERVAL,
              NULL, false,
              NOW() - ((v_txn_count - j + i % 50) || ' days')::INTERVAL,
              NOW() - ((v_txn_count - j + i % 50) || ' days')::INTERVAL,
              false
            );
          END IF;

        ELSE
          -- Deposit
          v_txn_amt := (1000 + (i * j * 137 % 30000))::NUMERIC;
          v_bal     := v_bal + v_txn_amt;

          INSERT INTO "SavingTransactions" (
            "Id","AccountId","BranchId","TransactionType","Amount",
            "BalanceAfter","DepositMode","ReceiptNumber","Narration",
            "TransactionDate","ProcessedBy","IsReversed",
            "CreatedAt","UpdatedAt","IsDeleted"
          ) VALUES (
            gen_random_uuid(), v_acc_id, v_branch_id,
            'Deposit', v_txn_amt, v_bal,
            v_deposit_modes[1 + (j % array_length(v_deposit_modes, 1))],
            v_rcpt, 'Deposit #' || j || ' - test data',
            NOW() - ((v_txn_count - j + i % 45) || ' days')::INTERVAL,
            NULL, false,
            NOW() - ((v_txn_count - j + i % 45) || ' days')::INTERVAL,
            NOW() - ((v_txn_count - j + i % 45) || ' days')::INTERVAL,
            false
          );
        END IF;

      END LOOP;

      -- Update account's final CurrentBalance to match transactions
      UPDATE "SavingAccounts" SET "CurrentBalance" = v_bal WHERE "Id" = v_acc_id;
    END;

    -- ── Loan (every 5th member gets a loan) ──────────────────────────────────
    IF i % 5 = 0 AND v_loan_prod IS NOT NULL THEN
      v_loan_id  := gen_random_uuid();
      v_loan_seq := nextval('loan_number_seq');
      v_loan_no  := 'TEST-LN-' || v_fy || '-' || LPAD(v_loan_seq::TEXT, 5, '0');

      INSERT INTO "Loans" (
        "Id","MemberId","BranchId","ProductId","LoanNumber",
        "AppliedAmount","ApprovedAmount","DisbursedAmount","OutstandingBalance",
        "InterestRate","TenureMonths","EmiAmount","RepaymentMode",
        "Status","NpaClassification","LoanPurpose",
        "AppliedDate","ApprovedDate","DisbursedDate","NextEmiDate",
        "OverdueAmount","OverdueDays",
        "CreatedAt","UpdatedAt","IsDeleted"
      ) VALUES (
        v_loan_id, v_member_id, v_branch_id, v_loan_prod, v_loan_no,
        (50000 + (i * 997 % 450000))::NUMERIC,
        (50000 + (i * 997 % 450000))::NUMERIC,
        (50000 + (i * 997 % 450000))::NUMERIC,
        (30000 + (i * 997 % 420000))::NUMERIC,
        14.0, 24,
        ROUND((50000 + (i * 997 % 450000)) * 0.14/12 * POWER(1 + 0.14/12, 24) / (POWER(1 + 0.14/12, 24) - 1), 2),
        'Monthly',
        CASE WHEN i % 15 = 0 THEN 'Pending'
             WHEN i % 15 = 5 THEN 'Approved'
             ELSE 'Active' END,
        'Standard',
        'Personal use - test data',
        CURRENT_DATE - (i % 400),
        CURRENT_DATE - (i % 390),
        CURRENT_DATE - (i % 380),
        CURRENT_DATE + 30,
        0, 0,
        NOW() - (i % 365 || ' days')::INTERVAL,
        NOW() - (i % 365 || ' days')::INTERVAL,
        false
      );
    END IF;

    -- Progress every 100
    IF i % 100 = 0 THEN
      RAISE NOTICE 'Inserted % members...', i;
    END IF;

  END LOOP;

  RAISE NOTICE '✅ Done! 1000 members, accounts, transactions and ~200 loans inserted.';
  RAISE NOTICE '   All members have MemberCode starting with TEST-';
  RAISE NOTICE '   All loans have LoanNumber starting with TEST-LN-';
  RAISE NOTICE '   Run delete_test_data.sql to remove all test data.';
END;
$$;
