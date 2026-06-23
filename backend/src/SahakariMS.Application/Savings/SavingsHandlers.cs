using MediatR;
using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;
using SahakariMS.Domain.Entities;
using SahakariMS.Domain.Interfaces;
using SahakariMS.Shared.Common;

namespace SahakariMS.Application.Savings;

public record DepositRequest(decimal Amount, string DepositMode, string? Narration, Guid? CollectedBy);
public record WithdrawRequest(decimal Amount, string WithdrawalMode, string? Narration, Guid? VerifiedById);
public record TransactionResponse(Guid TransactionId, string ReceiptNumber, decimal Amount,
    decimal BalanceAfter, DateTime TransactionDate);

// ── Deposit Command ───────────────────────────────────────────────────────────

public record DepositCommand(Guid AccountId, DepositRequest Request, Guid ActorId)
    : IRequest<Result<TransactionResponse>>;

public class DepositCommandHandler(IAppDbContext db, IUnitOfWork uow, ISequenceGenerator seq)
    : IRequestHandler<DepositCommand, Result<TransactionResponse>>
{
    public async Task<Result<TransactionResponse>> Handle(DepositCommand cmd, CancellationToken ct)
    {
        var account = await db.SavingAccounts.Include(a => a.Scheme)
            .FirstOrDefaultAsync(a => a.Id == cmd.AccountId && !a.IsDeleted, ct);

        if (account is null)
            return Result<TransactionResponse>.Failure("ACCOUNT_NOT_FOUND", "Savings account not found.");
        if (account.IsFrozen)
            return Result<TransactionResponse>.Failure("ACCOUNT_FROZEN", "Account is frozen.");
        if (account.Status != "Active")
            return Result<TransactionResponse>.Failure("ACCOUNT_INACTIVE", "Account is not active.");

        var r = cmd.Request;
        if (r.Amount <= 0)
            return Result<TransactionResponse>.Failure("INVALID_AMOUNT", "Deposit amount must be greater than zero.");

        account.CurrentBalance += r.Amount;
        var receipt = await seq.NextReceiptNumberAsync(account.BranchId);

        var txn = new SavingTransaction
        {
            AccountId = account.Id, BranchId = account.BranchId,
            TransactionType = "Deposit", Amount = r.Amount,
            BalanceAfter = account.CurrentBalance, DepositMode = r.DepositMode,
            ReceiptNumber = receipt, Narration = r.Narration,
            TransactionDate = DateTime.UtcNow, ProcessedBy = cmd.ActorId
        };
        await db.SavingTransactions.AddAsync(txn, ct);
        await uow.SaveChangesAsync(ct);

        return Result<TransactionResponse>.Success(
            new TransactionResponse(txn.Id, receipt, r.Amount, account.CurrentBalance, txn.TransactionDate));
    }
}

// ── Withdraw Command ──────────────────────────────────────────────────────────

public record WithdrawCommand(Guid AccountId, WithdrawRequest Request, Guid ActorId)
    : IRequest<Result<TransactionResponse>>;

public class WithdrawCommandHandler(IAppDbContext db, IUnitOfWork uow, ISequenceGenerator seq)
    : IRequestHandler<WithdrawCommand, Result<TransactionResponse>>
{
    public async Task<Result<TransactionResponse>> Handle(WithdrawCommand cmd, CancellationToken ct)
    {
        var account = await db.SavingAccounts.Include(a => a.Scheme)
            .FirstOrDefaultAsync(a => a.Id == cmd.AccountId && !a.IsDeleted, ct);

        if (account is null)
            return Result<TransactionResponse>.Failure("ACCOUNT_NOT_FOUND", "Savings account not found.");
        if (account.IsFrozen)
            return Result<TransactionResponse>.Failure("ACCOUNT_FROZEN", "Account is frozen.");

        var r = cmd.Request;
        var minBalance = account.Scheme?.MinimumBalance ?? 0;
        if (account.CurrentBalance - r.Amount < minBalance)
            return Result<TransactionResponse>.Failure("INSUFFICIENT_BALANCE",
                $"Minimum balance of NPR {minBalance:N2} must be maintained.");

        account.CurrentBalance -= r.Amount;
        var receipt = await seq.NextReceiptNumberAsync(account.BranchId);

        var txn = new SavingTransaction
        {
            AccountId = account.Id, BranchId = account.BranchId,
            TransactionType = "Withdrawal", Amount = r.Amount,
            BalanceAfter = account.CurrentBalance, DepositMode = r.WithdrawalMode,
            ReceiptNumber = receipt, Narration = r.Narration,
            TransactionDate = DateTime.UtcNow, ProcessedBy = cmd.ActorId
        };
        await db.SavingTransactions.AddAsync(txn, ct);
        await uow.SaveChangesAsync(ct);

        return Result<TransactionResponse>.Success(
            new TransactionResponse(txn.Id, receipt, r.Amount, account.CurrentBalance, txn.TransactionDate));
    }
}

