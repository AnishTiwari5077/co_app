using MediatR;
using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;
using SahakariMS.Domain.Entities;
using SahakariMS.Domain.Interfaces;
using SahakariMS.Shared.Common;

namespace SahakariMS.Application.Accounting;

public record CreateVoucherRequest(string VoucherType, DateOnly VoucherDate, string? Narration,
    List<VoucherEntryRequest> Entries);
public record VoucherEntryRequest(Guid AccountId, string EntryType, decimal Amount, string? Narration);
public record TrialBalanceDto(DateOnly AsOfDate, string BranchName,
    List<TrialBalanceRowDto> Accounts, decimal TotalDebit, decimal TotalCredit, bool IsBalanced);
public record TrialBalanceRowDto(string AccountCode, string AccountName, string AccountType,
    decimal DebitBalance, decimal CreditBalance);
public record DashboardSummaryDto(
    int TotalMembers, int ActiveLoans, decimal TotalSavingsBalance,
    decimal TotalLoanOutstanding, decimal TodayDeposits, decimal TodayWithdrawals,
    decimal LoanRecoveryRate, decimal NpaPercent, int NewMembersThisMonth, decimal CashPosition);

// ── Create Voucher ────────────────────────────────────────────────────────────

public record CreateVoucherCommand(CreateVoucherRequest Request, Guid BranchId, Guid ActorId) : IRequest<Result<Guid>>;

public class CreateVoucherCommandHandler(IAppDbContext db, IUnitOfWork uow, ISequenceGenerator seq)
    : IRequestHandler<CreateVoucherCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateVoucherCommand cmd, CancellationToken ct)
    {
        var r = cmd.Request;
        var totalDebit  = r.Entries.Where(e => e.EntryType == "Debit").Sum(e => e.Amount);
        var totalCredit = r.Entries.Where(e => e.EntryType == "Credit").Sum(e => e.Amount);

        if (totalDebit != totalCredit)
            return Result<Guid>.Failure("UNBALANCED_VOUCHER",
                $"Voucher is unbalanced. Debit: {totalDebit:N2}, Credit: {totalCredit:N2}.");

        var fiscalYear = await db.FiscalYears.FirstOrDefaultAsync(fy => fy.IsCurrent && !fy.IsClosed, ct);
        if (fiscalYear is null)
            return Result<Guid>.Failure("NO_FISCAL_YEAR", "No active fiscal year found.");

        var voucherNo = await seq.NextVoucherNumberAsync(r.VoucherType, cmd.BranchId, DateTime.UtcNow.Year + 57);
        var voucher = new Voucher
        {
            BranchId = cmd.BranchId, FiscalYearId = fiscalYear.Id,
            VoucherNumber = voucherNo, VoucherType = r.VoucherType,
            VoucherDate = r.VoucherDate, Narration = r.Narration,
            Status = "Posted", IsBalanced = true, PreparedBy = cmd.ActorId, CreatedBy = cmd.ActorId
        };

        foreach (var e in r.Entries)
        {
            voucher.Entries.Add(new VoucherEntry
            {
                AccountId = e.AccountId, EntryType = e.EntryType, Amount = e.Amount, Narration = e.Narration
            });
            var account = await db.ChartOfAccounts.FindAsync([e.AccountId], ct);
            if (account != null)
                account.CurrentBalance += e.EntryType == "Debit" ? e.Amount : -e.Amount;
        }

        await db.Vouchers.AddAsync(voucher, ct);
        await uow.SaveChangesAsync(ct);
        return Result<Guid>.Success(voucher.Id);
    }
}

// ── Trial Balance ─────────────────────────────────────────────────────────────

public record GetTrialBalanceQuery(Guid BranchId, DateOnly AsOfDate) : IRequest<Result<TrialBalanceDto>>;

