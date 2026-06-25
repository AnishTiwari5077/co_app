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
    decimal PenaltyPaid, decimal OutstandingBalance, DateOnly? NextEmiDate,
    int? InstallmentNo = null, DateOnly? EmiDueDate = null);
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
        if (member is null)
            return Result<Guid>.Failure("MEMBER_NOT_FOUND", "Member not found.");
        if (member.Status != "Active")
            return Result<Guid>.Failure("MEMBER_INVALID", $"Member status is '{member.Status}'. Only Active members can apply for loans.");

        if (r.RequestedAmount < product.MinAmount || r.RequestedAmount > product.MaxAmount)
            return Result<Guid>.Failure("INVALID_AMOUNT",
                $"Amount must be between NPR {product.MinAmount:N0} and NPR {product.MaxAmount:N0}.");

        var year   = DateTime.UtcNow.Year + 57;
        var branch = await db.Branches.FindAsync([member.BranchId], ct);
        if (branch is null)
            return Result<Guid>.Failure("BRANCH_NOT_FOUND", $"Branch for this member (Id: {member.BranchId}) was not found.");

        var loanNo = await seq.NextLoanNumberAsync(branch.BranchCode, year);
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

        // Remove any existing EMI schedules (cleanup from previous failed attempt)
        var existingSchedules = db.LoanEmiSchedules.Where(s => s.LoanId == cmd.LoanId);
        db.LoanEmiSchedules.RemoveRange(existingSchedules);

        var balance = cmd.DisbursedAmount;
        var r = loan.InterestRate / 100 / 12;
        var newSchedules = new List<LoanEmiSchedule>();
        for (int i = 1; i <= loan.TenureMonths; i++)
        {
            var interest  = Math.Round(balance * r, 2);
            var principal = i == loan.TenureMonths ? balance : Math.Round(loan.EmiAmount - interest, 2);
            balance -= principal;
            newSchedules.Add(new LoanEmiSchedule
            {
                LoanId = cmd.LoanId,
                InstallmentNo = i, DueDate = cmd.Date.AddMonths(i), EmiAmount = loan.EmiAmount,
                PrincipalAmount = principal, InterestAmount = interest,
                OutstandingBalance = Math.Max(0, balance),
                CreatedBy = cmd.ActorId
            });
        }
        await db.LoanEmiSchedules.AddRangeAsync(newSchedules, ct);
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

        // ── Find the next EMI installment to mark as Paid ─────────────────────
        var nextEmi = loan.EmiSchedule
            .Where(e => e.Status is "Pending" or "Overdue")
            .OrderBy(e => e.InstallmentNo)
            .FirstOrDefault();

        var r = cmd.Request;
        decimal principalPaid, interestPaid;

        if (nextEmi != null)
        {
            // Use the EMI schedule's exact amounts
            principalPaid = nextEmi.PrincipalAmount;
            interestPaid  = nextEmi.InterestAmount;

            // If the user paid a different amount handle partial/excess
            var totalDue = nextEmi.PrincipalAmount + nextEmi.InterestAmount;
            if (r.Amount != totalDue)
            {
                // Proportionally split by the EMI's ratio
                interestPaid  = Math.Round(nextEmi.InterestAmount / totalDue * r.Amount, 2);
                principalPaid = Math.Round(r.Amount - interestPaid, 2);
            }

            nextEmi.PaidAmount = r.Amount;
            nextEmi.PaidDate   = DateTime.SpecifyKind(r.PaymentDate.ToUniversalTime(), DateTimeKind.Utc);
            nextEmi.Status     = r.Amount >= (nextEmi.PrincipalAmount + nextEmi.InterestAmount) ? "Paid" : "PartPaid";
        }
        else
        {
            // No more EMIs (all paid already) — treat as overpayment
            var interestDue = Math.Round(loan.OutstandingBalance * loan.InterestRate / 100 / 12, 2);
            interestPaid  = Math.Min(r.Amount, interestDue);
            principalPaid = Math.Max(0, r.Amount - interestPaid);
        }

        loan.OutstandingBalance -= principalPaid;
        if (loan.OutstandingBalance <= 0)
        {
            loan.OutstandingBalance = 0;
            loan.Status = "Closed";
            loan.ClosedDate = DateOnly.FromDateTime(DateTime.UtcNow);
            // Mark any remaining EMIs as Waived
            foreach (var e in loan.EmiSchedule.Where(e => e.Status is "Pending" or "Overdue"))
                e.Status = "Waived";
        }
        else if (nextEmi != null)
        {
            // Advance NextEmiDate to the NEXT unpaid installment's due date
            var nextUnpaid = loan.EmiSchedule
                .Where(e => e.Status is "Pending" or "Overdue" && e.InstallmentNo != nextEmi.InstallmentNo)
                .OrderBy(e => e.InstallmentNo)
                .FirstOrDefault();
            loan.NextEmiDate = nextUnpaid?.DueDate ?? loan.NextEmiDate?.AddMonths(1);
        }

        var receipt = await seq.NextReceiptNumberAsync(loan.BranchId);
        await db.LoanPayments.AddAsync(new LoanPayment
        {
            LoanId = loan.Id, ReceiptNumber = receipt, TotalPaid = r.Amount,
            PrincipalPaid = principalPaid, InterestPaid = interestPaid, PenaltyPaid = 0,
            PaymentMode = r.PaymentMode,
            PaymentDate = DateTime.SpecifyKind(r.PaymentDate.ToUniversalTime(), DateTimeKind.Utc),
            Narration = r.Narration,
            BalanceAfter = loan.OutstandingBalance, ProcessedBy = cmd.ActorId
        }, ct);
        await uow.SaveChangesAsync(ct);

        return Result<LoanPaymentResponse>.Success(new LoanPaymentResponse(
            receipt, principalPaid, interestPaid, 0,
            loan.OutstandingBalance, loan.NextEmiDate,
            nextEmi?.InstallmentNo, nextEmi?.DueDate));
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

