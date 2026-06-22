# SahakariMS — Database: Migrations

## Overview

SahakariMS uses **Entity Framework Core Migrations** for all database schema changes. Every change is version-controlled and reversible. Migrations run automatically during deployment.

---

## Migration Strategy

1. **Never modify past migrations** — Create a new one instead
2. **One migration per feature** — Keep migrations atomic and focused
3. **Always generate `Down()`** — All migrations must be reversible
4. **Test on staging first** — Validate migration on staging DB before production
5. **Idempotent seeds** — Use `ON CONFLICT DO NOTHING` for seed data

---

## Creating Migrations

```bash
# Navigate to solution root
cd src/backend

# Create a new migration
dotnet ef migrations add AddMemberKycFields \
  --project SahakariMS.Infrastructure \
  --startup-project SahakariMS.API \
  --output-dir Migrations

# Apply pending migrations (development)
dotnet ef database update \
  --project SahakariMS.Infrastructure \
  --startup-project SahakariMS.API

# Revert last migration (development only)
dotnet ef database update PreviousMigrationName \
  --project SahakariMS.Infrastructure \
  --startup-project SahakariMS.API

# Generate SQL script for review (production deployment)
dotnet ef migrations script \
  --project SahakariMS.Infrastructure \
  --startup-project SahakariMS.API \
  --idempotent \
  --output ./migrations/$(date +%Y%m%d)_migration.sql
```

---

## Initial Migration Structure

```csharp
// Migrations/20240730_001_InitialCreate.cs
public partial class InitialCreate : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Branches table (no foreign key dependencies)
        migrationBuilder.CreateTable(
            name: "branches",
            columns: table => new
            {
                id = table.Column<Guid>(nullable: false, defaultValueSql: "gen_random_uuid()"),
                branch_code = table.Column<string>(maxLength: 10),
                branch_name = table.Column<string>(maxLength: 200),
                is_active = table.Column<bool>(defaultValue: true),
                is_deleted = table.Column<bool>(defaultValue: false),
                created_at = table.Column<DateTime>(defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTime>(defaultValueSql: "NOW()")
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_branches", x => x.id);
            });

        migrationBuilder.CreateIndex("idx_branches_code", "branches", "branch_code", unique: true);

        // Users table
        migrationBuilder.CreateTable(
            name: "users",
            columns: table => new
            {
                id = table.Column<Guid>(nullable: false, defaultValueSql: "gen_random_uuid()"),
                branch_id = table.Column<Guid>(),
                username = table.Column<string>(maxLength: 100),
                email = table.Column<string>(maxLength: 200),
                password_hash = table.Column<string>(maxLength: 100),
                full_name = table.Column<string>(maxLength: 200),
                status = table.Column<string>(maxLength: 20, defaultValue: "Active"),
                failed_login_count = table.Column<int>(defaultValue: 0),
                locked_until = table.Column<DateTime>(nullable: true),
                is_two_factor_enabled = table.Column<bool>(defaultValue: false),
                is_deleted = table.Column<bool>(defaultValue: false),
                created_at = table.Column<DateTime>(defaultValueSql: "NOW()"),
                updated_at = table.Column<DateTime>(defaultValueSql: "NOW()")
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_users", x => x.id);
                table.ForeignKey("fk_users_branch", x => x.branch_id, "branches", "id");
            });

        // Extensions
        migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";");
        migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";");

        // Schemas
        migrationBuilder.Sql("CREATE SCHEMA IF NOT EXISTS accounting;");
        migrationBuilder.Sql("CREATE SCHEMA IF NOT EXISTS audit;");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable("users");
        migrationBuilder.DropTable("branches");
    }
}
```

---

## Migration for Adding a Column

```csharp
// Migrations/20240815_002_AddMemberPanNumber.cs
public partial class AddMemberPanNumber : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "pan_number",
            table: "members",
            maxLength: 100,  // Encrypted, so longer than raw PAN
            nullable: true);

        // Backfill existing records if needed
        // migrationBuilder.Sql("UPDATE members SET pan_number = NULL WHERE pan_number IS NULL");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn("pan_number", "members");
    }
}
```