public class GetTrialBalanceQueryHandler(IAppDbContext db)
    : IRequestHandler<GetTrialBalanceQuery, Result<TrialBalanceDto>>
{
    public async Task<Result<TrialBalanceDto>> Handle(GetTrialBalanceQuery q, CancellationToken ct)
    {
        var branch = await db.Branches.FindAsync([q.BranchId], ct);
        if (branch is null) return Result<TrialBalanceDto>.Failure("BRANCH_NOT_FOUND", "Branch not found.");

        var accounts = await db.ChartOfAccounts.AsNoTracking()
            .Where(a => a.AllowDirectPosting && a.IsActive)
            .OrderBy(a => a.AccountCode).ToListAsync(ct);

        var rows = accounts.Select(a => new TrialBalanceRowDto(
            a.AccountCode, a.AccountName, a.AccountType,
            a.CurrentBalance >= 0 ? a.CurrentBalance : 0,
            a.CurrentBalance < 0 ? Math.Abs(a.CurrentBalance) : 0)).ToList();

        var td = rows.Sum(r => r.DebitBalance);
        var tc = rows.Sum(r => r.CreditBalance);
        return Result<TrialBalanceDto>.Success(new TrialBalanceDto(q.AsOfDate, branch.BranchName, rows, td, tc, td == tc));
    }
}

// ── Dashboard Summary ─────────────────────────────────────────────────────────

public record GetDashboardSummaryQuery(Guid BranchId) : IRequest<Result<DashboardSummaryDto>>;

public class GetDashboardSummaryQueryHandler(IAppDbContext db, ICacheService cache)
    : IRequestHandler<GetDashboardSummaryQuery, Result<DashboardSummaryDto>>
{
    public async Task<Result<DashboardSummaryDto>> Handle(GetDashboardSummaryQuery q, CancellationToken ct)
    {
        var cacheKey = $"dashboard:branch:{q.BranchId}";
        var cached = await cache.GetAsync<DashboardSummaryDto>(cacheKey, ct);
        if (cached is not null) return Result<DashboardSummaryDto>.Success(cached);

        var today      = DateTime.UtcNow.Date;
        var monthStart = new DateTime(today.Year, today.Month, 1);

        var totalMembers     = await db.Members.CountAsync(m => m.BranchId == q.BranchId && m.Status == "Active", ct);
        var activeLoans      = await db.Loans.CountAsync(l => l.BranchId == q.BranchId && l.Status == "Active", ct);
        var totalSavings     = await db.SavingAccounts.Where(a => a.BranchId == q.BranchId && a.Status == "Active").SumAsync(a => a.CurrentBalance, ct);
        var totalOutstanding = await db.Loans.Where(l => l.BranchId == q.BranchId && l.Status == "Active").SumAsync(l => l.OutstandingBalance, ct);
        var todayDeposits    = await db.SavingTransactions.Where(t => t.BranchId == q.BranchId && t.TransactionType == "Deposit"    && t.TransactionDate >= today).SumAsync(t => t.Amount, ct);
        var todayWithdrawals = await db.SavingTransactions.Where(t => t.BranchId == q.BranchId && t.TransactionType == "Withdrawal" && t.TransactionDate >= today).SumAsync(t => t.Amount, ct);
        var npaLoans         = await db.Loans.CountAsync(l => l.BranchId == q.BranchId && l.NpaClassification != "Standard", ct);
        var newMembers       = await db.Members.CountAsync(m => m.BranchId == q.BranchId && m.CreatedAt >= monthStart, ct);
        var npaPercent       = activeLoans > 0 ? Math.Round((decimal)npaLoans / activeLoans * 100, 2) : 0;

        var summary = new DashboardSummaryDto(totalMembers, activeLoans, totalSavings, totalOutstanding,
            todayDeposits, todayWithdrawals, 94.5m, npaPercent, newMembers, 0);

        await cache.SetAsync(cacheKey, summary, TimeSpan.FromMinutes(1), ct);
        return Result<DashboardSummaryDto>.Success(summary);
    }
}
