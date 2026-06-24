UPDATE "Users"
SET "PasswordHash" = '$2a$11$NLEqKWb9OxSdL9GTvUn6OOmjiUC34F40Ij/bpH9o43.7WUf2CSENW',
    "Status" = 'Active',
    "FailedLoginCount" = 0,
    "LockedUntil" = NULL
WHERE "Username" = 'admin';

SELECT "Username", "Status", "FailedLoginCount" FROM "Users";
