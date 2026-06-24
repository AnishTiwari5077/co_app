using MediatR;
using Microsoft.EntityFrameworkCore;
using SahakariMS.Application.Interfaces;
using SahakariMS.Shared.Common;

namespace SahakariMS.Application.Notifications;

// ── DTOs ─────────────────────────────────────────────────────────────────────

public record NotificationDto(
    string Id,
    string Title,
    string Body,
    string Type,       // alert | loan | savings | member | security | system
    string Category,   // ALERT | LOAN | SAVINGS | MEMBER | SYSTEM
    DateTime CreatedAt,
    bool IsRead
);

public record GetNotificationsQuery : IRequest<Result<List<NotificationDto>>>;

// ── Handler ───────────────────────────────────────────────────────────────────

public class GetNotificationsQueryHandler(IAppDbContext db)
    : IRequestHandler<GetNotificationsQuery, Result<List<NotificationDto>>>
{
    public async Task<Result<List<NotificationDto>>> Handle(
        GetNotificationsQuery request, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var today = DateOnly.FromDateTime(now);
        var sevenDaysAgo = now.AddDays(-7);
        var thirtyDaysFromNow = today.AddDays(30);

        var items = new List<NotificationDto>();

        // ── 1. Overdue Loans ──────────────────────────────────────────────────
        try
        {
            var overdueLoans = await db.Loans
                .Include(l => l.Member)
                .Where(l => !l.IsDeleted && l.OverdueDays > 0 && l.Status == "Active")
                .OrderByDescending(l => l.OverdueDays)
                .Take(10)
                .ToListAsync(ct);

            foreach (var loan in overdueLoans)
            {
                var memberName = loan.Member is not null
                    ? $"{loan.Member.FirstName} {loan.Member.LastName}".Trim()
                    : "Member";
                items.Add(new NotificationDto(
                    Id: $"loan-overdue-{loan.Id}",
                    Title: $"EMI Overdue — {memberName}",
                    Body: $"Loan {loan.LoanNumber}: EMI of NPR {loan.EmiAmount:N0} is {loan.OverdueDays} days overdue.",
                    Type: "alert",
                    Category: "ALERT",
                    CreatedAt: now.AddHours(-Math.Min(loan.OverdueDays, 48)),
                    IsRead: false
                ));
            }
        }
        catch { /* Skip section on error */ }

        // ── 2. Pending Loan Applications ─────────────────────────────────────
        try
        {
            var pendingLoans = await db.Loans
                .Include(l => l.Member)
                .Where(l => !l.IsDeleted && l.Status == "Pending")
                .OrderByDescending(l => l.CreatedAt)
                .Take(5)
                .ToListAsync(ct);

            foreach (var loan in pendingLoans)
            {
                var memberName = loan.Member is not null
                    ? $"{loan.Member.FirstName} {loan.Member.LastName}".Trim()
                    : "Member";
                var memberCode = loan.Member?.MemberCode ?? "";
                items.Add(new NotificationDto(
                    Id: $"loan-pending-{loan.Id}",
                    Title: "Loan Application Received",
                    Body: $"{memberName} ({memberCode}) submitted a loan application of NPR {loan.AppliedAmount:N0}.",
                    Type: "loan",
                    Category: "LOAN",
                    CreatedAt: loan.CreatedAt,
                    IsRead: loan.CreatedAt < now.AddHours(-4)
                ));
            }
        }
        catch { /* Skip section on error */ }

        // ── 3. Pending Member Registrations ───────────────────────────────────
        try
        {
            var pendingMembers = await db.Members
                .Where(m => !m.IsDeleted && m.Status == "Pending")
                .OrderByDescending(m => m.CreatedAt)
                .Take(5)
                .ToListAsync(ct);

            foreach (var member in pendingMembers)
            {
                var memberName = $"{member.FirstName} {member.LastName}".Trim();
                items.Add(new NotificationDto(
                    Id: $"member-pending-{member.Id}",
                    Title: "New Member Registration",
                    Body: $"{memberName} has submitted a membership application. Pending KYC review.",
                    Type: "member",
                    Category: "MEMBER",
                    CreatedAt: member.CreatedAt,
                    IsRead: member.CreatedAt < now.AddHours(-2)
                ));
            }
        }
        catch { /* Skip section on error */ }

        // ── 4. Large Withdrawals (last 7 days, > NPR 50,000) ─────────────────
        try
        {
            var largeWithdrawals = await db.SavingTransactions
                .Include(t => t.Account)
                    .ThenInclude(a => a!.Member)
                .Where(t => !t.IsDeleted
                    && t.TransactionType == "Withdrawal"
                    && t.Amount >= 50000
                    && t.TransactionDate >= sevenDaysAgo)
                .OrderByDescending(t => t.Amount)
                .Take(5)
                .ToListAsync(ct);

            foreach (var txn in largeWithdrawals)
            {
                var member = txn.Account?.Member;
                var memberName = member is not null
                    ? $"{member.FirstName} {member.LastName}".Trim()
                    : "Member";
                var age = now - txn.TransactionDate;
                var ageStr = age.TotalHours < 24
                    ? $"{(int)age.TotalHours}h ago"
                    : $"{(int)age.TotalDays}d ago";

                items.Add(new NotificationDto(
                    Id: $"withdrawal-{txn.Id}",
                    Title: "Large Withdrawal Alert",
                    Body: $"{memberName} requested NPR {txn.Amount:N0} withdrawal ({ageStr}).",
                    Type: "alert",
                    Category: "ALERT",
                    CreatedAt: txn.TransactionDate,
                    IsRead: txn.TransactionDate < now.AddHours(-6)
                ));
            }
        }
        catch { /* Skip section on error */ }

        // ── 5. FD Maturity in Next 30 Days ────────────────────────────────────
        try
        {
            var fdAccounts = await db.SavingAccounts
                .Include(a => a.Member)
                .Include(a => a.Scheme)
                .Where(a => !a.IsDeleted
                    && a.Status == "Active"
                    && a.Scheme != null
                    && a.Scheme.SchemeType == "FixedDeposit"
                    && a.Scheme.MaxTenureMonths != null)
                .ToListAsync(ct);

            foreach (var fd in fdAccounts)
            {
                var tenure = fd.Scheme!.MaxTenureMonths!.Value;
                var maturityDate = fd.OpenDate.AddMonths(tenure);
                if (maturityDate >= today && maturityDate <= thirtyDaysFromNow)
                {
                    var daysLeft = maturityDate.DayNumber - today.DayNumber;
                    var member = fd.Member;
                    var memberName = member is not null
                        ? $"{member.FirstName} {member.LastName}".Trim()
                        : "Member";
                    items.Add(new NotificationDto(
                        Id: $"fd-maturity-{fd.Id}",
                        Title: "FD Maturity Alert",
                        Body: $"Fixed Deposit {fd.AccountNumber} (NPR {fd.CurrentBalance:N0}) for {memberName} matures in {daysLeft} day{(daysLeft == 1 ? "" : "s")}.",
                        Type: "savings",
                        Category: "SAVINGS",
                        CreatedAt: now.AddDays(-1),
                        IsRead: true
                    ));
                }
            }
        }
        catch { /* Skip section on error */ }

        // Sort: unread first, then by most recent
        var sorted = items
            .OrderByDescending(n => !n.IsRead)
            .ThenByDescending(n => n.CreatedAt)
            .ToList();

        return Result<List<NotificationDto>>.Success(sorted);
    }
}
