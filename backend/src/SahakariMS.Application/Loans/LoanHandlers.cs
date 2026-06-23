using MediatR;
using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;
using SahakariMS.Domain.Entities;
using SahakariMS.Domain.Interfaces;
using SahakariMS.Shared.Common;

namespace SahakariMS.Application.Loans;

public record ApplyLoanRequest(
    Guid MemberId, Guid LoanProductId, decimal RequestedAmount, int TenureMonths,
    string? LoanPurpose, Guid? DisbursementAccountId,
    List<GuarantorRequest>? Guarantors, List<CollateralRequest>? Collaterals);

public record GuarantorRequest(Guid MemberId, decimal ShareAmount);
public record CollateralRequest(string Type, string Description, decimal EstimatedValue);
public record LoanPaymentRequest(decimal Amount, string PaymentMode, DateTime PaymentDate, string? Narration);
public record LoanPaymentResponse(string ReceiptNumber, decimal PrincipalPaid, decimal InterestPaid,
    decimal PenaltyPaid, decimal OutstandingBalance, DateOnly? NextEmiDate);
public record EmiScheduleDto(int InstallmentNo, DateOnly DueDate, decimal EmiAmount,
    decimal PrincipalAmount, decimal InterestAmount, decimal OutstandingBalance, string Status);

// ── Apply Loan ────────────────────────────────────────────────────────────────

public record ApplyLoanCommand(ApplyLoanRequest Request, Guid ActorId) : IRequest<Result<Guid>>;

public class ApplyLoanCommandHandler(IAppDbContext db, IUnitOfWork uow, ISequenceGenerator seq)
    : IRequestHandler<ApplyLoanCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(ApplyLoanCommand cmd, CancellationToken ct)
    {
        var r = cmd.Request;
        var product = await db.LoanProducts.FindAsync([r.LoanProductId], ct);
        if (product is null) return Result<Guid>.Failure("PRODUCT_NOT_FOUND", "Loan product not found.");

        var member = await db.Members.FindAsync([r.MemberId], ct);
        if (member is null || member.Status != "Active")
            return Result<Guid>.Failure("MEMBER_INVALID", "Member not found or not active.");

        if (r.RequestedAmount < product.MinAmount || r.RequestedAmount > product.MaxAmount)
            return Result<Guid>.Failure("INVALID_AMOUNT",
                $"Amount must be between NPR {product.MinAmount:N0} and NPR {product.MaxAmount:N0}.");

        var year   = DateTime.UtcNow.Year + 57;
        var branch = await db.Branches.FindAsync([member.BranchId], ct);
        var loanNo = await seq.NextLoanNumberAsync(branch!.BranchCode, year);
        var emi    = Loan.CalculateEmi(r.RequestedAmount, product.InterestRate, r.TenureMonths);

        var loan = new Loan
        {
            MemberId = r.MemberId, BranchId = member.BranchId, ProductId = r.LoanProductId,
            LoanNumber = loanNo, AppliedAmount = r.RequestedAmount,
            InterestRate = product.InterestRate, TenureMonths = r.TenureMonths,
            EmiAmount = emi, LoanPurpose = r.LoanPurpose,
            DisbursementAccountId = r.DisbursementAccountId,
            Status = "Pending", AppliedDate = DateOnly.FromDateTime(DateTime.UtcNow),
            CreatedBy = cmd.ActorId
        };

        if (r.Guarantors != null)
            foreach (var g in r.Guarantors)
                loan.Guarantors.Add(new LoanGuarantor { GuarantorMemberId = g.MemberId, ShareAmount = g.ShareAmount });

        if (r.Collaterals != null)
            foreach (var c in r.Collaterals)
                loan.Collaterals.Add(new LoanCollateral { CollateralType = c.Type, Description = c.Description, EstimatedValue = c.EstimatedValue });

        await db.Loans.AddAsync(loan, ct);
        await uow.SaveChangesAsync(ct);
        return Result<Guid>.Success(loan.Id);
    }
}

// ── Approve Loan ──────────────────────────────────────────────────────────────

public record ApproveLoanCommand(Guid LoanId, decimal ApprovedAmount, string? Remarks, Guid ActorId) : IRequest<Result>;