// ── Get Saving Account By Number ──────────────────────────────────────────────

public record GetSavingAccountByNumberQuery(string AccountNumber)
    : IRequest<Result<SavingAccountDetailDto>>;

public class GetSavingAccountByNumberQueryHandler(IAppDbContext db)
    : IRequestHandler<GetSavingAccountByNumberQuery, Result<SavingAccountDetailDto>>
{
    public async Task<Result<SavingAccountDetailDto>> Handle(GetSavingAccountByNumberQuery q, CancellationToken ct)
    {
        var account = await db.SavingAccounts.AsNoTracking()
            .Include(a => a.Member)
            .Include(a => a.Scheme)
            .Include(a => a.Branch)
            .FirstOrDefaultAsync(a => a.AccountNumber == q.AccountNumber && !a.IsDeleted, ct);

        if (account is null)
            return Result<SavingAccountDetailDto>.Failure("ACCOUNT_NOT_FOUND", $"No account found with number '{q.AccountNumber}'.");

        var memberName = account.Member != null
            ? account.Member.FirstName +
              (account.Member.MiddleName != null ? " " + account.Member.MiddleName : "") +
              " " + account.Member.LastName
            : "Unknown";

        var txnStats = await db.SavingTransactions.AsNoTracking()
            .Where(t => t.AccountId == account.Id)
            .GroupBy(_ => 1)
            .Select(g => new
            {
                TotalDeposits    = g.Where(t => t.TransactionType == "Deposit").Sum(t => (decimal?)t.Amount) ?? 0,
                TotalWithdrawals = g.Where(t => t.TransactionType == "Withdrawal").Sum(t => (decimal?)t.Amount) ?? 0,
                TotalInterest    = g.Where(t => t.TransactionType == "Interest").Sum(t => (decimal?)t.Amount) ?? 0,
            })
            .FirstOrDefaultAsync(ct);

        return Result<SavingAccountDetailDto>.Success(new SavingAccountDetailDto(
            account.Id,
            account.AccountNumber,
            memberName,
            account.MemberId.ToString(),
            account.Scheme?.SchemeType ?? "Regular",
            account.Scheme?.SchemeName ?? "Standard",
            account.Scheme?.SchemeCode ?? "",
            account.CurrentBalance,
            account.Status,
            account.OpenDate,
            account.Scheme?.InterestRate ?? 0,
            account.Scheme?.MinimumBalance ?? 0,
            account.Scheme?.MinimumDeposit,
            account.Scheme?.WithdrawalAllowed ?? true,
            account.Branch?.BranchName ?? "Head Office",
            txnStats?.TotalDeposits ?? 0,
            txnStats?.TotalWithdrawals ?? 0,
            txnStats?.TotalInterest ?? 0));
    }
}

// ── Get Saving Accounts Query ─────────────────────────────────────────────────

public record SavingAccountListDto(
    Guid Id, string AccountNumber, string MemberName, string AccountType,
    decimal Balance, string Status, DateTime? LastTransactionDate);

public record GetSavingAccountsQuery(
    int Page = 1, int PageSize = 20, string? Search = null,
    string? AccountType = null, Guid? BranchId = null)
    : IRequest<Result<PagedResult<SavingAccountListDto>>>;

