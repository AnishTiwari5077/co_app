using SahakariMS.Domain.Common;

namespace SahakariMS.Domain.Entities;

/// <summary>Loan product definition — per loan_products table.</summary>
public class LoanProduct : BaseEntity
{
    public string ProductCode { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public string LoanType { get; set; } = string.Empty;        // Personal|Business|Agriculture|Housing|Education
    public decimal InterestRate { get; set; }                   // Annual % (flat or diminishing)
    public string InterestType { get; set; } = "Diminishing";  // Flat|Diminishing
    public decimal PenaltyRate { get; set; } = 2;              // Extra % on overdue EMI
    public decimal MinAmount { get; set; }
    public decimal MaxAmount { get; set; }
    public int MinTenureMonths { get; set; }
    public int MaxTenureMonths { get; set; }
    public decimal ProcessingFeePercent { get; set; } = 1;
    public bool CollateralRequired { get; set; } = true;
    public bool GuarantorRequired { get; set; } = true;
    public bool IsActive { get; set; } = true;
    public ICollection<Loan> Loans { get; set; } = [];
}

/// <summary>Loan account — per loans table.</summary>
public class Loan : BaseEntity
{
    public Guid MemberId { get; set; }
    public Guid BranchId { get; set; }
    public Guid ProductId { get; set; }
    public string LoanNumber { get; set; } = string.Empty;      // e.g. LN-2081-00456
    public decimal AppliedAmount { get; set; }
    public decimal? ApprovedAmount { get; set; }
    public decimal? DisbursedAmount { get; set; }
    public decimal OutstandingBalance { get; set; } = 0;
    public decimal InterestRate { get; set; }
    public int TenureMonths { get; set; }
    public decimal EmiAmount { get; set; }
    public string RepaymentMode { get; set; } = "Monthly";
    public string Status { get; set; } = "Pending";             // Pending|Approved|Rejected|Active|Closed|NPA
    public string NpaClassification { get; set; } = "Standard"; // Standard|Watch|Substandard|Doubtful|Loss
    public string? LoanPurpose { get; set; }
    public DateOnly? AppliedDate { get; set; }
    public DateOnly? ApprovedDate { get; set; }
    public DateOnly? DisbursedDate { get; set; }
    public DateOnly? ClosedDate { get; set; }
    public DateOnly? NextEmiDate { get; set; }
    public decimal OverdueAmount { get; set; } = 0;
    public int OverdueDays { get; set; } = 0;
    public Guid? DisbursementAccountId { get; set; }
    public string? ApprovalRemarks { get; set; }
    public Guid? ApprovedBy { get; set; }
    public Guid? DisbursedBy { get; set; }

    // Navigation
    public Member? Member { get; set; }
    public Branch? Branch { get; set; }
    public LoanProduct? Product { get; set; }
    public ICollection<LoanEmiSchedule> EmiSchedule { get; set; } = [];
    public ICollection<LoanPayment> Payments { get; set; } = [];
    public ICollection<LoanGuarantor> Guarantors { get; set; } = [];
    public ICollection<LoanCollateral> Collaterals { get; set; } = [];

    /// <summary>Calculates EMI using diminishing balance formula per Nepal SACCOS practice.</summary>
    public static decimal CalculateEmi(decimal principal, decimal annualRatePercent, int tenureMonths)
    {
        if (annualRatePercent == 0) return principal / tenureMonths;
        var r = annualRatePercent / 100 / 12;
        return Math.Round(principal * r * (decimal)Math.Pow((double)(1 + r), tenureMonths)
            / ((decimal)Math.Pow((double)(1 + r), tenureMonths) - 1), 2);
    }
}

/// <summary>Monthly EMI schedule row — per loan_emi_schedule table.</summary>
public class LoanEmiSchedule : BaseEntity
{
    public Guid LoanId { get; set; }
    public int InstallmentNo { get; set; }
    public DateOnly DueDate { get; set; }
    public decimal EmiAmount { get; set; }
    public decimal PrincipalAmount { get; set; }
    public decimal InterestAmount { get; set; }
    public decimal OutstandingBalance { get; set; }
    public string Status { get; set; } = "Pending";             // Pending|Paid|PartPaid|Overdue
    public decimal PaidAmount { get; set; } = 0;
    public DateTime? PaidDate { get; set; }
    public Loan? Loan { get; set; }
}

/// <summary>EMI payment record — per loan_payments table.</summary>
public class LoanPayment : BaseEntity
{
    public Guid LoanId { get; set; }
    public string ReceiptNumber { get; set; } = string.Empty;
    public decimal TotalPaid { get; set; }
    public decimal PrincipalPaid { get; set; }
    public decimal InterestPaid { get; set; }
    public decimal PenaltyPaid { get; set; }
    public string PaymentMode { get; set; } = "Cash";
    public DateTime PaymentDate { get; set; }
    public string? Narration { get; set; }
    public decimal BalanceAfter { get; set; }
    public Guid? ProcessedBy { get; set; }
    public Guid? VoucherId { get; set; }
    public Loan? Loan { get; set; }
}

public class LoanGuarantor : BaseEntity
{
    public Guid LoanId { get; set; }
    public Guid GuarantorMemberId { get; set; }
    public decimal ShareAmount { get; set; }
    public string Status { get; set; } = "Active";
    public Loan? Loan { get; set; }
    public Member? GuarantorMember { get; set; }
}

public class LoanCollateral : BaseEntity
{
    public Guid LoanId { get; set; }
    public string CollateralType { get; set; } = string.Empty;  // Land|Building|Vehicle|Jewelry|FD|Other
    public string Description { get; set; } = string.Empty;
    public decimal EstimatedValue { get; set; }
    public string? DocumentReference { get; set; }
    public Loan? Loan { get; set; }
}