public class ApproveLoanCommandHandler(IAppDbContext db, IUnitOfWork uow) : IRequestHandler<ApproveLoanCommand, Result>
{
    public async Task<Result> Handle(ApproveLoanCommand cmd, CancellationToken ct)
    {
        var loan = await db.Loans.FindAsync([cmd.LoanId], ct);
        if (loan is null) return Result.Failure("LOAN_NOT_FOUND", "Loan not found.");
        if (loan.Status != "Pending") return Result.Failure("INVALID_STATUS", "Only pending loans can be approved.");
        loan.Status = "Approved"; loan.ApprovedAmount = cmd.ApprovedAmount;
        loan.ApprovedDate = DateOnly.FromDateTime(DateTime.UtcNow);
        loan.ApprovalRemarks = cmd.Remarks; loan.ApprovedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        return Result.Success();
    }
}

// ── Disburse Loan ─────────────────────────────────────────────────────────────

public record DisburseLoanCommand(Guid LoanId, decimal DisbursedAmount, string Mode, DateOnly Date, Guid ActorId) : IRequest<Result>;

public class DisburseLoanCommandHandler(IAppDbContext db, IUnitOfWork uow) : IRequestHandler<DisburseLoanCommand, Result>
{
    public async Task<Result> Handle(DisburseLoanCommand cmd, CancellationToken ct)
    {
        var loan = await db.Loans.FindAsync([cmd.LoanId], ct);
        if (loan is null) return Result.Failure("LOAN_NOT_FOUND", "Loan not found.");
        if (loan.Status != "Approved") return Result.Failure("INVALID_STATUS", "Only approved loans can be disbursed.");

        loan.Status = "Active"; loan.DisbursedAmount = cmd.DisbursedAmount;
        loan.OutstandingBalance = cmd.DisbursedAmount; loan.DisbursedDate = cmd.Date;
        loan.NextEmiDate = cmd.Date.AddMonths(1); loan.DisbursedBy = cmd.ActorId;

        var balance = cmd.DisbursedAmount;
        var r = loan.InterestRate / 100 / 12;
        for (int i = 1; i <= loan.TenureMonths; i++)
        {
            var interest  = Math.Round(balance * r, 2);
            var principal = i == loan.TenureMonths ? balance : Math.Round(loan.EmiAmount - interest, 2);
            balance -= principal;
            loan.EmiSchedule.Add(new LoanEmiSchedule
            {
                InstallmentNo = i, DueDate = cmd.Date.AddMonths(i), EmiAmount = loan.EmiAmount,
                PrincipalAmount = principal, InterestAmount = interest,
                OutstandingBalance = Math.Max(0, balance)
            });
        }
        await uow.SaveChangesAsync(ct);
        return Result.Success();
    }
}

// ── Make Payment ──────────────────────────────────────────────────────────────

public record MakePaymentCommand(Guid LoanId, LoanPaymentRequest Request, Guid ActorId)
    : IRequest<Result<LoanPaymentResponse>>;

public class MakePaymentCommandHandler(IAppDbContext db, IUnitOfWork uow, ISequenceGenerator seq)
    : IRequestHandler<MakePaymentCommand, Result<LoanPaymentResponse>>
{
    public async Task<Result<LoanPaymentResponse>> Handle(MakePaymentCommand cmd, CancellationToken ct)
    {
        var loan = await db.Loans.Include(l => l.EmiSchedule)
            .FirstOrDefaultAsync(l => l.Id == cmd.LoanId, ct);
        if (loan is null) return Result<LoanPaymentResponse>.Failure("LOAN_NOT_FOUND", "Loan not found.");
        if (loan.Status != "Active") return Result<LoanPaymentResponse>.Failure("INVALID_STATUS", "Loan is not active.");

        var r = cmd.Request;
        var interestDue  = Math.Round(loan.OutstandingBalance * loan.InterestRate / 100 / 12, 2);
        var interestPaid = Math.Min(r.Amount, interestDue);
        var principalPaid = Math.Max(0, r.Amount - interestPaid);

        loan.OutstandingBalance -= principalPaid;
        if (loan.OutstandingBalance <= 0) { loan.OutstandingBalance = 0; loan.Status = "Closed"; loan.ClosedDate = DateOnly.FromDateTime(DateTime.UtcNow); }
        loan.NextEmiDate = loan.NextEmiDate?.AddMonths(1);

        var receipt = await seq.NextReceiptNumberAsync(loan.BranchId);
        await db.LoanPayments.AddAsync(new LoanPayment
        {
            LoanId = loan.Id, ReceiptNumber = receipt, TotalPaid = r.Amount,
            PrincipalPaid = principalPaid, InterestPaid = interestPaid, PenaltyPaid = 0,
            PaymentMode = r.PaymentMode, PaymentDate = r.PaymentDate, Narration = r.Narration,
            BalanceAfter = loan.OutstandingBalance, ProcessedBy = cmd.ActorId
        }, ct);
        await uow.SaveChangesAsync(ct);

        return Result<LoanPaymentResponse>.Success(new LoanPaymentResponse(
            receipt, principalPaid, interestPaid, 0, loan.OutstandingBalance, loan.NextEmiDate));
    }
}

