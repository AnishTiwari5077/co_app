# SahakariMS — Module: Notifications

## Overview

The Notifications module manages all outbound communication to members and staff: SMS alerts, email notifications, and mobile push notifications. Every financial transaction triggers an appropriate notification.

---

## Notification Channels

| Channel | Provider | Use Case |
|---------|---------|---------|
| **SMS** | Sparrow SMS (primary) / Aakash SMS (fallback) | Transaction alerts, OTP, EMI reminders |
| **Email** | SendGrid | Reports, statements, KYC documents |
| **Push (FCM)** | Firebase Cloud Messaging | Real-time alerts in mobile app |
| **In-App** | Internal notification centre | Admin/staff notifications |

---

## Notification Templates

### SMS Templates

```
// Deposit
DEPOSIT: NPR {amount} credited to a/c {accountNo}. Avl Bal: NPR {balance}. -SahakariMS

// Withdrawal
WITHDRAWAL: NPR {amount} debited from a/c {accountNo}. Avl Bal: NPR {balance}. -SahakariMS

// Loan disbursement
LOAN DISBURSED: NPR {amount} disbursed to your a/c for loan {loanNo}. EMI: NPR {emi}/month from {date}. -SahakariMS

// EMI receipt
EMI PAID: NPR {amount} received for loan {loanNo}. Outstanding: NPR {outstanding}. Next EMI: {date}. -SahakariMS

// EMI reminder
EMI DUE: Your EMI of NPR {amount} for loan {loanNo} is due on {date}. Pay at branch or via mobile app. -SahakariMS

// EMI overdue
OVERDUE: Your EMI of NPR {amount} for loan {loanNo} is overdue by {days} days. Please pay immediately to avoid penalty. -SahakariMS

// FD maturity
FD MATURITY: Your FD {fdNo} of NPR {amount} matures on {date}. Please visit branch to renew/withdraw. -SahakariMS

// OTP
{otp} is your SahakariMS OTP. Valid for 5 minutes. Do NOT share with anyone. -SahakariMS

// Member approval
MEMBERSHIP APPROVED: Dear {name}, your membership has been approved. Member Code: {code}. Welcome to {branchName}! -SahakariMS

// Dividend
DIVIDEND: NPR {amount} dividend credited to your a/c for FY {year}. Bal: NPR {balance}. -SahakariMS
```

---

## Notification Service Implementation

```csharp
// Infrastructure/Notifications/NotificationService.cs
public class NotificationService : INotificationService
{
    private readonly ISmsGateway _smsGateway;
    private readonly IEmailService _emailService;
    private readonly IFcmService _fcmService;
    private readonly INotificationRepository _repo;
    private readonly ILogger<NotificationService> _logger;

    public async Task SendTransactionNotificationAsync(
        TransactionNotificationRequest request,
        CancellationToken ct)
    {
        var template = GetTemplate(request.NotificationType);
        var message = template.Format(request.Data);

        var notification = new Notification
        {
            MemberId = request.MemberId,
            Channel = NotificationChannel.SMS,
            Body = message,
            ReferenceType = request.ReferenceType,
            ReferenceId = request.ReferenceId
        };

        await _repo.CreateAsync(notification, ct);

        // Send in background (don't block transaction)
        _ = Task.Run(() => SendSmsWithFallbackAsync(
            request.PhoneNumber, message, notification.Id));
    }

    private async Task SendSmsWithFallbackAsync(
        string phone, string message, Guid notificationId)
    {
        try
        {
            // Try primary gateway (Sparrow SMS)
            var result = await _smsGateway.SendAsync(phone, message);

            await _repo.UpdateStatusAsync(notificationId,
                result.Success ? NotificationStatus.Sent : NotificationStatus.Failed,
                result.Reference);
        }
        catch (SparrowSmsException ex)
        {
            _logger.LogWarning(ex, "Sparrow SMS failed, trying fallback");

            // Fallback to Aakash SMS
            try
            {
                await _fallbackSmsGateway.SendAsync(phone, message);
                await _repo.UpdateStatusAsync(notificationId, NotificationStatus.Sent);
            }
            catch (Exception fallbackEx)
            {
                _logger.LogError(fallbackEx, "Both SMS gateways failed for {Phone}", phone);
                await _repo.UpdateStatusAsync(notificationId, NotificationStatus.Failed,
                    failureReason: fallbackEx.Message);
            }
        }
    }
}
```

---

## Sparrow SMS Integration

```csharp
// Infrastructure/Notifications/SparsowSmsGateway.cs
public class SparrowSmsGateway : ISmsGateway
{
    private readonly HttpClient _http;
    private readonly string _token;
    private readonly string _from;

    public async Task<SmsResult> SendAsync(string to, string message, CancellationToken ct = default)
    {
        var payload = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["token"]   = _token,
            ["from"]    = _from,
            ["to"]      = to,
            ["text"]    = message
        });

        var response = await _http.PostAsync(
            "https://api.sparrowsms.com/v2/sms/", payload, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        var result = JsonSerializer.Deserialize<SparrowResponse>(body);

        return new SmsResult
        {
            Success = result?.ResponseCode == 200,
            Reference = result?.Mobile
        };
    }
}
```

