using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using SahakariMS.Domain.Entities;

namespace SahakariMS.Application.Interfaces;

/// <summary>
/// Application-layer abstraction over the EF DbContext.
/// Infrastructure implements this; Application depends only on this interface.
/// This follows the "pragmatic Clean Architecture" approach used by most .NET SACCOS systems.
/// </summary>
public interface IAppDbContext
{
    // Identity
    DbSet<Branch> Branches { get; }
    DbSet<User> Users { get; }
    DbSet<Role> Roles { get; }
    DbSet<Permission> Permissions { get; }
    DbSet<UserRole> UserRoles { get; }
    DbSet<RolePermission> RolePermissions { get; }
    DbSet<RefreshToken> RefreshTokens { get; }

    // Members
    DbSet<Member> Members { get; }
    DbSet<MemberNominee> MemberNominees { get; }

    // Savings
    DbSet<SavingScheme> SavingSchemes { get; }
    DbSet<SavingAccount> SavingAccounts { get; }
    DbSet<SavingTransaction> SavingTransactions { get; }
    DbSet<ShareAccount> ShareAccounts { get; }

    // Loans
    DbSet<LoanProduct> LoanProducts { get; }
    DbSet<Loan> Loans { get; }
    DbSet<LoanEmiSchedule> LoanEmiSchedules { get; }
    DbSet<LoanPayment> LoanPayments { get; }
    DbSet<LoanGuarantor> LoanGuarantors { get; }
    DbSet<LoanCollateral> LoanCollaterals { get; }

    // Accounting
    DbSet<FiscalYear> FiscalYears { get; }
    DbSet<ChartOfAccount> ChartOfAccounts { get; }
    DbSet<Voucher> Vouchers { get; }
    DbSet<VoucherEntry> VoucherEntries { get; }

    // Audit
    DbSet<AuditLog> AuditLogs { get; }

    DatabaseFacade Database { get; }

    Task<int> SaveChangesAsync(CancellationToken ct = default);
}

/// <summary>JWT token generation contract — Infrastructure implements this.</summary>
public interface IJwtService
{
    string GenerateAccessToken(User user, IEnumerable<string> roles, IEnumerable<string> permissions);
    string GenerateRefreshToken();
}
