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
    string? CitizenshipDocUrl, string? SignatureUrl,
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
        {
            var s = q.Search.ToLower();
            query = query.Where(m =>
                m.FirstName.ToLower().Contains(s) ||
                m.LastName.ToLower().Contains(s) ||
                m.MemberCode.ToLower().Contains(s) ||
                m.PhoneNumber.ToLower().Contains(s));
        }

        if (!string.IsNullOrEmpty(q.Status))
            query = query.Where(m => m.Status == q.Status);

        if (q.BranchId.HasValue)
            query = query.Where(m => m.BranchId == q.BranchId);

        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(m => m.CreatedAt)
            .Skip((q.Page - 1) * q.PageSize).Take(Math.Min(q.PageSize, 50000))
            .Select(m => new MemberListDto(
                m.Id, m.MemberCode,
                m.FirstName + (m.MiddleName != null ? " " + m.MiddleName : "") + " " + m.LastName,
                m.PhoneNumber, m.Status,
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
            m.CitizenshipDocUrl, m.SignatureUrl,
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

// ── Update Member Status Command ──────────────────────────────────────────────

/// <param name="Action">One of: "suspend" | "reactivate" | "deactivate"</param>
public record UpdateMemberStatusCommand(Guid MemberId, string Action, string? Reason, Guid ActorId) : IRequest<Result>;

public class UpdateMemberStatusCommandHandler(IAppDbContext db, IUnitOfWork uow, ICacheService cache)
    : IRequestHandler<UpdateMemberStatusCommand, Result>
{
    public async Task<Result> Handle(UpdateMemberStatusCommand cmd, CancellationToken ct)
    {
        var member = await db.Members.FindAsync([cmd.MemberId], ct);

        if (member is null) return Result.Failure("MEMBER_NOT_FOUND", "Member not found.");

        switch (cmd.Action.ToLower())
        {
            case "suspend":
                if (member.Status != "Active")
                    return Result.Failure("INVALID_STATUS", $"Cannot suspend a member with status '{member.Status}'. Only Active members can be suspended.");
                member.Status = "Suspended";
                break;

            case "reactivate":
                if (member.Status != "Suspended" && member.Status != "Inactive")
                    return Result.Failure("INVALID_STATUS", $"Cannot reactivate a member with status '{member.Status}'.");
                member.Status = "Active";
                break;

            case "deactivate":
                if (member.Status == "Inactive")
                    return Result.Failure("INVALID_STATUS", "Member is already inactive.");

                // Guard: cannot deactivate if they have active savings or loans
                var activeSavingsQ = db.SavingAccounts
                    .Where(s => s.MemberId == cmd.MemberId && s.Status == "Active");
                var hasActiveSavings = await activeSavingsQ.AnyAsync(ct);

                var activeLoansQ = db.Loans
                    .Where(l => l.MemberId == cmd.MemberId && (l.Status == "Active" || l.Status == "Disbursed"));
                var hasActiveLoans = await activeLoansQ.AnyAsync(ct);

                if (hasActiveSavings)
                    return Result.Failure("HAS_ACTIVE_SAVINGS", "Cannot deactivate member with active savings accounts. Please close all savings accounts first.");
                if (hasActiveLoans)
                    return Result.Failure("HAS_ACTIVE_LOANS", "Cannot deactivate member with active loans. Please settle all outstanding loans first.");

                member.Status = "Inactive";
                break;

            default:
                return Result.Failure("INVALID_ACTION", $"Unknown action '{cmd.Action}'. Allowed: suspend, reactivate, deactivate.");
        }

        member.UpdatedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        try { await cache.RemoveByPrefixAsync("dashboard:", ct); } catch { /* ignore */ }
        return Result.Success();
    }
}

// ── Update Member Profile Command ─────────────────────────────────────────────

public record UpdateMemberRequest(
    string FirstName, string? MiddleName, string LastName,
    string? Gender, string? DateOfBirthAd, string? Occupation,
    string PhoneNumber, string? Email,
    string? AddressDistrict, string? AddressMunicipality,
    string? AddressWard, string? AddressTole,
    string? CitizenshipNumber, string? PanNumber);

public record UpdateMemberCommand(Guid MemberId, UpdateMemberRequest Request, Guid ActorId) : IRequest<Result>;

public class UpdateMemberCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<UpdateMemberCommand, Result>
{
    public async Task<Result> Handle(UpdateMemberCommand cmd, CancellationToken ct)
    {
        var r = cmd.Request;
        var member = await db.Members.FindAsync([cmd.MemberId], ct);
        if (member is null || member.IsDeleted)
            return Result.Failure("NOT_FOUND", "Member not found.");

        member.FirstName           = r.FirstName.Trim();
        member.MiddleName          = string.IsNullOrWhiteSpace(r.MiddleName) ? null : r.MiddleName.Trim();
        member.LastName            = r.LastName.Trim();
        member.Gender              = r.Gender;
        member.DateOfBirthAd       = r.DateOfBirthAd is { Length: > 0 } s &&
                                      DateOnly.TryParse(s, out var dob) ? dob : null;
        member.Occupation          = r.Occupation;
        member.PhoneNumber         = r.PhoneNumber.Trim();
        member.Email               = string.IsNullOrWhiteSpace(r.Email) ? null : r.Email.Trim();
        member.AddressDistrict     = r.AddressDistrict;
        member.AddressMunicipality = r.AddressMunicipality;
        member.AddressWard         = r.AddressWard;
        member.AddressTole         = r.AddressTole;
        member.CitizenshipNumber   = r.CitizenshipNumber;
        member.PanNumber           = r.PanNumber;
        member.UpdatedBy           = cmd.ActorId;

        await uow.SaveChangesAsync(ct);
        return Result.Success();
    }
}


public record DeleteMemberCommand(Guid MemberId, Guid ActorId) : IRequest<Result>;

public class DeleteMemberCommandHandler(IAppDbContext db, IUnitOfWork uow, ICacheService cache)
    : IRequestHandler<DeleteMemberCommand, Result>
{
    public async Task<Result> Handle(DeleteMemberCommand cmd, CancellationToken ct)
    {
        var member = await db.Members.FindAsync([cmd.MemberId], ct);
        if (member is null) return Result.Failure("MEMBER_NOT_FOUND", "Member not found.");

        // Only Pending or Inactive members can be deleted
        if (member.Status != "Pending" && member.Status != "Inactive")
            return Result.Failure("INVALID_STATUS",
                $"Cannot delete a member with status '{member.Status}'. Please deactivate the member first before deleting.");

        // Guard: must have no savings or loans at all
        var hasSavings = await db.SavingAccounts
            .Where(s => s.MemberId == cmd.MemberId)
            .AnyAsync(ct);
        var hasLoans = await db.Loans
            .Where(l => l.MemberId == cmd.MemberId)
            .AnyAsync(ct);

        if (hasSavings)
            return Result.Failure("HAS_SAVINGS",
                "Cannot delete a member who has savings account history. Consider keeping the member as Inactive.");
        if (hasLoans)
            return Result.Failure("HAS_LOANS",
                "Cannot delete a member who has loan history. Consider keeping the member as Inactive.");

        // Soft delete
        member.IsDeleted = true;
        member.DeletedAt = DateTime.UtcNow;
        member.DeletedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        try { await cache.RemoveByPrefixAsync("dashboard:", ct); } catch { /* ignore */ }
        return Result.Success();
    }
}

// ── Upload Member Document Command ────────────────────────────────────────────

public record UploadMemberDocumentCommand(
    Guid MemberId,
    string DocType,          // "photo" | "citizenship" | "signature"
    Stream FileStream,
    string FileName,
    string WebRootPath,
    Guid ActorId) : IRequest<Result<string>>;

public class UploadMemberDocumentCommandHandler(IAppDbContext db, IUnitOfWork uow)
    : IRequestHandler<UploadMemberDocumentCommand, Result<string>>
{
    public async Task<Result<string>> Handle(UploadMemberDocumentCommand cmd, CancellationToken ct)
    {
        var member = await db.Members.FindAsync([cmd.MemberId], ct);
        if (member is null) return Result<string>.Failure("MEMBER_NOT_FOUND", "Member not found.");

        // Validate doc type
        if (cmd.DocType is not ("photo" or "citizenship" or "signature"))
            return Result<string>.Failure("INVALID_DOC_TYPE", "DocType must be photo, citizenship, or signature.");

        // Build safe filename and save
        var ext = Path.GetExtension(cmd.FileName).ToLowerInvariant();
        var allowedExts = new[] { ".jpg", ".jpeg", ".png", ".pdf", ".webp" };
        if (!allowedExts.Contains(ext))
            return Result<string>.Failure("INVALID_FILE_TYPE", "Only JPG, PNG, PDF, WEBP files are allowed.");

        var memberDir = Path.Combine(cmd.WebRootPath, "uploads", "members", cmd.MemberId.ToString());
        Directory.CreateDirectory(memberDir);

        var savedName = $"{cmd.DocType}_{DateTime.UtcNow:yyyyMMddHHmmss}{ext}";
        var filePath = Path.Combine(memberDir, savedName);

        await using (var fs = File.Create(filePath))
            await cmd.FileStream.CopyToAsync(fs, ct);

        var relativeUrl = $"/uploads/members/{cmd.MemberId}/{savedName}";

        switch (cmd.DocType)
        {
            case "photo":       member.PhotoUrl          = relativeUrl; break;
            case "citizenship": member.CitizenshipDocUrl  = relativeUrl; break;
            case "signature":   member.SignatureUrl       = relativeUrl; break;
        }
        member.UpdatedBy = cmd.ActorId;
        await uow.SaveChangesAsync(ct);
        return Result<string>.Success(relativeUrl);
    }
}