---

## Firebase FCM Push Notifications

```csharp
// Infrastructure/Notifications/FcmService.cs
public class FcmService : IFcmService
{
    private readonly FirebaseApp _firebaseApp;

    public async Task SendAsync(PushNotificationRequest request, CancellationToken ct)
    {
        var message = new Message
        {
            Token = request.DeviceToken,
            Notification = new FirebaseAdmin.Messaging.Notification
            {
                Title = request.Title,
                Body = request.Body
            },
            Data = new Dictionary<string, string>
            {
                ["type"] = request.NotificationType,
                ["referenceId"] = request.ReferenceId?.ToString() ?? "",
                ["deepLink"] = request.DeepLink ?? ""
            },
            Android = new AndroidConfig
            {
                Priority = Priority.High,
                Notification = new AndroidNotification
                {
                    Sound = "default",
                    ClickAction = "FLUTTER_NOTIFICATION_CLICK"
                }
            },
            Apns = new ApnsConfig
            {
                Aps = new Aps { Sound = "default" }
            }
        };

        await FirebaseMessaging.DefaultInstance.SendAsync(message, ct);
    }
}
```

---

## Scheduled Notification Jobs (Hangfire)

```csharp
// Runs daily at 8:00 AM
[DisableConcurrentExecution(300)]
public class DailyEmiReminderJob
{
    public async Task ExecuteAsync()
    {
        // Find all EMIs due tomorrow
        var dueEMIs = await _loanRepo.GetEmisDueTomorrowAsync();

        foreach (var emi in dueEMIs)
        {
            await _notificationService.SendTransactionNotificationAsync(
                new TransactionNotificationRequest
                {
                    NotificationType = NotificationType.EmiReminder,
                    MemberId = emi.MemberId,
                    PhoneNumber = emi.MemberPhone,
                    Data = new {
                        amount = emi.EmiAmount.ToNPR(),
                        loanNo = emi.LoanNumber,
                        date = emi.DueDateBs
                    }
                });
        }
    }
}

// Runs daily at 8:30 AM
public class OverdueEmiAlertJob
{
    public async Task ExecuteAsync()
    {
        var overdueLoans = await _loanRepo.GetOverdueLoansAsync(minDaysOverdue: 1);

        foreach (var loan in overdueLoans)
        {
            await _notificationService.SendAsync(new TransactionNotificationRequest
            {
                NotificationType = NotificationType.EmiOverdue,
                Data = new {
                    amount = loan.OverdueAmount.ToNPR(),
                    loanNo = loan.LoanNumber,
                    days = loan.OverdueDays
                }
            });
        }
    }
}

// Runs daily at 9:00 AM
public class FdMaturityReminderJob
{
    public async Task ExecuteAsync()
    {
        var sevenDayFDs = await _fdRepo.GetMaturingFDsAsync(daysAhead: 7);
        var oneDayFDs   = await _fdRepo.GetMaturingFDsAsync(daysAhead: 1);

        foreach (var fd in sevenDayFDs.Concat(oneDayFDs).DistinctBy(f => f.Id))
        {
            await _notificationService.SendAsync(/* FD maturity template */);
        }
    }
}
```

---

## Member Notification Preferences

```sql
CREATE TABLE member_notification_preferences (
    member_id           UUID PRIMARY KEY REFERENCES members(id),
    sms_enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    email_enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    push_enabled        BOOLEAN NOT NULL DEFAULT TRUE,
    -- Fine-grained opt-outs
    sms_transactions    BOOLEAN NOT NULL DEFAULT TRUE,
    sms_emi_reminder    BOOLEAN NOT NULL DEFAULT TRUE,
    sms_marketing       BOOLEAN NOT NULL DEFAULT FALSE,
    email_statements    BOOLEAN NOT NULL DEFAULT TRUE,
    email_marketing     BOOLEAN NOT NULL DEFAULT FALSE
);
```

---

## SMS Delivery Tracking

```sql
-- sms_logs table tracks every SMS
SELECT
    sl.phone_number,
    sl.message,
    sl.gateway,
    sl.status,
    sl.sent_at,
    sl.delivered_at,
    EXTRACT(EPOCH FROM (sl.delivered_at - sl.sent_at)) AS delivery_seconds,
    sl.cost
FROM sms_logs sl
WHERE sl.sent_at >= CURRENT_DATE
ORDER BY sl.sent_at DESC;

-- SMS gateway success rate
SELECT
    gateway,
    COUNT(*) AS total,
    SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) AS delivered,
    ROUND(100.0 * SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate
FROM sms_logs
WHERE sent_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY gateway;
```

---

## API Endpoints

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/notifications` | Any | Get own notification list |
| PUT | `/notifications/{id}/read` | Any | Mark as read |
| PUT | `/notifications/read-all` | Any | Mark all as read |
| GET | `/notifications/preferences` | Any | Get notification preferences |
| PUT | `/notifications/preferences` | Any | Update preferences |
| GET | `/admin/notifications/sms-logs` | ADMIN | SMS delivery logs |
| GET | `/admin/notifications/stats` | ADMIN | Notification statistics |
| POST | `/admin/notifications/send-bulk` | ADMIN | Send bulk SMS to members |
