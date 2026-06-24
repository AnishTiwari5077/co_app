-- Fix: Assign the Head Office branch to admin user (BranchId was NULL)
UPDATE "Users"
SET 
  "BranchId" = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  "UpdatedAt" = now()
WHERE "Username" = 'admin'
  AND ("BranchId" IS NULL OR "BranchId" != 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid);

-- Verify
SELECT u."Username", u."BranchId", b."BranchCode", b."BranchName" 
FROM "Users" u 
LEFT JOIN "Branches" b ON b."Id" = u."BranchId"
WHERE u."Username" = 'admin';
