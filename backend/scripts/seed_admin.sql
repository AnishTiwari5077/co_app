-- Seed admin user for SahakariMS
-- Password: Admin@1234  (BCrypt cost 11)

INSERT INTO "Users" (
  "Id", "BranchId", "EmployeeCode", "FullName", "Email", "Username",
  "PasswordHash", "Phone", "Status", "IsTwoFactorEnabled",
  "FailedLoginCount", "MustChangePassword", "CreatedAt", "UpdatedAt", "IsDeleted"
)
SELECT
  gen_random_uuid(),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'EMP-001',
  'System Administrator',
  'admin@sahakarims.np',
  'admin',
  '$2a$11$3QF4Ky8i5rJz9mT7V2vhBuKX5eNpA0wYdWsG6oR1cHjLmPxQtIdO.',
  '9800000000',
  'Active',
  false, 0, false,
  now(), now(), false
WHERE NOT EXISTS (
  SELECT 1 FROM "Users" WHERE "Username" = 'admin'
);

-- Assign ADMIN role to admin user
INSERT INTO "UserRoles" ("UserId", "RoleId")
SELECT u."Id", '11111111-1111-1111-1111-111111111111'::uuid
FROM "Users" u
WHERE u."Username" = 'admin'
  AND NOT EXISTS (
    SELECT 1 FROM "UserRoles" ur
    WHERE ur."UserId" = u."Id"
      AND ur."RoleId" = '11111111-1111-1111-1111-111111111111'::uuid
  );

-- Ensure admin always has the Head Office branch (fixes NULL BranchId if user pre-existed)
UPDATE "Users"
SET
  "BranchId" = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  "UpdatedAt" = now()
WHERE "Username" = 'admin'
  AND ("BranchId" IS NULL OR "BranchId" != 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid);

-- Verify
SELECT u."Username", u."FullName", u."Status", u."BranchId", b."BranchName"
FROM "Users" u
LEFT JOIN "Branches" b ON b."Id" = u."BranchId"
WHERE u."Username" = 'admin';
