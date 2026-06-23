-- Activate all Pending members so accounts can be opened
UPDATE "Members" SET "Status" = 'Active', "UpdatedAt" = NOW() WHERE "Status" = 'Pending';

-- Confirm
SELECT "Status", COUNT(*) as count FROM "Members" GROUP BY "Status";