// ── Get Loan Products Query ───────────────────────────────────────────────────

public record LoanProductDto(
    Guid Id, string ProductName, string LoanType, decimal InterestRate,
    decimal MinAmount, decimal MaxAmount, int MinTenureMonths, int MaxTenureMonths,
    decimal ProcessingFeePercent, bool IsActive);

public record GetLoanProductsQuery() : IRequest<Result<List<LoanProductDto>>>;

public class GetLoanProductsQueryHandler(IAppDbContext db)
    : IRequestHandler<GetLoanProductsQuery, Result<List<LoanProductDto>>>
{
    public async Task<Result<List<LoanProductDto>>> Handle(GetLoanProductsQuery q, CancellationToken ct)
    {
        var products = await db.LoanProducts.AsNoTracking()
            .Where(p => !p.IsDeleted && p.IsActive)
            .OrderBy(p => p.ProductName)
            .Select(p => new LoanProductDto(
                p.Id, p.ProductName, p.LoanType, p.InterestRate,
                p.MinAmount, p.MaxAmount, p.MinTenureMonths, p.MaxTenureMonths,
                p.ProcessingFeePercent, p.IsActive))
            .ToListAsync(ct);

        return Result<List<LoanProductDto>>.Success(products);
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
        {
            var s = q.Search.ToLower();
            query = query.Where(l =>
                l.LoanNumber.ToLower().Contains(s) ||
                l.Member!.FirstName.ToLower().Contains(s) ||
                l.Member.LastName.ToLower().Contains(s));
        }

        if (!string.IsNullOrEmpty(q.Status))
            query = query.Where(l => l.Status == q.Status);

        if (q.BranchId.HasValue)
            query = query.Where(l => l.BranchId == q.BranchId);

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var total = await query.CountAsync(ct);

        var summary = new
        {
            totalPortfolio = await query.SumAsync(l => (decimal?)l.OutstandingBalance, ct) ?? 0,
            activeCount = await query.CountAsync(l => l.Status == "Active", ct),
            overdueCount = await query.CountAsync(l => l.Status == "Active" && l.NextEmiDate.HasValue && l.NextEmiDate.Value < today, ct),
            npaCount = await query.CountAsync(l => l.Status == "NPA", ct)
        };

        var items = await query
            .OrderByDescending(l => l.CreatedAt)
            .Skip((q.Page - 1) * q.PageSize).Take(Math.Min(q.PageSize, 2000))
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
            PagedResult<LoanListDto>.Create(items, q.Page, q.PageSize, total, summary));
    }
}

// ── Get Loan Detail Query ─────────────────────────────────────────────────────

public record LoanGuarantorDto(string MemberName, string MemberCode, decimal ShareAmount);
public record LoanCollateralDto(string Type, string Description, decimal EstimatedValue);

public record LoanDetailDto(
    Guid Id, string LoanNumber, string MemberName, string MemberCode, string MemberId,
    string ProductName, string LoanType, decimal InterestRate, string InterestType,
    decimal ProcessingFeePercent, int TenureMonths, decimal AppliedAmount,
    decimal? ApprovedAmount, decimal? DisbursedAmount, decimal OutstandingBalance,
    decimal EmiAmount, string Status, string? LoanPurpose, string? ApprovalRemarks,
    DateOnly? AppliedDate, DateOnly? ApprovedDate, DateOnly? DisbursedDate,
    DateOnly? ClosedDate, DateOnly? NextEmiDate, decimal OverdueAmount, int OverdueDays,
    string Branch, int InstallmentsPaid, int InstallmentsTotal,
    List<LoanGuarantorDto> Guarantors, List<LoanCollateralDto> Collaterals);

