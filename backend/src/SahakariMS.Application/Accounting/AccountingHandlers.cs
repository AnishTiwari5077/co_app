using MediatR;
using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;
using SahakariMS.Domain.Entities;
using SahakariMS.Domain.Interfaces;
using SahakariMS.Shared.Common;

namespace SahakariMS.Application.Accounting;

public record CreateVoucherRequest(string VoucherType, DateOnly VoucherDate, string? Narration,
    List<VoucherEntryRequest> Entries, bool SaveAsDraft = false);
public record VoucherEntryRequest(Guid AccountId, string EntryType, decimal Amount, string? Narration);

public record ChartOfAccountDto(Guid Id, string AccountCode, string AccountName,
    string AccountType, string AccountGroup, decimal CurrentBalance, bool AllowDirectPosting);
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

        // Only enforce balance for posted vouchers, not drafts
        if (!r.SaveAsDraft)
        {
            var totalDebit  = r.Entries.Where(e => e.EntryType == "Debit").Sum(e => e.Amount);
            var totalCredit = r.Entries.Where(e => e.EntryType == "Credit").Sum(e => e.Amount);
            if (totalDebit != totalCredit)
                return Result<Guid>.Failure("UNBALANCED_VOUCHER",
                    $"Voucher is unbalanced. Debit: {totalDebit:N2}, Credit: {totalCredit:N2}.");
        }

        var fiscalYear = await db.FiscalYears.FirstOrDefaultAsync(fy => fy.IsCurrent && !fy.IsClosed, ct);
        if (fiscalYear is null)
            return Result<Guid>.Failure("NO_FISCAL_YEAR", "No active fiscal year found.");

        var status = r.SaveAsDraft ? "Draft" : "Posted";
        var voucherNo = await seq.NextVoucherNumberAsync(r.VoucherType, cmd.BranchId, DateTime.UtcNow.Year + 57);
        var voucher = new Voucher
        {
            BranchId = cmd.BranchId, FiscalYearId = fiscalYear.Id,
            VoucherNumber = voucherNo, VoucherType = r.VoucherType,
            VoucherDate = r.VoucherDate, Narration = r.Narration,
            Status = status, IsBalanced = !r.SaveAsDraft, PreparedBy = cmd.ActorId, CreatedBy = cmd.ActorId
        };

        foreach (var e in r.Entries.Where(e => e.Amount > 0))
        {
            voucher.Entries.Add(new VoucherEntry
            {
                AccountId = e.AccountId, EntryType = e.EntryType, Amount = e.Amount, Narration = e.Narration
            });
            // Only update account balances for posted vouchers
            if (!r.SaveAsDraft)
            {
                var account = await db.ChartOfAccounts.FindAsync([e.AccountId], ct);
                if (account != null)
                    account.CurrentBalance += e.EntryType == "Debit" ? e.Amount : -e.Amount;
            }
        }

        await db.Vouchers.AddAsync(voucher, ct);
        await uow.SaveChangesAsync(ct);
        return Result<Guid>.Success(voucher.Id);
    }
}

// ── Delete Voucher ────────────────────────────────────────────────────────────

public record DeleteVoucherCommand(Guid VoucherId, Guid ActorId) : IRequest<Result<bool>>;

public class DeleteVoucherCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<DeleteVoucherCommand, Result<bool>>
{
    public async Task<Result<bool>> Handle(DeleteVoucherCommand cmd, CancellationToken ct)
    {
        var voucher = await db.Vouchers
            .Include(v => v.Entries)
            .FirstOrDefaultAsync(v => v.Id == cmd.VoucherId && !v.IsDeleted, ct);

        if (voucher is null)
            return Result<bool>.Failure("NOT_FOUND", "Voucher not found.");

        // If posted, reverse balances
        if (voucher.Status == "Posted")
        {
            foreach (var e in voucher.Entries)
            {
                var account = await db.ChartOfAccounts.FindAsync([e.AccountId], ct);
                if (account != null)
                {
                    // Reverse the original effect: Debit -> subtract, Credit -> add
                    account.CurrentBalance += e.EntryType == "Debit" ? -e.Amount : e.Amount;
                }
            }
        }

        // Soft delete
        voucher.IsDeleted = true;
        foreach (var e in voucher.Entries) e.IsDeleted = true;

        await uow.SaveChangesAsync(ct);
        return Result<bool>.Success(true);
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
        try
        {
            var cached = await cache.GetAsync<DashboardSummaryDto>(cacheKey, ct);
            if (cached is not null) return Result<DashboardSummaryDto>.Success(cached);
        }
        catch { /* Redis unavailable — skip cache */ }

        var today      = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Utc);
        var monthStart = DateTime.SpecifyKind(new DateTime(today.Year, today.Month, 1), DateTimeKind.Utc);

