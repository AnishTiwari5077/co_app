using MediatR;
using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;
using SahakariMS.Domain.Entities;
using SahakariMS.Domain.Interfaces;
using SahakariMS.Shared.Common;

namespace SahakariMS.Application.Members;

public record MemberListDto(Guid Id, string MemberCode, string FullName, string Phone,
    string Status, decimal TotalSavings, decimal TotalLoan, DateOnly? MembershipDate, string? PhotoUrl);

public record MemberDetailDto(Guid Id, string MemberCode, string FirstName, string? MiddleName,
    string LastName, string Gender, DateOnly? DateOfBirthAd, string? CitizenshipNumber,
    string? PanNumber, string? Occupation,
    string PhoneNumber, string? Email,
    string? AddressDistrict, string? AddressMunicipality, string? AddressWard, string? AddressTole,
    DateOnly? MembershipDate,
    string Status, bool KycVerified, string? PhotoUrl,
    List<SavingAccountSummaryDto> SavingAccounts, List<LoanSummaryDto> Loans,
    List<NomineeSummaryDto> Nominees);

public record SavingAccountSummaryDto(Guid Id, string AccountNumber, decimal Balance, string Status);
public record LoanSummaryDto(Guid Id, string LoanNumber, decimal Outstanding, string Status);
public record NomineeSummaryDto(string? FullName, string? Relationship, string? PhoneNumber);

public record RegisterMemberRequest(
    string FirstName, string? MiddleName, string LastName, string Gender,
    DateOnly? DateOfBirthAd, string? CitizenshipNumber, string PhoneNumber, string? Email,
    string? AddressDistrict, string? AddressMunicipality, string? AddressWard, string? AddressTole,
    string? Occupation, Guid BranchId);

// ── Get Members Query ─────────────────────────────────────────────────────────

public record GetMembersQuery(int Page = 1, int PageSize = 20, string? Search = null,
    string? Status = null, Guid? BranchId = null) : IRequest<Result<PagedResult<MemberListDto>>>;

public class GetMembersQueryHandler(IAppDbContext db)
    : IRequestHandler<GetMembersQuery, Result<PagedResult<MemberListDto>>>
{
    public async Task<Result<PagedResult<MemberListDto>>> Handle(GetMembersQuery q, CancellationToken ct)
    {
        var query = db.Members.AsNoTracking().Where(m => !m.IsDeleted);

        if (!string.IsNullOrEmpty(q.Search))
            query = query.Where(m => m.FirstName.Contains(q.Search) || m.LastName.Contains(q.Search)
                || m.MemberCode.Contains(q.Search) || m.PhoneNumber.Contains(q.Search));

        if (!string.IsNullOrEmpty(q.Status))
            query = query.Where(m => m.Status == q.Status);

        if (q.BranchId.HasValue)
            query = query.Where(m => m.BranchId == q.BranchId);

        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(m => m.CreatedAt)
            .Skip((q.Page - 1) * q.PageSize).Take(Math.Min(q.PageSize, 100))
            .Select(m => new MemberListDto(
                m.Id, m.MemberCode, m.FullName, m.PhoneNumber, m.Status,
                m.SavingAccounts.Sum(s => s.CurrentBalance),
                m.Loans.Where(l => l.Status == "Active").Sum(l => l.OutstandingBalance),
                m.MembershipDate, m.PhotoUrl))
            .ToListAsync(ct);

        return Result<PagedResult<MemberListDto>>.Success(
            PagedResult<MemberListDto>.Create(items, q.Page, q.PageSize, total));
    }
}

// ── Get Member By ID ──────────────────────────────────────────────────────────

public record GetMemberByIdQuery(Guid Id) : IRequest<Result<MemberDetailDto>>;

