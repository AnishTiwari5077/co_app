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

-- Verify
SELECT "Username", "FullName", "Status", "CreatedAt" FROM "Users";