        var totalMembers     = await db.Members.CountAsync(m => !m.IsDeleted, ct);
        var activeMembers    = await db.Members.CountAsync(m => !m.IsDeleted && m.Status == "Active", ct);
        var activeLoans      = await db.Loans.CountAsync(l => !l.IsDeleted && l.Status == "Active", ct);
        var totalSavings     = await db.SavingAccounts
            .Where(a => a.Status == "Active")
            .SumAsync(a => (decimal?)a.CurrentBalance, ct) ?? 0;
        var totalOutstanding = await db.Loans
            .Where(l => l.Status == "Active")
            .SumAsync(l => (decimal?)l.OutstandingBalance, ct) ?? 0;
        var todayDeposits    = await db.SavingTransactions
            .Where(t => t.TransactionType == "Deposit" && t.TransactionDate >= today)
            .SumAsync(t => (decimal?)t.Amount, ct) ?? 0;
        var todayWithdrawals = await db.SavingTransactions
            .Where(t => t.TransactionType == "Withdrawal" && t.TransactionDate >= today)
            .SumAsync(t => (decimal?)t.Amount, ct) ?? 0;
        var npaLoans         = await db.Loans.CountAsync(l => !l.IsDeleted && l.NpaClassification != null && l.NpaClassification != "Standard", ct);
        var newMembers       = await db.Members.CountAsync(m => !m.IsDeleted && m.CreatedAt >= monthStart, ct);
        var npaPercent       = activeLoans > 0 ? Math.Round((decimal)npaLoans / activeLoans * 100, 2) : 0;

        // Real recovery rate: total collected / total due (EMIs with DueDate <= today)
        var todayOnly    = DateOnly.FromDateTime(today);
        var dueEmiTotal  = await db.LoanEmiSchedules
            .Where(e => e.DueDate <= todayOnly)
            .SumAsync(e => (decimal?)e.EmiAmount, ct) ?? 0;
        var paidEmiTotal = await db.LoanEmiSchedules
            .Where(e => e.DueDate <= todayOnly)
            .SumAsync(e => (decimal?)e.PaidAmount, ct) ?? 0;
        var recoveryRate = dueEmiTotal > 0
            ? Math.Round(paidEmiTotal / dueEmiTotal * 100, 1)
            : 0;

        var summary = new DashboardSummaryDto(totalMembers, activeLoans, totalSavings, totalOutstanding,
            todayDeposits, todayWithdrawals, recoveryRate, npaPercent, newMembers, 0);

        try { await cache.SetAsync(cacheKey, summary, TimeSpan.FromMinutes(5), ct); }
        catch { /* Redis unavailable — skip cache write */ }

        return Result<DashboardSummaryDto>.Success(summary);
    }
}

// ── Get Chart of Accounts Query ────────────────────────────────────────────────

public record GetChartOfAccountsQuery(string? Search = null, string? AccountType = null, bool PostableOnly = true)
    : IRequest<Result<List<ChartOfAccountDto>>>;

public class GetChartOfAccountsQueryHandler(IAppDbContext db)
    : IRequestHandler<GetChartOfAccountsQuery, Result<List<ChartOfAccountDto>>>
{
    public async Task<Result<List<ChartOfAccountDto>>> Handle(GetChartOfAccountsQuery q, CancellationToken ct)
    {
        var query = db.ChartOfAccounts.AsNoTracking().Where(a => !a.IsDeleted);

        // When managing accounts (postableOnly=false), show all including inactive
        if (q.PostableOnly)
            query = query.Where(a => a.IsActive && a.AllowDirectPosting);

        if (!string.IsNullOrEmpty(q.Search))
        {
            var s = q.Search.ToLower();
            query = query.Where(a =>
                a.AccountCode.ToLower().Contains(s) ||
                a.AccountName.ToLower().Contains(s));
        }

        if (!string.IsNullOrEmpty(q.AccountType))
            query = query.Where(a => a.AccountType == q.AccountType);

        var items = await query
            .OrderBy(a => a.AccountCode)
            .Select(a => new ChartOfAccountDto(
                a.Id, a.AccountCode, a.AccountName,
                a.AccountType, a.AccountGroup, a.CurrentBalance, a.AllowDirectPosting))
            .ToListAsync(ct);

        return Result<List<ChartOfAccountDto>>.Success(items);
    }
}

