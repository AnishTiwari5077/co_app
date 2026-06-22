using SahakariMS.Domain.Common;

namespace SahakariMS.Domain.Entities;

/// <summary>Savings scheme definition (Regular, Recurring, Fixed Deposit) — per saving_schemes table.</summary>
public class SavingScheme : BaseEntity
{
    public string SchemeCode { get; set; } = string.Empty;
    public string SchemeName { get; set; } = string.Empty;
    public string SchemeType { get; set; } = "Regular";   // Regular|RecurringDeposit|FixedDeposit
    public decimal InterestRate { get; set; }              // Annual %
    public string InterestCalculation { get; set; } = "Daily"; // Daily|Monthly
    public string InterestPosting { get; set; } = "Quarterly"; // Monthly|Quarterly|Yearly
    public decimal MinimumBalance { get; set; } = 0;
    public decimal? MinimumDeposit { get; set; }
    public int? MinTenureMonths { get; set; }
    public int? MaxTenureMonths { get; set; }
    public bool WithdrawalAllowed { get; set; } = true;
    public int? WithdrawalNoticeDays { get; set; }
    public bool IsActive { get; set; } = true;
    public ICollection<SavingAccount> Accounts { get; set; } = [];
}

/// <summary>Member savings account — per saving_accounts table.</summary>
public class SavingAccount : BaseEntity
{
    public Guid MemberId { get; set; }
    public Guid BranchId { get; set; }
    public Guid SchemeId { get; set; }
    public string AccountNumber { get; set; } = string.Empty;   // e.g. SAV-2081-00456
    public decimal CurrentBalance { get; set; } = 0;
    public decimal InterestAccrued { get; set; } = 0;
    public string Status { get; set; } = "Active";              // Active|Frozen|Closed
    public DateOnly OpenDate { get; set; }
    public DateOnly? CloseDate { get; set; }
    public string? CloseReason { get; set; }
    public bool IsFrozen { get; set; } = false;
    public string? FreezeReason { get; set; }
    public Guid? NomineeId { get; set; }

    // Navigation
    public Member? Member { get; set; }
    public Branch? Branch { get; set; }
    public SavingScheme? Scheme { get; set; }
    public ICollection<SavingTransaction> Transactions { get; set; } = [];
}

/// <summary>Individual deposit or withdrawal — per saving_transactions table.</summary>
public class SavingTransaction : BaseEntity
{
    public Guid AccountId { get; set; }
    public Guid BranchId { get; set; }
    public string TransactionType { get; set; } = string.Empty; // Deposit|Withdrawal|InterestPosting|Reversal
    public decimal Amount { get; set; }
    public decimal BalanceAfter { get; set; }
    public string DepositMode { get; set; } = "Cash";           // Cash|Cheque|Online|Transfer
    public string ReceiptNumber { get; set; } = string.Empty;
    public string? Narration { get; set; }
    public DateTime TransactionDate { get; set; } = DateTime.UtcNow;
    public Guid? ProcessedBy { get; set; }
    public Guid? VoucherId { get; set; }                        // Linked journal voucher
    public bool IsReversed { get; set; } = false;
    public Guid? ReversalOfId { get; set; }

    // Navigation
    public SavingAccount? Account { get; set; }
}

/// <summary>Share account — per share_accounts table.</summary>
public class ShareAccount : BaseEntity
{
    public Guid MemberId { get; set; }
    public Guid BranchId { get; set; }
    public string AccountNumber { get; set; } = string.Empty;
    public int SharesHeld { get; set; } = 0;
    public decimal FaceValuePerShare { get; set; } = 100;
    public decimal TotalValue => SharesHeld * FaceValuePerShare;
    public string Status { get; set; } = "Active";
    public Member? Member { get; set; }
}
