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