// ── Create Chart of Account ────────────────────────────────────────────────────

public record CreateChartOfAccountRequest(
    string AccountCode, string AccountName, string AccountNameNp,
    string AccountType, string AccountGroup, bool AllowDirectPosting = true);

public record CreateChartOfAccountCommand(CreateChartOfAccountRequest Request, Guid ActorId)
    : IRequest<Result<Guid>>;

public class CreateChartOfAccountCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<CreateChartOfAccountCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateChartOfAccountCommand cmd, CancellationToken ct)
    {
        var r = cmd.Request;

        if (await db.ChartOfAccounts.AnyAsync(a => a.AccountCode == r.AccountCode && !a.IsDeleted, ct))
            return Result<Guid>.Failure("DUPLICATE_CODE", $"Account code '{r.AccountCode}' already exists.");

        var validTypes = new[] { "Asset", "Liability", "Equity", "Income", "Expense" };
        if (!validTypes.Contains(r.AccountType))
            return Result<Guid>.Failure("INVALID_TYPE", $"AccountType must be one of: {string.Join(", ", validTypes)}.");

        var account = new ChartOfAccount
        {
            AccountCode = r.AccountCode.Trim(),
            AccountName = r.AccountName.Trim(),
            AccountNameNp = r.AccountNameNp?.Trim() ?? string.Empty,
            AccountType = r.AccountType,
            AccountGroup = r.AccountGroup?.Trim() ?? r.AccountType,
            AllowDirectPosting = r.AllowDirectPosting,
            IsActive = true,
            CurrentBalance = 0,
            CreatedBy = cmd.ActorId
        };

        await db.ChartOfAccounts.AddAsync(account, ct);
        await uow.SaveChangesAsync(ct);
        return Result<Guid>.Success(account.Id);
    }
}

// ── Toggle Active (Activate / Deactivate) ─────────────────────────────────────

public record ToggleChartOfAccountCommand(Guid AccountId, Guid ActorId) : IRequest<Result<bool>>;

public class ToggleChartOfAccountCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<ToggleChartOfAccountCommand, Result<bool>>
{
    public async Task<Result<bool>> Handle(ToggleChartOfAccountCommand cmd, CancellationToken ct)
    {
        var account = await db.ChartOfAccounts.FindAsync([cmd.AccountId], ct);
        if (account is null || account.IsDeleted)
            return Result<bool>.Failure("NOT_FOUND", "Account not found.");

        account.IsActive = !account.IsActive;
        account.UpdatedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        return Result<bool>.Success(account.IsActive);
    }
}

// ── Delete Chart of Account (soft) ────────────────────────────────────────────

public record DeleteChartOfAccountCommand(Guid AccountId, Guid ActorId) : IRequest<Result<bool>>;

public class DeleteChartOfAccountCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<DeleteChartOfAccountCommand, Result<bool>>
{
    public async Task<Result<bool>> Handle(DeleteChartOfAccountCommand cmd, CancellationToken ct)
    {
        var account = await db.ChartOfAccounts.FindAsync([cmd.AccountId], ct);
        if (account is null || account.IsDeleted)
            return Result<bool>.Failure("NOT_FOUND", "Account not found.");

        // Prevent deleting accounts that have transactions
        var hasEntries = await db.VoucherEntries.AnyAsync(e => e.AccountId == cmd.AccountId && !e.IsDeleted, ct);
        if (hasEntries)
            return Result<bool>.Failure("HAS_TRANSACTIONS", "Cannot delete an account that has posted transactions.");

        account.IsDeleted = true;
        account.IsActive = false;
        account.UpdatedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        return Result<bool>.Success(true);
    }
}

// ── Dashboard Activity Query ───────────────────────────────────────────────────

