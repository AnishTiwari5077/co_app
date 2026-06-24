-- Unlock admin account and reset failed login count
UPDATE "Users"
SET "Status" = 'Active',
    "FailedLoginCount" = 0,
    "LockedUntil" = NULL
WHERE "Username" = 'admin';

SELECT "Username", "Status", "FailedLoginCount", "LockedUntil" FROM "Users";