public class GetMemberByIdQueryHandler(IAppDbContext db)
    : IRequestHandler<GetMemberByIdQuery, Result<MemberDetailDto>>
{
    public async Task<Result<MemberDetailDto>> Handle(GetMemberByIdQuery q, CancellationToken ct)
    {
        var m = await db.Members.AsNoTracking()
            .Include(m => m.SavingAccounts)
            .Include(m => m.Loans)
            .Include(m => m.Nominees)
            .FirstOrDefaultAsync(m => m.Id == q.Id && !m.IsDeleted, ct);

        if (m is null) return Result<MemberDetailDto>.Failure("MEMBER_NOT_FOUND", $"Member {q.Id} not found.");

        return Result<MemberDetailDto>.Success(new MemberDetailDto(
            m.Id, m.MemberCode, m.FirstName, m.MiddleName, m.LastName, m.Gender,
            m.DateOfBirthAd, m.CitizenshipNumber, m.PanNumber, m.Occupation,
            m.PhoneNumber, m.Email,
            m.AddressDistrict, m.AddressMunicipality, m.AddressWard, m.AddressTole,
            m.MembershipDate,
            m.Status, m.KycVerified, m.PhotoUrl,
            m.SavingAccounts.Select(s => new SavingAccountSummaryDto(s.Id, s.AccountNumber, s.CurrentBalance, s.Status)).ToList(),
            m.Loans.Select(l => new LoanSummaryDto(l.Id, l.LoanNumber, l.OutstandingBalance, l.Status)).ToList(),
            m.Nominees.Select(n => new NomineeSummaryDto(n.FullName, n.Relationship, n.PhoneNumber)).ToList()));
    }
}

// ── Register Member Command ───────────────────────────────────────────────────

public record RegisterMemberCommand(RegisterMemberRequest Request, Guid ActorId) : IRequest<Result<Guid>>;

public class RegisterMemberCommandHandler(IAppDbContext db, IUnitOfWork uow, ISequenceGenerator seq, ICacheService cache)
    : IRequestHandler<RegisterMemberCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(RegisterMemberCommand cmd, CancellationToken ct)
    {
        var r = cmd.Request;
        var branch = await db.Branches.FindAsync([r.BranchId], ct);
        if (branch is null) return Result<Guid>.Failure("BRANCH_NOT_FOUND", "Branch not found.");

        var year = DateTime.UtcNow.Year + 57;
        var memberCode = await seq.NextMemberCodeAsync(branch.BranchCode, year);

        var member = new Member
        {
            BranchId = r.BranchId, MemberCode = memberCode,
            FirstName = r.FirstName, MiddleName = r.MiddleName, LastName = r.LastName,
            Gender = r.Gender, DateOfBirthAd = r.DateOfBirthAd,
            CitizenshipNumber = r.CitizenshipNumber, PhoneNumber = r.PhoneNumber,
            Email = r.Email, AddressDistrict = r.AddressDistrict,
            AddressMunicipality = r.AddressMunicipality, AddressWard = r.AddressWard,
            AddressTole = r.AddressTole, Occupation = r.Occupation,
            Status = "Pending", CreatedBy = cmd.ActorId
        };
        await db.Members.AddAsync(member, ct);
        await uow.SaveChangesAsync(ct);
        // Bust dashboard cache so pending approvals + total members reflect immediately
        try { await cache.RemoveByPrefixAsync("dashboard:", ct); } catch { /* ignore */ }
        return Result<Guid>.Success(member.Id);
    }
}

// ── Approve Member Command ────────────────────────────────────────────────────

public record ApproveMemberCommand(Guid MemberId, Guid ActorId) : IRequest<Result>;

public class ApproveMemberCommandHandler(IAppDbContext db, IUnitOfWork uow, ICacheService cache) : IRequestHandler<ApproveMemberCommand, Result>
{
    public async Task<Result> Handle(ApproveMemberCommand cmd, CancellationToken ct)
    {
        var member = await db.Members.FindAsync([cmd.MemberId], ct);
        if (member is null) return Result.Failure("MEMBER_NOT_FOUND", "Member not found.");
        if (member.Status != "Pending") return Result.Failure("INVALID_STATUS", "Only pending members can be approved.");
        member.Status = "Active";
        member.MembershipDate = DateOnly.FromDateTime(DateTime.UtcNow);
        member.UpdatedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        // Bust dashboard cache — active member count + pending approvals must refresh
        try { await cache.RemoveByPrefixAsync("dashboard:", ct); } catch { /* ignore */ }
        return Result.Success();
    }
}