public record DashboardRecentTxnDto(
    string MemberName, string TransactionType, decimal Amount,
    string AccountNumber, DateTime TransactionDate);

public record DashboardSchemeDistDto(string SchemeType, decimal TotalBalance, int AccountCount);

public record DashboardPendingItemDto(
    string Title, string Subtitle, string ItemType, string Urgency, DateTime CreatedAt);

public record DashboardActivityDto(
    IReadOnlyList<DashboardRecentTxnDto> RecentTransactions,
    IReadOnlyList<DashboardSchemeDistDto> SavingsDistribution,
    IReadOnlyList<DashboardPendingItemDto> PendingItems);

public record GetDashboardActivityQuery() : IRequest<Result<DashboardActivityDto>>;

public class GetDashboardActivityQueryHandler(IAppDbContext db)
    : IRequestHandler<GetDashboardActivityQuery, Result<DashboardActivityDto>>
{
    public async Task<Result<DashboardActivityDto>> Handle(GetDashboardActivityQuery q, CancellationToken ct)
    {
        // ── Recent transactions (last 10 across all savings accounts) ──────────
        var recentTxns = await db.SavingTransactions.AsNoTracking()
            .Where(t => !t.IsDeleted && !t.IsReversed)
            .OrderByDescending(t => t.TransactionDate)
            .Take(10)
            .Select(t => new DashboardRecentTxnDto(
                t.Account!.Member!.FirstName + " " + t.Account.Member.LastName,
                t.TransactionType,
                t.Amount,
                t.Account.AccountNumber,
                t.TransactionDate))
            .ToListAsync(ct);

        // ── Savings distribution by scheme type ───────────────────────────────
        var dist = await db.SavingAccounts.AsNoTracking()
            .Where(a => !a.IsDeleted && a.Status == "Active")
            .GroupBy(a => a.Scheme!.SchemeType)
            .Select(g => new DashboardSchemeDistDto(
                g.Key ?? "Other",
                g.Sum(a => a.CurrentBalance),
                g.Count()))
            .ToListAsync(ct);

        // ── Pending approvals (pending members + pending loan applications) ───
        var pendingMembers = await db.Members.AsNoTracking()
            .Where(m => !m.IsDeleted && m.Status == "Pending")
            .OrderByDescending(m => m.CreatedAt)
            .Take(5)
            .Select(m => new DashboardPendingItemDto(
                "Member Registration – " + m.FirstName + " " + m.LastName,
                "New Member",
                "Member",
                "NORMAL",
                m.CreatedAt))
            .ToListAsync(ct);

        var pendingLoans = await db.Loans.AsNoTracking()
            .Where(l => !l.IsDeleted && l.Status == "Pending")
            .OrderByDescending(l => l.CreatedAt)
            .Take(5)
            .Select(l => new DashboardPendingItemDto(
                "Loan Application – " + l.Member!.FirstName + " " + l.Member.LastName,
                "NPR " + l.AppliedAmount.ToString("N0"),
                "Loan",
                l.AppliedAmount >= 500000 ? "URGENT" : "NORMAL",
                l.CreatedAt))
            .ToListAsync(ct);

        var pending = pendingLoans
            .Concat(pendingMembers)
            .OrderByDescending(p => p.CreatedAt)
            .Take(5)
            .ToList();

        return Result<DashboardActivityDto>.Success(
            new DashboardActivityDto(recentTxns, dist, pending));
    }
}

// ── Get Vouchers Query ────────────────────────────────────────────────────────

public record VoucherEntryDto(string AccountCode, string AccountName, string EntryType, decimal Amount, string? Narration);
public record VoucherListDto(Guid Id, string VoucherNumber, string VoucherType, DateOnly VoucherDate,
    string? Narration, string Status, decimal TotalAmount, List<VoucherEntryDto> Entries);

public record GetVouchersQuery(int Page = 1, int PageSize = 30, string? VoucherType = null)
    : IRequest<Result<PagedResult<VoucherListDto>>>;

