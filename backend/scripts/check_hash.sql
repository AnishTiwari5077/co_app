SELECT "Username", LEFT("PasswordHash", 30) as hash_start FROM "Users" ORDER BY "CreatedAt";