---

## Seed Data Migration

```csharp
// Migrations/20240730_003_SeedRolesAndPermissions.cs
public partial class SeedRolesAndPermissions : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Seed roles (idempotent)
        migrationBuilder.Sql(@"
            INSERT INTO roles (id, role_code, role_name, description, is_system_role)
            VALUES
              (gen_random_uuid(), 'ADMIN', 'System Administrator', 'Full system access', TRUE),
              (gen_random_uuid(), 'MANAGER', 'Branch Manager', 'Branch management', TRUE),
              (gen_random_uuid(), 'ACCOUNTANT', 'Accountant', 'Accounting operations', TRUE),
              (gen_random_uuid(), 'CASHIER', 'Cashier', 'Transaction processing', TRUE),
              (gen_random_uuid(), 'LOAN_OFFICER', 'Loan Officer', 'Loan processing', TRUE),
              (gen_random_uuid(), 'COLLECTOR', 'Field Collector', 'Field collection', TRUE),
              (gen_random_uuid(), 'AUDITOR', 'Internal Auditor', 'Read-only access', TRUE),
              (gen_random_uuid(), 'MEMBER', 'Member', 'Member portal access', TRUE)
            ON CONFLICT (role_code) DO NOTHING;
        ");

        // Seed permissions
        migrationBuilder.Sql(@"
            INSERT INTO permissions (id, permission_code, module, action, description)
            VALUES
              (gen_random_uuid(), 'MEMBERS_VIEW', 'MEMBERS', 'VIEW', 'View member profiles'),
              (gen_random_uuid(), 'MEMBERS_CREATE', 'MEMBERS', 'CREATE', 'Register new members'),
              (gen_random_uuid(), 'MEMBERS_APPROVE', 'MEMBERS', 'APPROVE', 'Approve memberships'),
              (gen_random_uuid(), 'SAVINGS_DEPOSIT', 'SAVINGS', 'DEPOSIT', 'Process deposits'),
              (gen_random_uuid(), 'SAVINGS_WITHDRAW', 'SAVINGS', 'WITHDRAW', 'Process withdrawals'),
              (gen_random_uuid(), 'LOANS_APPROVE', 'LOANS', 'APPROVE', 'Approve loans'),
              (gen_random_uuid(), 'LOANS_DISBURSE', 'LOANS', 'DISBURSE', 'Disburse loans')
            ON CONFLICT (permission_code) DO NOTHING;
        ");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DELETE FROM role_permissions;");
        migrationBuilder.Sql("DELETE FROM permissions;");
        migrationBuilder.Sql("DELETE FROM roles WHERE is_system_role = TRUE;");
    }
}
```

---

## Production Migration Process

```bash
# 1. Generate idempotent SQL script
dotnet ef migrations script --idempotent \
  --output migrations/prod_$(date +%Y%m%d_%H%M%S).sql

# 2. Review script manually (important!)
cat migrations/prod_*.sql

# 3. Backup production database FIRST
./scripts/backup.sh

# 4. Apply migration to staging, verify
psql $STAGING_CONNECTION < migrations/prod_*.sql

# 5. Test staging thoroughly

# 6. Apply to production (with application stopped or in maintenance)
docker compose exec api \
  dotnet ef database update \
  --project SahakariMS.Infrastructure \
  --startup-project SahakariMS.API

# 7. Restart application
docker compose restart api
```

---

## Migration Naming Conventions

```
{Date}_{Sequence}_{PascalCaseName}

Examples:
  20240730_001_InitialCreate
  20240815_002_AddMemberPanNumber
  20240822_003_SeedRolesAndPermissions
  20240901_004_AddLoanNpaClassification
  20240915_005_CreateAuditLogsPartition
  20241001_006_AddHrModule
```
