UPDATE "Users"
SET "PasswordHash" = '$2a$11$HIv5WtXKVQRmhaw8pGBCyuCqBizejrgQU3hQFRLhdvfxKq7itdA6e'
WHERE "Username" = 'admin';

SELECT "Username", LEFT("PasswordHash", 7) AS hash_prefix, "Status"
FROM "Users";