public record GetLoanDetailQuery(Guid LoanId) : IRequest<Result<LoanDetailDto>>;

public class GetLoanDetailQueryHandler(IAppDbContext db)
    : IRequestHandler<GetLoanDetailQuery, Result<LoanDetailDto>>
{
    public async Task<Result<LoanDetailDto>> Handle(GetLoanDetailQuery q, CancellationToken ct)
    {
        var loan = await db.Loans.AsNoTracking()
            .Include(l => l.Member)
            .Include(l => l.Product)
            .Include(l => l.Branch)
            .Include(l => l.EmiSchedule)
            .Include(l => l.Guarantors).ThenInclude(g => g.GuarantorMember)
            .Include(l => l.Collaterals)
            .FirstOrDefaultAsync(l => l.Id == q.LoanId && !l.IsDeleted, ct);

        if (loan is null)
            return Result<LoanDetailDto>.Failure("LOAN_NOT_FOUND", "Loan not found.");

        var memberName = loan.Member != null
            ? loan.Member.FirstName + (loan.Member.MiddleName != null ? " " + loan.Member.MiddleName : "") + " " + loan.Member.LastName
            : "Unknown";

        var paid = loan.EmiSchedule.Count(e => e.Status == "Paid");

        var guarantors = loan.Guarantors.Select(g => new LoanGuarantorDto(
            g.GuarantorMember != null
                ? g.GuarantorMember.FirstName + " " + g.GuarantorMember.LastName
                : "Unknown",
            g.GuarantorMember?.MemberCode ?? "—",
            g.ShareAmount)).ToList();

        var collaterals = loan.Collaterals.Select(c =>
            new LoanCollateralDto(c.CollateralType, c.Description, c.EstimatedValue)).ToList();

        return Result<LoanDetailDto>.Success(new LoanDetailDto(
            loan.Id, loan.LoanNumber, memberName,
            loan.Member?.MemberCode ?? "—",
            loan.MemberId.ToString(),
            loan.Product?.ProductName ?? "—",
            loan.Product?.LoanType ?? "Personal",
            loan.InterestRate,
            loan.Product?.InterestType ?? "Diminishing",
            loan.Product?.ProcessingFeePercent ?? 1,
            loan.TenureMonths, loan.AppliedAmount,
            loan.ApprovedAmount, loan.DisbursedAmount,
            loan.OutstandingBalance, loan.EmiAmount,
            loan.Status, loan.LoanPurpose, loan.ApprovalRemarks,
            loan.AppliedDate, loan.ApprovedDate, loan.DisbursedDate,
            loan.ClosedDate, loan.NextEmiDate,
            loan.OverdueAmount, loan.OverdueDays,
            loan.Branch?.BranchName ?? "Head Office",
            paid, loan.TenureMonths,
            guarantors, collaterals));
    }
}

// ── Get Loan Payments Query ───────────────────────────────────────────────────

public record LoanPaymentDto(
    string ReceiptNumber, decimal TotalPaid, decimal PrincipalPaid,
    decimal InterestPaid, decimal PenaltyPaid, string PaymentMode,
    DateTime PaymentDate, string? Narration, decimal BalanceAfter);

public record GetLoanPaymentsQuery(Guid LoanId, int Page = 1, int PageSize = 30)
    : IRequest<Result<PagedResult<LoanPaymentDto>>>;

public class GetLoanPaymentsQueryHandler(IAppDbContext db)
    : IRequestHandler<GetLoanPaymentsQuery, Result<PagedResult<LoanPaymentDto>>>
{
    public async Task<Result<PagedResult<LoanPaymentDto>>> Handle(GetLoanPaymentsQuery q, CancellationToken ct)
    {
        var exists = await db.Loans.AnyAsync(l => l.Id == q.LoanId && !l.IsDeleted, ct);
        if (!exists) return Result<PagedResult<LoanPaymentDto>>.Failure("LOAN_NOT_FOUND", "Loan not found.");

        var total = await db.LoanPayments.Where(p => p.LoanId == q.LoanId).CountAsync(ct);
        var items = await db.LoanPayments.AsNoTracking()
            .Where(p => p.LoanId == q.LoanId)
            .OrderByDescending(p => p.PaymentDate)
            .Skip((q.Page - 1) * q.PageSize).Take(Math.Min(q.PageSize, 2000))
            .Select(p => new LoanPaymentDto(
                p.ReceiptNumber, p.TotalPaid, p.PrincipalPaid,
                p.InterestPaid, p.PenaltyPaid, p.PaymentMode,
                p.PaymentDate, p.Narration, p.BalanceAfter))
            .ToListAsync(ct);

        return Result<PagedResult<LoanPaymentDto>>.Success(
            PagedResult<LoanPaymentDto>.Create(items, q.Page, q.PageSize, total));
    }
}

