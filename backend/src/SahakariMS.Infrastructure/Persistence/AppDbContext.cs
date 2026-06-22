using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;
using SahakariMS.Domain.Entities;

namespace SahakariMS.Infrastructure.Persistence;

public class AppDbContext : DbContext, IAppDbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    // ── Identity ──────────────────────────────────────────────────────────────
    public DbSet<Branch> Branches => Set<Branch>();
    public DbSet<User> Users => Set<User>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Permission> Permissions => Set<Permission>();
    public DbSet<UserRole> UserRoles => Set<UserRole>();
    public DbSet<RolePermission> RolePermissions => Set<RolePermission>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    // ── Members ───────────────────────────────────────────────────────────────
    public DbSet<Member> Members => Set<Member>();
    public DbSet<MemberNominee> MemberNominees => Set<MemberNominee>();

    // ── Savings ───────────────────────────────────────────────────────────────
    public DbSet<SavingScheme> SavingSchemes => Set<SavingScheme>();
    public DbSet<SavingAccount> SavingAccounts => Set<SavingAccount>();
    public DbSet<SavingTransaction> SavingTransactions => Set<SavingTransaction>();
    public DbSet<ShareAccount> ShareAccounts => Set<ShareAccount>();

    // ── Loans ─────────────────────────────────────────────────────────────────
    public DbSet<LoanProduct> LoanProducts => Set<LoanProduct>();
    public DbSet<Loan> Loans => Set<Loan>();
    public DbSet<LoanEmiSchedule> LoanEmiSchedules => Set<LoanEmiSchedule>();
    public DbSet<LoanPayment> LoanPayments => Set<LoanPayment>();
    public DbSet<LoanGuarantor> LoanGuarantors => Set<LoanGuarantor>();
    public DbSet<LoanCollateral> LoanCollaterals => Set<LoanCollateral>();

    // ── Accounting ────────────────────────────────────────────────────────────
    public DbSet<FiscalYear> FiscalYears => Set<FiscalYear>();
    public DbSet<ChartOfAccount> ChartOfAccounts => Set<ChartOfAccount>();
    public DbSet<Voucher> Vouchers => Set<Voucher>();
    public DbSet<VoucherEntry> VoucherEntries => Set<VoucherEntry>();

    // ── Audit ─────────────────────────────────────────────────────────────────
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // Separate schemas per docs/database-design.md
        modelBuilder.Entity<FiscalYear>().ToTable("fiscal_years", "accounting");
        modelBuilder.Entity<ChartOfAccount>().ToTable("chart_of_accounts", "accounting");
        modelBuilder.Entity<Voucher>().ToTable("vouchers", "accounting");
        modelBuilder.Entity<VoucherEntry>().ToTable("voucher_entries", "accounting");
        modelBuilder.Entity<AuditLog>().ToTable("audit_logs", "audit");

        // Composite keys + optional navigations (suppresses EF query-filter warnings)
        modelBuilder.Entity<UserRole>().HasKey(ur => new { ur.UserId, ur.RoleId });
        modelBuilder.Entity<UserRole>()
            .HasOne(ur => ur.User).WithMany(u => u.UserRoles)
            .HasForeignKey(ur => ur.UserId).IsRequired(false);
        modelBuilder.Entity<UserRole>()
            .HasOne(ur => ur.Role).WithMany(r => r.UserRoles)
            .HasForeignKey(ur => ur.RoleId).IsRequired(false);

        modelBuilder.Entity<RolePermission>().HasKey(rp => new { rp.RoleId, rp.PermissionId });
        modelBuilder.Entity<RolePermission>()
            .HasOne(rp => rp.Role).WithMany(r => r.RolePermissions)
            .HasForeignKey(rp => rp.RoleId).IsRequired(false);
        modelBuilder.Entity<RolePermission>()
            .HasOne(rp => rp.Permission).WithMany(p => p.RolePermissions)
            .HasForeignKey(rp => rp.PermissionId).IsRequired(false);


        // Global soft-delete query filter — skip join tables that have no IsDeleted
        var joinTypes = new[] { typeof(UserRole), typeof(RolePermission) };
        foreach (var entityType in modelBuilder.Model.GetEntityTypes()
            .Where(e => !joinTypes.Contains(e.ClrType)))
        {
            if (entityType.ClrType.GetProperty("IsDeleted") != null)
            {
                var method = typeof(AppDbContext)
                    .GetMethod(nameof(SetSoftDeleteFilter),
                        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)!
                    .MakeGenericMethod(entityType.ClrType);
                method.Invoke(null, [modelBuilder]);
            }
        }

        // NUMERIC(18,4) for all monetary columns
        foreach (var property in modelBuilder.Model.GetEntityTypes()
            .SelectMany(t => t.GetProperties())
            .Where(p => p.ClrType == typeof(decimal) || p.ClrType == typeof(decimal?)))
        {
            property.SetColumnType("numeric(18,4)");
        }

        SeedData(modelBuilder);
    }

    private static void SetSoftDeleteFilter<T>(ModelBuilder mb) where T : class
    {
        mb.Entity<T>().HasQueryFilter(e => EF.Property<bool>(e, "IsDeleted") == false);
    }

    private static void SeedData(ModelBuilder modelBuilder)
    {
        var adminRoleId = new Guid("11111111-1111-1111-1111-111111111111");
        modelBuilder.Entity<Role>().HasData(
            new Role { Id = adminRoleId,                                        RoleCode = "ADMIN",        RoleName = "Administrator", IsSystemRole = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new Role { Id = new Guid("22222222-2222-2222-2222-222222222222"),   RoleCode = "MANAGER",      RoleName = "Manager",       IsSystemRole = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new Role { Id = new Guid("33333333-3333-3333-3333-333333333333"),   RoleCode = "ACCOUNTANT",   RoleName = "Accountant",    IsSystemRole = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new Role { Id = new Guid("44444444-4444-4444-4444-444444444444"),   RoleCode = "CASHIER",      RoleName = "Cashier",       IsSystemRole = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
            new Role { Id = new Guid("55555555-5555-5555-5555-555555555555"),   RoleCode = "LOAN_OFFICER", RoleName = "Loan Officer",  IsSystemRole = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow }
        );

        var headBranchId = new Guid("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
        modelBuilder.Entity<Branch>().HasData(new Branch
        {
            Id = headBranchId, BranchCode = "HO", BranchName = "Head Office",
            IsHeadOffice = true, Status = "Active",
            CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow
        });
    }
}