public class GetVouchersQueryHandler(IAppDbContext db)
    : IRequestHandler<GetVouchersQuery, Result<PagedResult<VoucherListDto>>>
{
    public async Task<Result<PagedResult<VoucherListDto>>> Handle(GetVouchersQuery q, CancellationToken ct)
    {
        var query = db.Vouchers.AsNoTracking()
            .Include(v => v.Entries).ThenInclude(e => e.Account)
            .Where(v => !v.IsDeleted);

        if (!string.IsNullOrEmpty(q.VoucherType))
            query = query.Where(v => v.VoucherType == q.VoucherType);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(v => v.VoucherDate)
            .ThenByDescending(v => v.CreatedAt)
            .Skip((q.Page - 1) * q.PageSize).Take(Math.Min(q.PageSize, 2000))
            .ToListAsync(ct);

        var dtos = items.Select(v => new VoucherListDto(
            v.Id, v.VoucherNumber, v.VoucherType, v.VoucherDate,
            v.Narration, v.Status,
            v.Entries.Where(e => e.EntryType == "Debit").Sum(e => e.Amount),
            v.Entries.Select(e => new VoucherEntryDto(
                e.Account?.AccountCode ?? "",
                e.Account?.AccountName ?? "",
                e.EntryType, e.Amount, e.Narration)).ToList()
        )).ToList();

        return Result<PagedResult<VoucherListDto>>.Success(
            PagedResult<VoucherListDto>.Create(dtos, q.Page, q.PageSize, total));
    }
}

// ── Get Ledger Query ──────────────────────────────────────────────────────────

public record LedgerEntryDto(string VoucherNumber, string VoucherType, DateOnly VoucherDate,
    string? Narration, string EntryType, decimal Amount, decimal RunningBalance);

public record LedgerDto(string AccountCode, string AccountName, string AccountType,
    decimal OpeningBalance, decimal CurrentBalance,
    List<LedgerEntryDto> Entries, decimal TotalDebit, decimal TotalCredit);

public record GetLedgerQuery(Guid AccountId, DateOnly? FromDate = null, DateOnly? ToDate = null)
    : IRequest<Result<LedgerDto>>;

public class GetLedgerQueryHandler(IAppDbContext db)
    : IRequestHandler<GetLedgerQuery, Result<LedgerDto>>
{
    public async Task<Result<LedgerDto>> Handle(GetLedgerQuery q, CancellationToken ct)
    {
        var account = await db.ChartOfAccounts.AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == q.AccountId && !a.IsDeleted, ct);
        if (account is null)
            return Result<LedgerDto>.Failure("ACCOUNT_NOT_FOUND", "Account not found.");

        var entryQuery = db.VoucherEntries.AsNoTracking()
            .Include(e => e.Voucher)
            .Where(e => e.AccountId == q.AccountId && !e.IsDeleted);

        if (q.FromDate.HasValue)
            entryQuery = entryQuery.Where(e => e.Voucher!.VoucherDate >= q.FromDate.Value);
        if (q.ToDate.HasValue)
            entryQuery = entryQuery.Where(e => e.Voucher!.VoucherDate <= q.ToDate.Value);

        var rawEntries = await entryQuery
            .OrderBy(e => e.Voucher!.VoucherDate)
            .ThenBy(e => e.CreatedAt)
            .ToListAsync(ct);

        // Build running balance
        var runningBalance = 0m;
        var entries = rawEntries.Select(e =>
        {
            var delta = e.EntryType == "Debit" ? e.Amount : -e.Amount;
            runningBalance += delta;
            return new LedgerEntryDto(
                e.Voucher!.VoucherNumber, e.Voucher.VoucherType, e.Voucher.VoucherDate,
                e.Narration ?? e.Voucher.Narration, e.EntryType, e.Amount, runningBalance);
        }).ToList();

        var totalDebit = rawEntries.Where(e => e.EntryType == "Debit").Sum(e => e.Amount);
        var totalCredit = rawEntries.Where(e => e.EntryType == "Credit").Sum(e => e.Amount);

        return Result<LedgerDto>.Success(new LedgerDto(
            account.AccountCode, account.AccountName, account.AccountType,
            0, account.CurrentBalance, entries, totalDebit, totalCredit));
    }
}

// ── Fiscal Year DTOs & Commands ───────────────────────────────────────────────

public record FiscalYearDto(Guid Id, string YearCode, DateOnly StartDate, DateOnly EndDate,
    bool IsCurrent, bool IsClosed, DateTime? ClosedAt);

public record CreateFiscalYearRequest(string YearCode, DateOnly StartDate, DateOnly EndDate);

