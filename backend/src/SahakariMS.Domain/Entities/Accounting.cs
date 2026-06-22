using SahakariMS.Domain.Common;

namespace SahakariMS.Domain.Entities;

/// <summary>Fiscal year definition — per accounting.fiscal_years table.</summary>
public class FiscalYear : BaseEntity
{
    public string YearCode { get; set; } = string.Empty;    // e.g. "2081-82"
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public bool IsCurrent { get; set; } = false;
    public bool IsClosed { get; set; } = false;
    public DateTime? ClosedAt { get; set; }
    public Guid? ClosedBy { get; set; }
    public ICollection<Voucher> Vouchers { get; set; } = [];
}

/// <summary>Chart of Accounts entry — per accounting.chart_of_accounts table.</summary>
public class ChartOfAccount : BaseEntity
{
    public Guid? ParentId { get; set; }
    public Guid? BranchId { get; set; }
    public string AccountCode { get; set; } = string.Empty;  // e.g. "1001"
    public string AccountName { get; set; } = string.Empty;
    public string AccountNameNp { get; set; } = string.Empty;
    public string AccountType { get; set; } = string.Empty;  // Asset|Liability|Equity|Income|Expense
    public string AccountGroup { get; set; } = string.Empty;
    public bool IsControl { get; set; } = false;             // Group account
    public bool AllowDirectPosting { get; set; } = true;
    public decimal CurrentBalance { get; set; } = 0;
    public bool IsActive { get; set; } = true;

    // Navigation
    public ChartOfAccount? Parent { get; set; }
    public ICollection<ChartOfAccount> Children { get; set; } = [];
    public ICollection<VoucherEntry> Entries { get; set; } = [];
}

/// <summary>Journal voucher header — per accounting.vouchers table.</summary>
public class Voucher : BaseEntity
{
    public Guid BranchId { get; set; }
    public Guid FiscalYearId { get; set; }
    public string VoucherNumber { get; set; } = string.Empty;
    public string VoucherType { get; set; } = "Journal";    // Journal|Receipt|Payment|Contra
    public DateOnly VoucherDate { get; set; }
    public string? Narration { get; set; }
    public string Status { get; set; } = "Draft";           // Draft|Posted|Reversed
    public bool IsBalanced { get; set; } = false;
    public Guid? PreparedBy { get; set; }
    public Guid? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public Guid? ReversalOfId { get; set; }

    // Navigation
    public FiscalYear? FiscalYear { get; set; }
    public ICollection<VoucherEntry> Entries { get; set; } = [];

    /// <summary>Validates that debits == credits (double-entry invariant).</summary>
    public bool Validate() =>
        Entries.Sum(e => e.EntryType == "Debit" ? e.Amount : 0) ==
        Entries.Sum(e => e.EntryType == "Credit" ? e.Amount : 0);
}

/// <summary>Individual debit/credit line — per accounting.voucher_entries table.</summary>
public class VoucherEntry : BaseEntity
{
    public Guid VoucherId { get; set; }
    public Guid AccountId { get; set; }
    public string EntryType { get; set; } = "Debit";        // Debit|Credit
    public decimal Amount { get; set; }
    public string? Narration { get; set; }
    public string? RefType { get; set; }                    // Member|Loan|Saving etc.
    public Guid? RefId { get; set; }

    // Navigation
    public Voucher? Voucher { get; set; }
    public ChartOfAccount? Account { get; set; }
}

/// <summary>Audit log — per audit.audit_logs table.</summary>
public class AuditLog : BaseEntity
{
    public Guid? UserId { get; set; }
    public string Action { get; set; } = string.Empty;      // CREATE|UPDATE|DELETE|LOGIN|LOGOUT
    public string EntityType { get; set; } = string.Empty;
    public Guid? EntityId { get; set; }
    public string? OldValues { get; set; }                  // JSON
    public string? NewValues { get; set; }                  // JSON
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public string? CorrelationId { get; set; }
}
