-- Fix: Seed the Head Office branch that was missing from the Branches table
-- This branch is referenced by all seeded users (BranchId = aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa)

INSERT INTO "Branches" (
  "Id", "BranchCode", "BranchName", "IsHeadOffice", "Status",
  "CreatedAt", "UpdatedAt", "IsDeleted"
)
SELECT
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'HO',
  'Head Office',
  true,
  'Active',
  now(), now(), false
WHERE NOT EXISTS (
  SELECT 1 FROM "Branches" WHERE "Id" = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
);

-- Verify
SELECT "Id", "BranchCode", "BranchName", "IsHeadOffice", "Status" FROM "Branches";
