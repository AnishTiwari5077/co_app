START TRANSACTION;


DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    ALTER TABLE "RolePermissions" DROP CONSTRAINT "FK_RolePermissions_Permissions_PermissionId1";
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    ALTER TABLE "RolePermissions" DROP CONSTRAINT "FK_RolePermissions_Roles_RoleId";
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    ALTER TABLE "UserRoles" DROP CONSTRAINT "FK_UserRoles_Users_UserId";
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    DROP INDEX "IX_RolePermissions_PermissionId1";
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    ALTER TABLE "RolePermissions" DROP COLUMN "PermissionId1";
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    ALTER TABLE "Members" ADD "CitizenshipDocUrl" text;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    ALTER TABLE "Members" ADD "SignatureUrl" text;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    UPDATE "Branches" SET "CreatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685739Z', "UpdatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685739Z'
    WHERE "Id" = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    UPDATE "Roles" SET "CreatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685688Z', "UpdatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685688Z'
    WHERE "Id" = '11111111-1111-1111-1111-111111111111';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    UPDATE "Roles" SET "CreatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685689Z', "UpdatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685689Z'
    WHERE "Id" = '22222222-2222-2222-2222-222222222222';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    UPDATE "Roles" SET "CreatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.68569Z', "UpdatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.68569Z'
    WHERE "Id" = '33333333-3333-3333-3333-333333333333';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    UPDATE "Roles" SET "CreatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.68569Z', "UpdatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685691Z'
    WHERE "Id" = '44444444-4444-4444-4444-444444444444';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    UPDATE "Roles" SET "CreatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685691Z', "UpdatedAt" = TIMESTAMPTZ '2026-06-24T17:00:30.685691Z'
    WHERE "Id" = '55555555-5555-5555-5555-555555555555';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    ALTER TABLE "RolePermissions" ADD CONSTRAINT "FK_RolePermissions_Roles_RoleId" FOREIGN KEY ("RoleId") REFERENCES "Roles" ("Id");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    ALTER TABLE "UserRoles" ADD CONSTRAINT "FK_UserRoles_Users_UserId" FOREIGN KEY ("UserId") REFERENCES "Users" ("Id");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260624170033_SeedHeadOfficeBranch') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260624170033_SeedHeadOfficeBranch', '8.0.11');
    END IF;
END $EF$;
COMMIT;