// ── Get Fiscal Years ──────────────────────────────────────────────────────────

public record GetFiscalYearsQuery() : IRequest<Result<List<FiscalYearDto>>>;

public class GetFiscalYearsQueryHandler(IAppDbContext db)
    : IRequestHandler<GetFiscalYearsQuery, Result<List<FiscalYearDto>>>
{
    public async Task<Result<List<FiscalYearDto>>> Handle(GetFiscalYearsQuery q, CancellationToken ct)
    {
        var years = await db.FiscalYears.AsNoTracking()
            .Where(fy => !fy.IsDeleted)
            .OrderByDescending(fy => fy.StartDate)
            .Select(fy => new FiscalYearDto(fy.Id, fy.YearCode, fy.StartDate, fy.EndDate,
                fy.IsCurrent, fy.IsClosed, fy.ClosedAt))
            .ToListAsync(ct);
        return Result<List<FiscalYearDto>>.Success(years);
    }
}

// ── Create Fiscal Year ────────────────────────────────────────────────────────

public record CreateFiscalYearCommand(CreateFiscalYearRequest Request, Guid ActorId)
    : IRequest<Result<Guid>>;

public class CreateFiscalYearCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<CreateFiscalYearCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateFiscalYearCommand cmd, CancellationToken ct)
    {
        var r = cmd.Request;

        // Validate year code uniqueness
        if (await db.FiscalYears.AnyAsync(fy => fy.YearCode == r.YearCode && !fy.IsDeleted, ct))
            return Result<Guid>.Failure("DUPLICATE_YEAR", $"Fiscal year '{r.YearCode}' already exists.");

        if (r.EndDate <= r.StartDate)
            return Result<Guid>.Failure("INVALID_DATES", "End date must be after start date.");

        var fy = new FiscalYear
        {
            YearCode = r.YearCode,
            StartDate = r.StartDate,
            EndDate = r.EndDate,
            IsCurrent = false,
            IsClosed = false,
            CreatedBy = cmd.ActorId
        };
        await db.FiscalYears.AddAsync(fy, ct);
        await uow.SaveChangesAsync(ct);
        return Result<Guid>.Success(fy.Id);
    }
}

// ── Set Current Fiscal Year ───────────────────────────────────────────────────

public record SetCurrentFiscalYearCommand(Guid FiscalYearId, Guid ActorId) : IRequest<Result<bool>>;

public class SetCurrentFiscalYearCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<SetCurrentFiscalYearCommand, Result<bool>>
{
    public async Task<Result<bool>> Handle(SetCurrentFiscalYearCommand cmd, CancellationToken ct)
    {
        var target = await db.FiscalYears.FindAsync([cmd.FiscalYearId], ct);
        if (target is null) return Result<bool>.Failure("NOT_FOUND", "Fiscal year not found.");
        if (target.IsClosed) return Result<bool>.Failure("YEAR_CLOSED", "Cannot activate a closed fiscal year.");

        // Deactivate any currently active year
        var current = await db.FiscalYears.FirstOrDefaultAsync(fy => fy.IsCurrent && !fy.IsDeleted, ct);
        if (current is not null) current.IsCurrent = false;

        target.IsCurrent = true;
        target.UpdatedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        return Result<bool>.Success(true);
    }
}

// ── Close Fiscal Year ─────────────────────────────────────────────────────────

public record CloseFiscalYearCommand(Guid FiscalYearId, Guid ActorId) : IRequest<Result<bool>>;

public class CloseFiscalYearCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<CloseFiscalYearCommand, Result<bool>>
{
    public async Task<Result<bool>> Handle(CloseFiscalYearCommand cmd, CancellationToken ct)
    {
        var fy = await db.FiscalYears.FindAsync([cmd.FiscalYearId], ct);
        if (fy is null) return Result<bool>.Failure("NOT_FOUND", "Fiscal year not found.");
        if (fy.IsClosed) return Result<bool>.Failure("ALREADY_CLOSED", "Fiscal year is already closed.");

        fy.IsClosed = true;
        fy.IsCurrent = false;
        fy.ClosedAt = DateTime.UtcNow;
        fy.ClosedBy = cmd.ActorId;
        fy.UpdatedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        return Result<bool>.Success(true);
    }
}
