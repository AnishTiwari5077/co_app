using Microsoft.EntityFrameworkCore;
using SahakariMS.Domain.Interfaces;
using SahakariMS.Infrastructure.Persistence;

namespace SahakariMS.Infrastructure.Services;

/// <summary>
/// Generates human-readable sequential codes for members, loans, accounts, vouchers.
/// Uses PostgreSQL sequences for atomicity under concurrent access.
/// </summary>
public class SequenceGenerator(AppDbContext db) : ISequenceGenerator
{
    public async Task<string> NextMemberCodeAsync(string branchCode, int fiscalYear)
    {
        var seq = await db.Database.ExecuteSqlRawAsync("SELECT nextval('member_code_seq')");
        var n = await db.Database.SqlQuery<long>($"SELECT nextval('member_code_seq')").FirstAsync();
        return $"{branchCode}-{fiscalYear}-{n:D5}";   // e.g. KTM-2081-00123
    }

    public async Task<string> NextLoanNumberAsync(string branchCode, int fiscalYear)
    {
        var n = await db.Database.SqlQuery<long>($"SELECT nextval('loan_number_seq')").FirstAsync();
        return $"LN-{fiscalYear}-{n:D5}";             // e.g. LN-2081-00456
    }

    public async Task<string> NextAccountNumberAsync(string prefix, int fiscalYear)
    {
        var n = await db.Database.SqlQuery<long>($"SELECT nextval('account_number_seq')").FirstAsync();
        return $"{prefix}-{fiscalYear}-{n:D5}";
    }

    public async Task<string> NextVoucherNumberAsync(string voucherType, Guid branchId, int fiscalYear)
    {
        var n = await db.Database.SqlQuery<long>($"SELECT nextval('voucher_number_seq')").FirstAsync();
        var prefix = voucherType switch
        {
            "Journal" => "JV", "Receipt" => "RV", "Payment" => "PV", _ => "CV"
        };
        return $"{prefix}-{fiscalYear}-{n:D6}";       // e.g. JV-2081-000123
    }

    public async Task<string> NextReceiptNumberAsync(Guid branchId)
    {
        var n = await db.Database.SqlQuery<long>($"SELECT nextval('receipt_number_seq')").FirstAsync();
        var fy = DateTime.UtcNow.Year + 57;
        return $"RCP-{fy}-{n:D5}";                    // e.g. RCP-2081-01234
    }
}
