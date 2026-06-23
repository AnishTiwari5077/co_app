using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;

namespace SahakariMS.Application.Loans;

/// <summary>
/// Runs daily (via Hangfire) to:
///   1. Mark Pending EMIs whose DueDate has passed as "Overdue"
///   2. Recalculate loan.OverdueDays, loan.OverdueAmount
///   3. Update NPA classification (Standard / Substandard / Doubtful / Loss)
/// </summary>
public class LoanNpaJob(IAppDbContext db)
{
    // NPA thresholds (Nepal Rastra Bank guidelines)
    private const int SubstandardDays = 90;
    private const int DoubtfulDays = 180;
    private const int LossDays = 360;

    public async Task ExecuteAsync()
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);

        // ── 1. Load all active loans with their EMI schedules ─────────────────
        var activeLoans = await db.Loans
            .Include(l => l.EmiSchedule)
            .Where(l => l.Status == "Active" && !l.IsDeleted)
            .ToListAsync();

        foreach (var loan in activeLoans)
        {
            bool changed = false;

            // ── 2. Mark overdue EMIs ─────────────────────────────────────────
            var nowOverdue = loan.EmiSchedule
                .Where(e => e.Status == "Pending" && e.DueDate < today)
                .ToList();

            foreach (var emi in nowOverdue)
            {
                emi.Status = "Overdue";
                changed = true;
            }

            // ── 3. Calculate overdue days (from earliest unpaid overdue EMI) ──
            var earliestOverdue = loan.EmiSchedule
                .Where(e => e.Status == "Overdue")
                .OrderBy(e => e.DueDate)
                .FirstOrDefault();

            if (earliestOverdue != null)
            {
                var overdueDays = today.DayNumber - earliestOverdue.DueDate.DayNumber;
                var overdueAmount = loan.EmiSchedule
                    .Where(e => e.Status == "Overdue")
                    .Sum(e => e.EmiAmount - e.PaidAmount);

                loan.OverdueDays = overdueDays;
                loan.OverdueAmount = Math.Round(overdueAmount, 2);
                loan.NextEmiDate = earliestOverdue.DueDate; // keep pointing at earliest unpaid

                // ── 4. NPA Classification ─────────────────────────────────────
                loan.NpaClassification = overdueDays switch
                {
                    >= LossDays        => "Loss",
                    >= DoubtfulDays    => "Doubtful",
                    >= SubstandardDays => "Substandard",
                    _                  => "Standard"
                };
                changed = true;
            }
            else
            {
                // All EMIs on time — reset to Standard
                if (loan.NpaClassification != "Standard" || loan.OverdueDays != 0)
                {
                    loan.OverdueDays = 0;
                    loan.OverdueAmount = 0;
                    loan.NpaClassification = "Standard";
                    changed = true;
                }
            }

            _ = changed; // suppress unused warning (EF tracks changes automatically)
        }

        await db.SaveChangesAsync();
    }
}