// ── Get EMI Schedule ──────────────────────────────────────────────────────────

public record GetEmiScheduleQuery(Guid LoanId) : IRequest<Result<List<EmiScheduleDto>>>;

public class GetEmiScheduleQueryHandler(IAppDbContext db)
    : IRequestHandler<GetEmiScheduleQuery, Result<List<EmiScheduleDto>>>
{
    public async Task<Result<List<EmiScheduleDto>>> Handle(GetEmiScheduleQuery q, CancellationToken ct)
    {
        var schedule = await db.LoanEmiSchedules.AsNoTracking()
            .Where(e => e.LoanId == q.LoanId).OrderBy(e => e.InstallmentNo)
            .Select(e => new EmiScheduleDto(e.InstallmentNo, e.DueDate, e.EmiAmount,
                e.PrincipalAmount, e.InterestAmount, e.OutstandingBalance, e.Status))
            .ToListAsync(ct);

        if (!schedule.Any()) return Result<List<EmiScheduleDto>>.Failure("NOT_FOUND", "No schedule found.");
        return Result<List<EmiScheduleDto>>.Success(schedule);
    }
}

// ── Get Loans Query ───────────────────────────────────────────────────────────

public record LoanListDto(
    Guid Id, string LoanNumber, string MemberName, string ProductName,
    decimal AppliedAmount, decimal OutstandingBalance, decimal EmiAmount,
    string Status, DateOnly? NextEmiDate, int OverdueDays);

public record GetLoansQuery(
    int Page = 1, int PageSize = 20, string? Search = null,
    string? Status = null, Guid? BranchId = null)
    : IRequest<Result<PagedResult<LoanListDto>>>;

public class GetLoansQueryHandler(IAppDbContext db)
    : IRequestHandler<GetLoansQuery, Result<PagedResult<LoanListDto>>>
{
    public async Task<Result<PagedResult<LoanListDto>>> Handle(GetLoansQuery q, CancellationToken ct)
    {
        var query = db.Loans.AsNoTracking()
            .Include(l => l.Member)
            .Include(l => l.Product)
            .Where(l => !l.IsDeleted);

        if (!string.IsNullOrEmpty(q.Search))
            query = query.Where(l =>
                l.LoanNumber.Contains(q.Search) ||
                l.Member.FirstName.Contains(q.Search) ||
                l.Member.LastName.Contains(q.Search));

        if (!string.IsNullOrEmpty(q.Status))
            query = query.Where(l => l.Status == q.Status);

        if (q.BranchId.HasValue)
            query = query.Where(l => l.BranchId == q.BranchId);

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(l => l.CreatedAt)
            .Skip((q.Page - 1) * q.PageSize).Take(Math.Min(q.PageSize, 100))
            .Select(l => new LoanListDto(
                l.Id, l.LoanNumber,
                l.Member.FirstName + (l.Member.MiddleName != null ? " " + l.Member.MiddleName : "") + " " + l.Member.LastName,
                l.Product.ProductName,
                l.AppliedAmount, l.OutstandingBalance, l.EmiAmount,
                l.Status, l.NextEmiDate,
                l.Status == "Active" && l.NextEmiDate.HasValue && l.NextEmiDate.Value < today
                    ? today.DayNumber - l.NextEmiDate.Value.DayNumber : 0))
            .ToListAsync(ct);

        return Result<PagedResult<LoanListDto>>.Success(
            PagedResult<LoanListDto>.Create(items, q.Page, q.PageSize, total));
    }
}