public class GetSavingAccountsQueryHandler(IAppDbContext db)
    : IRequestHandler<GetSavingAccountsQuery, Result<PagedResult<SavingAccountListDto>>>
{
    public async Task<Result<PagedResult<SavingAccountListDto>>> Handle(GetSavingAccountsQuery q, CancellationToken ct)
    {
        var query = db.SavingAccounts.AsNoTracking()
            .Include(a => a.Member)
            .Include(a => a.Scheme)
            .Where(a => !a.IsDeleted);

        if (!string.IsNullOrEmpty(q.Search))
            query = query.Where(a =>
                a.AccountNumber.Contains(q.Search) ||
                a.Member.FirstName.Contains(q.Search) ||
                a.Member.LastName.Contains(q.Search));

        if (!string.IsNullOrEmpty(q.AccountType))
            query = query.Where(a => a.Scheme!.SchemeType == q.AccountType);

        if (q.BranchId.HasValue)
            query = query.Where(a => a.BranchId == q.BranchId);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(a => a.UpdatedAt)
            .Skip((q.Page - 1) * q.PageSize).Take(Math.Min(q.PageSize, 100))
            .Select(a => new SavingAccountListDto(
                a.Id, a.AccountNumber,
                a.Member!.FirstName + (a.Member.MiddleName != null ? " " + a.Member.MiddleName : "") + " " + a.Member.LastName,
                a.Scheme!.SchemeType, a.CurrentBalance, a.Status,
                db.SavingTransactions
                    .Where(t => t.AccountId == a.Id)
                    .OrderByDescending(t => t.TransactionDate)
                    .Select(t => (DateTime?)t.TransactionDate)
                    .FirstOrDefault()))
            .ToListAsync(ct);

        return Result<PagedResult<SavingAccountListDto>>.Success(
            PagedResult<SavingAccountListDto>.Create(items, q.Page, q.PageSize, total));
    }
}
// ── Get Saving Schemes Query ──────────────────────────────────────────────────

public record SavingSchemeDto(
    Guid Id, string SchemeCode, string SchemeName, string SchemeType,
    decimal InterestRate, decimal MinimumBalance, decimal? MinimumDeposit,
    int? MinTenureMonths, int? MaxTenureMonths, bool WithdrawalAllowed);

public record GetSavingSchemesQuery() : IRequest<Result<List<SavingSchemeDto>>>;

public class GetSavingSchemesQueryHandler(IAppDbContext db)
    : IRequestHandler<GetSavingSchemesQuery, Result<List<SavingSchemeDto>>>
{
    public async Task<Result<List<SavingSchemeDto>>> Handle(GetSavingSchemesQuery q, CancellationToken ct)
    {
        var schemes = await db.SavingSchemes.AsNoTracking()
            .Where(s => s.IsActive && !s.IsDeleted)
            .OrderBy(s => s.SchemeType).ThenBy(s => s.SchemeName)
            .Select(s => new SavingSchemeDto(
                s.Id, s.SchemeCode, s.SchemeName, s.SchemeType,
                s.InterestRate, s.MinimumBalance, s.MinimumDeposit,
                s.MinTenureMonths, s.MaxTenureMonths, s.WithdrawalAllowed))
            .ToListAsync(ct);

        return Result<List<SavingSchemeDto>>.Success(schemes);
    }
}

// ── Open Saving Account Command ───────────────────────────────────────────────

public record OpenSavingAccountRequest(Guid MemberId, Guid SchemeId, decimal InitialDeposit, string DepositMode, string? CustomAccountNumber);
public record OpenSavingAccountResponse(Guid AccountId, string AccountNumber, decimal Balance);

public record OpenSavingAccountCommand(OpenSavingAccountRequest Request, Guid BranchId, Guid ActorId)
    : IRequest<Result<OpenSavingAccountResponse>>;

