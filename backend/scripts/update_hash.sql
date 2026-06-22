UPDATE "Users" SET "PasswordHash" = '$2a$11$cqQJl56G1ozcUwv5vruzFOa1AalA7U45ldV1YoabRLP/zPHluthCa' WHERE "Username" = 'admin';
UPDATE "Users" SET "PasswordHash" = '$2a$11$QofRtyGHk/UADxTmbKHv7eRO4FwqX28RZ/HL4.evx5IiI.Kjd8zzm' WHERE "Username" = 'manager1';
UPDATE "Users" SET "PasswordHash" = '$2a$11$PdJV/IJ6lLBY1tILi1zYg.s4F4kUx/Lwk3lAtlOHzVv.C.MctM3RC' WHERE "Username" = 'accountant1';
UPDATE "Users" SET "PasswordHash" = '$2a$11$R5GH0JM7ihKfETBn4gliOu3FGFCgg7kQgscJdECO53LgjliBt3roq' WHERE "Username" = 'cashier1';
UPDATE "Users" SET "PasswordHash" = '$2a$11$eqAJFGXaldNS7BBKjeeA8uSKKrJijEQk7BZBMU2AAYMm957Q856OC' WHERE "Username" = 'loanofficer1';
SELECT "Username", "Status", "FailedLoginCount" FROM "Users" ORDER BY "CreatedAt";
