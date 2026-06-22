-- ============================================================
-- SahakariMS — Seed All Role Users
-- ============================================================
-- Credentials:
--   admin        / Admin@1234        (ADMIN)
--   manager1     / Manager@1234      (MANAGER)
--   accountant1  / Accountant@1234   (ACCOUNTANT)
--   cashier1     / Cashier@1234      (CASHIER)
--   loanofficer1 / LoanOfficer@1234  (LOAN_OFFICER)
-- ============================================================

DO $$
DECLARE
  branch_id UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  -- Role IDs (must match seeded Roles table)
  role_admin        UUID := '11111111-1111-1111-1111-111111111111';
  role_manager      UUID := '22222222-2222-2222-2222-222222222222';
  role_accountant   UUID := '33333333-3333-3333-3333-333333333333';
  role_cashier      UUID := '44444444-4444-4444-4444-444444444444';
  role_loan_officer UUID := '55555555-5555-5555-5555-555555555555';

  uid UUID;
BEGIN

  -- ── MANAGER ──────────────────────────────────────────────
  INSERT INTO "Users" (
    "Id","BranchId","EmployeeCode","FullName","Email","Username",
    "PasswordHash","Phone","Status","IsTwoFactorEnabled",
    "FailedLoginCount","MustChangePassword","CreatedAt","UpdatedAt","IsDeleted"
  )
  SELECT gen_random_uuid(), branch_id, 'EMP-002',
    'Sita Sharma', 'manager@sahakarims.np', 'manager1',
    '$2a$11$WoxFxYdUGujlt5sjT152/.0q7qOM6WaCeEsjgMPynk2KftY18cA7C',
    '9800000002','Active',false,0,false,now(),now(),false
  WHERE NOT EXISTS (SELECT 1 FROM "Users" WHERE "Username"='manager1')
  RETURNING "Id" INTO uid;

  IF uid IS NOT NULL THEN
    INSERT INTO "UserRoles"("UserId","RoleId") VALUES (uid, role_manager);
    RAISE NOTICE 'Created manager1: %', uid;
  ELSE
    RAISE NOTICE 'manager1 already exists';
  END IF;

  -- ── ACCOUNTANT ───────────────────────────────────────────
  INSERT INTO "Users" (
    "Id","BranchId","EmployeeCode","FullName","Email","Username",
    "PasswordHash","Phone","Status","IsTwoFactorEnabled",
    "FailedLoginCount","MustChangePassword","CreatedAt","UpdatedAt","IsDeleted"
  )
  SELECT gen_random_uuid(), branch_id, 'EMP-003',
    'Hari Prasad', 'accountant@sahakarims.np', 'accountant1',
    '$2a$11$0PTvuemQ0JcpQps.NpiL8.R6S3cgN577TMu1snJKj30of1gcKLQDS',
    '9800000003','Active',false,0,false,now(),now(),false
  WHERE NOT EXISTS (SELECT 1 FROM "Users" WHERE "Username"='accountant1')
  RETURNING "Id" INTO uid;

  IF uid IS NOT NULL THEN
    INSERT INTO "UserRoles"("UserId","RoleId") VALUES (uid, role_accountant);
    RAISE NOTICE 'Created accountant1: %', uid;
  ELSE
    RAISE NOTICE 'accountant1 already exists';
  END IF;

  -- ── CASHIER ──────────────────────────────────────────────
  INSERT INTO "Users" (
    "Id","BranchId","EmployeeCode","FullName","Email","Username",
    "PasswordHash","Phone","Status","IsTwoFactorEnabled",
    "FailedLoginCount","MustChangePassword","CreatedAt","UpdatedAt","IsDeleted"
  )
  SELECT gen_random_uuid(), branch_id, 'EMP-004',
    'Ram Bahadur', 'cashier@sahakarims.np', 'cashier1',
    '$2a$11$y2DMjHgDfP68c3JnHKyPXuGNDApYmT9CmWCbzWe7I9UPAd5UQo0rC',
    '9800000004','Active',false,0,false,now(),now(),false
  WHERE NOT EXISTS (SELECT 1 FROM "Users" WHERE "Username"='cashier1')
  RETURNING "Id" INTO uid;

  IF uid IS NOT NULL THEN
    INSERT INTO "UserRoles"("UserId","RoleId") VALUES (uid, role_cashier);
    RAISE NOTICE 'Created cashier1: %', uid;
  ELSE
    RAISE NOTICE 'cashier1 already exists';
  END IF;

  -- ── LOAN OFFICER ─────────────────────────────────────────
  INSERT INTO "Users" (
    "Id","BranchId","EmployeeCode","FullName","Email","Username",
    "PasswordHash","Phone","Status","IsTwoFactorEnabled",
    "FailedLoginCount","MustChangePassword","CreatedAt","UpdatedAt","IsDeleted"
  )
  SELECT gen_random_uuid(), branch_id, 'EMP-005',
    'Gita Thapa', 'loanofficer@sahakarims.np', 'loanofficer1',
    '$2a$11$fKfMM07J3eMVQSB4yv2NEeNa0JGLml8ETxq.DnS3qAkPmfIBvengS',
    '9800000005','Active',false,0,false,now(),now(),false
  WHERE NOT EXISTS (SELECT 1 FROM "Users" WHERE "Username"='loanofficer1')
  RETURNING "Id" INTO uid;

  IF uid IS NOT NULL THEN
    INSERT INTO "UserRoles"("UserId","RoleId") VALUES (uid, role_loan_officer);
    RAISE NOTICE 'Created loanofficer1: %', uid;
  ELSE
    RAISE NOTICE 'loanofficer1 already exists';
  END IF;

END $$;

-- Verify all users
SELECT
  u."Username",
  u."FullName",
  u."Email",
  u."Phone",
  u."Status",
  STRING_AGG(r."RoleCode", ', ') AS "Roles"
FROM "Users" u
LEFT JOIN "UserRoles" ur ON ur."UserId" = u."Id"
LEFT JOIN "Roles" r      ON r."Id"      = ur."RoleId"
GROUP BY u."Username", u."FullName", u."Email", u."Phone", u."Status"
ORDER BY u."FullName";
