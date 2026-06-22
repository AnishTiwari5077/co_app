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
    private async Task<long> NextVal(string seqName)
    {
        var conn = db.Database.GetDbConnection();
        var wasOpen = conn.State == System.Data.ConnectionState.Open;
        if (!wasOpen) await conn.OpenAsync();
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = $"SELECT nextval('{seqName}')";
            var result = await cmd.ExecuteScalarAsync();
            return Convert.ToInt64(result);
        }
        finally
        {
            if (!wasOpen) await conn.CloseAsync();
        }
    }

    public async Task<string> NextMemberCodeAsync(string branchCode, int fiscalYear)
    {
        var n = await NextVal("member_code_seq");
        return $"{branchCode}-{fiscalYear}-{n:D5}";
    }

    public async Task<string> NextLoanNumberAsync(string branchCode, int fiscalYear)
    {
        var n = await NextVal("loan_number_seq");
        return $"LN-{fiscalYear}-{n:D5}";
    }

    public async Task<string> NextAccountNumberAsync(string prefix, int fiscalYear)
    {
        var n = await NextVal("account_number_seq");
        return $"{prefix}-{fiscalYear}-{n:D5}";
    }

    public async Task<string> NextVoucherNumberAsync(string voucherType, Guid branchId, int fiscalYear)
    {
        var n = await NextVal("voucher_number_seq");
        var prefix = voucherType switch
        {
            "Journal" => "JV", "Receipt" => "RV", "Payment" => "PV", _ => "CV"
        };
        return $"{prefix}-{fiscalYear}-{n:D6}";
    }

    public async Task<string> NextReceiptNumberAsync(Guid branchId)
    {
        var n = await NextVal("receipt_number_seq");
        var fy = DateTime.UtcNow.Year + 57;
        return $"RCP-{fy}-{n:D5}";
    }
}