public class OpenSavingAccountCommandHandler(IAppDbContext db, IUnitOfWork uow, ISequenceGenerator seq)
    : IRequestHandler<OpenSavingAccountCommand, Result<OpenSavingAccountResponse>>
{
    public async Task<Result<OpenSavingAccountResponse>> Handle(OpenSavingAccountCommand cmd, CancellationToken ct)
    {
        var r = cmd.Request;

        var member = await db.Members.FirstOrDefaultAsync(m => m.Id == r.MemberId && !m.IsDeleted, ct);
        if (member is null)
            return Result<OpenSavingAccountResponse>.Failure("MEMBER_NOT_FOUND", "Member not found.");
        if (member.Status == "Suspended")
            return Result<OpenSavingAccountResponse>.Failure("MEMBER_SUSPENDED", "Suspended members cannot open a savings account.");

        var scheme = await db.SavingSchemes.FirstOrDefaultAsync(s => s.Id == r.SchemeId && s.IsActive && !s.IsDeleted, ct);
        if (scheme is null)
            return Result<OpenSavingAccountResponse>.Failure("SCHEME_NOT_FOUND", "Savings scheme not found.");

        if (r.InitialDeposit < (scheme.MinimumDeposit ?? 0))
            return Result<OpenSavingAccountResponse>.Failure("MIN_DEPOSIT",
                $"Minimum initial deposit for this scheme is NPR {scheme.MinimumDeposit:N2}.");

        // Determine account number: use custom if provided, else auto-generate
        string accountNumber;
        if (!string.IsNullOrWhiteSpace(r.CustomAccountNumber))
        {
            // Validate uniqueness
            var exists = await db.SavingAccounts.AnyAsync(
                a => a.AccountNumber == r.CustomAccountNumber && !a.IsDeleted, ct);
            if (exists)
                return Result<OpenSavingAccountResponse>.Failure(
                    "ACCOUNT_NUMBER_TAKEN",
                    $"Account number '{r.CustomAccountNumber}' is already in use.");
            accountNumber = r.CustomAccountNumber.Trim().ToUpperInvariant();
        }
        else
        {
            // Auto-generate e.g. SAV-2082-00001
            var year = DateTime.UtcNow.Year + 57;
            accountNumber = await seq.NextAccountNumberAsync("SAV", year);
        }

        var account = new SavingAccount
        {
            MemberId    = r.MemberId,
            BranchId    = cmd.BranchId,
            SchemeId    = r.SchemeId,
            AccountNumber = accountNumber,
            CurrentBalance = r.InitialDeposit,
            Status      = "Active",
            OpenDate    = DateOnly.FromDateTime(DateTime.UtcNow),
            CreatedBy   = cmd.ActorId,
        };
        await db.SavingAccounts.AddAsync(account, ct);

        // Record opening deposit transaction
        if (r.InitialDeposit > 0)
        {
            var receipt = await seq.NextReceiptNumberAsync(cmd.BranchId);
            var txn = new SavingTransaction
            {
                AccountId        = account.Id,
                BranchId         = cmd.BranchId,
                TransactionType  = "Deposit",
                Amount           = r.InitialDeposit,
                BalanceAfter     = r.InitialDeposit,
                DepositMode      = r.DepositMode,
                ReceiptNumber    = receipt,
                Narration        = "Account opening deposit",
                TransactionDate  = DateTime.UtcNow,
                ProcessedBy      = cmd.ActorId,
            };
            await db.SavingTransactions.AddAsync(txn, ct);
        }

        await uow.SaveChangesAsync(ct);
        return Result<OpenSavingAccountResponse>.Success(
            new OpenSavingAccountResponse(account.Id, accountNumber, account.CurrentBalance));
    }
}

// ── Get Saving Account Detail Query ──────────────────────────────────────────

public record SavingAccountDetailDto(
    Guid Id, string AccountNumber, string MemberName, string MemberId,
    string AccountType, string SchemeName, string SchemeCode,
    decimal Balance, string Status, DateOnly OpenDate,
    decimal InterestRate, decimal MinimumBalance, decimal? MinimumDeposit,
    bool WithdrawalAllowed, string Branch,
    decimal TotalDeposits, decimal TotalWithdrawals, decimal TotalInterest);

public record GetSavingAccountDetailQuery(Guid AccountId)
    : IRequest<Result<SavingAccountDetailDto>>;

