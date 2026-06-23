using SahakariMS.Domain.Common;

namespace SahakariMS.Domain.Entities;

/// <summary>Core member profile — per public.members table spec.</summary>
public class Member : BaseEntity
{
    public Guid BranchId { get; set; }
    public string MemberCode { get; set; } = string.Empty;     // e.g. KTM-2081-00123
    public string FirstName { get; set; } = string.Empty;
    public string? MiddleName { get; set; }
    public string LastName { get; set; } = string.Empty;
    public string FullName => string.Join(" ", new[] { FirstName, MiddleName, LastName }.Where(s => !string.IsNullOrEmpty(s)));
    public string Gender { get; set; } = string.Empty;         // Male|Female|Other
    public DateOnly? DateOfBirthAd { get; set; }
    public string? DateOfBirthBs { get; set; }
    public string? CitizenshipNumber { get; set; }
    public string? CitizenshipIssuedDistrict { get; set; }
    public DateOnly? CitizenshipIssuedDate { get; set; }
    public string? PanNumber { get; set; }
    public string PhoneNumber { get; set; } = string.Empty;
    public string? AlternatePhone { get; set; }
    public string? Email { get; set; }
    public string? AddressDistrict { get; set; }
    public string? AddressMunicipality { get; set; }
    public string? AddressWard { get; set; }
    public string? AddressTole { get; set; }
    public string? PermanentAddress { get; set; }
    public string? Occupation { get; set; }
    public string? EmployerName { get; set; }
    public decimal? MonthlyIncome { get; set; }
    public string? PhotoUrl { get; set; }
    public string? CitizenshipDocUrl { get; set; }
    public string? SignatureUrl { get; set; }
    public string Status { get; set; } = "Pending";            // Pending|Active|Suspended|Closed
    public bool KycVerified { get; set; } = false;
    public DateTime? KycVerifiedAt { get; set; }
    public Guid? KycVerifiedBy { get; set; }
    public DateOnly? MembershipDate { get; set; }
    public string? SuspensionReason { get; set; }

    // Navigation
    public Branch? Branch { get; set; }
    public ICollection<MemberNominee> Nominees { get; set; } = [];
    public ICollection<SavingAccount> SavingAccounts { get; set; } = [];
    public ICollection<Loan> Loans { get; set; } = [];
    public ShareAccount? ShareAccount { get; set; }
}

public class MemberNominee : BaseEntity
{
    public Guid MemberId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Relationship { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public string? CitizenshipNumber { get; set; }
    public decimal AllocationPercent { get; set; } = 100;
    public Member? Member { get; set; }
}