public class GetSavingAccountDetailQueryHandler(IAppDbContext db)
    : IRequestHandler<GetSavingAccountDetailQuery, Result<SavingAccountDetailDto>>
{
    public async Task<Result<SavingAccountDetailDto>> Handle(GetSavingAccountDetailQuery q, CancellationToken ct)
    {
        var account = await db.SavingAccounts.AsNoTracking()
            .Include(a => a.Member)
            .Include(a => a.Scheme)
            .Include(a => a.Branch)
            .FirstOrDefaultAsync(a => a.Id == q.AccountId && !a.IsDeleted, ct);

        if (account is null)
            return Result<SavingAccountDetailDto>.Failure("ACCOUNT_NOT_FOUND", "Savings account not found.");

        var memberName = account.Member != null
            ? account.Member.FirstName +
              (account.Member.MiddleName != null ? " " + account.Member.MiddleName : "") +
              " " + account.Member.LastName
            : "Unknown";

        var txnStats = await db.SavingTransactions.AsNoTracking()
            .Where(t => t.AccountId == account.Id)
            .GroupBy(_ => 1)
            .Select(g => new
            {
                TotalDeposits = g.Where(t => t.TransactionType == "Deposit").Sum(t => (decimal?)t.Amount) ?? 0,
                TotalWithdrawals = g.Where(t => t.TransactionType == "Withdrawal").Sum(t => (decimal?)t.Amount) ?? 0,
                TotalInterest = g.Where(t => t.TransactionType == "Interest").Sum(t => (decimal?)t.Amount) ?? 0,
            })
            .FirstOrDefaultAsync(ct);

        return Result<SavingAccountDetailDto>.Success(new SavingAccountDetailDto(
            account.Id,
            account.AccountNumber,
            memberName,
            account.MemberId.ToString(),
            account.Scheme?.SchemeType ?? "Regular",
            account.Scheme?.SchemeName ?? "Standard",
            account.Scheme?.SchemeCode ?? "",
            account.CurrentBalance,
            account.Status,
            account.OpenDate,
            account.Scheme?.InterestRate ?? 0,
            account.Scheme?.MinimumBalance ?? 0,
            account.Scheme?.MinimumDeposit,
            account.Scheme?.WithdrawalAllowed ?? true,
            account.Branch?.BranchName ?? "Head Office",
            txnStats?.TotalDeposits ?? 0,
            txnStats?.TotalWithdrawals ?? 0,
            txnStats?.TotalInterest ?? 0));
    }
}

// ── Get Saving Transactions Query ─────────────────────────────────────────────

public record SavingTransactionDto(
    Guid Id, string ReceiptNumber, string TransactionType,
    decimal Amount, decimal BalanceAfter, string Mode,
    string? Narration, DateTime TransactionDate);

public record GetSavingTransactionsQuery(Guid AccountId, int Page = 1, int PageSize = 30)
    : IRequest<Result<PagedResult<SavingTransactionDto>>>;

public class GetSavingTransactionsQueryHandler(IAppDbContext db)
    : IRequestHandler<GetSavingTransactionsQuery, Result<PagedResult<SavingTransactionDto>>>
{
    public async Task<Result<PagedResult<SavingTransactionDto>>> Handle(GetSavingTransactionsQuery q, CancellationToken ct)
    {
        var exists = await db.SavingAccounts.AnyAsync(a => a.Id == q.AccountId && !a.IsDeleted, ct);
        if (!exists)
            return Result<PagedResult<SavingTransactionDto>>.Failure("ACCOUNT_NOT_FOUND", "Savings account not found.");

        var total = await db.SavingTransactions
            .Where(t => t.AccountId == q.AccountId)
            .CountAsync(ct);

        var items = await db.SavingTransactions.AsNoTracking()
            .Where(t => t.AccountId == q.AccountId)
            .OrderByDescending(t => t.TransactionDate)
            .Skip((q.Page - 1) * q.PageSize).Take(Math.Min(q.PageSize, 100))
            .Select(t => new SavingTransactionDto(
                t.Id, t.ReceiptNumber, t.TransactionType,
                t.Amount, t.BalanceAfter,
                t.DepositMode ?? "Cash",
                t.Narration, t.TransactionDate))
            .ToListAsync(ct);

        return Result<PagedResult<SavingTransactionDto>>.Success(
            PagedResult<SavingTransactionDto>.Create(items, q.Page, q.PageSize, total));
    }
}
