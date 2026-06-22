# SahakariMS — Module: Mobile Banking

## Overview

The Mobile Banking app allows cooperative members to view their accounts, perform fund transfers, pay bills, and apply for loans directly from their smartphones (Android and iOS).

---

## Features by Role (Member App)

| Feature | Description |
|---------|-------------|
| Account Dashboard | Real-time balances for all accounts |
| Transaction History | Last 90 days of transactions |
| Fund Transfer | Transfer between own accounts |
| EMI Payment | Pay loan EMI from savings account |
| QR Payment | FonePay/eSewa QR code scanning |
| Utility Bills | Electricity, water, internet bills |
| Fixed Deposit | View and create FD from app |
| Loan Application | Apply for loans from mobile |
| Loan Status | Track loan application progress |
| Statement Download | Download PDF statement |
| Account Opening | Open new savings account |
| Push Notifications | Transaction alerts, EMI reminders |
| Biometric Login | Fingerprint/face unlock |
| Profile Update | Update phone and address |
| Passbook | Digital passbook view |

---

## Authentication Flow

```
First Time Setup:
  1. Download app
  2. Enter member code + registered phone
  3. Receive OTP via SMS
  4. Verify OTP
  5. Set 4-digit mPIN
  6. Optional: Enable biometric

Subsequent Logins:
  Enter mPIN (or biometric)
  → Access token issued (2 hours)
  → Refresh token (30 days for mobile)
```

---

## Transaction Limits

| Transaction Type | Daily Limit | Per Transaction Limit |
|----------------|------------|----------------------|
| Fund Transfer (own) | NPR 2,00,000 | NPR 1,00,000 |
| QR Payment | NPR 50,000 | NPR 25,000 |
| Utility Payment | NPR 20,000 | NPR 5,000 |
| EMI Payment | No limit | No limit |
| FD Creation | No limit | No limit |

---

## App Screen Structure

```
Bottom Navigation:
  🏠 Home         → Dashboard
  💳 Accounts     → Savings + FD + Loans
  🔄 Payments     → Transfer + QR + Bills
  📄 Statements   → History + Download
  👤 Profile      → Settings + Help

HOME DASHBOARD
──────────────
┌─────────────────────────────────┐
│  Good morning, Ram! 🙏          │
│  Total Balance                  │
│  NPR 1,25,000.00                │
│                                 │
│  ┌──────────┐  ┌──────────┐    │
│  │ Savings  │  │  Loans   │    │
│  │ 45,000   │  │ 80,000   │    │
│  └──────────┘  └──────────┘    │
│                                 │
│  Quick Actions                  │
│  [Transfer] [Pay] [QR] [More]   │
│                                 │
│  Recent Transactions            │
│  ─────────────────────────────  │
│  Deposit    +5,000   2081-04-15 │
│  Withdrawal -2,000   2081-04-10 │
│  Interest   +238     2081-03-31 │
└─────────────────────────────────┘
```

---

## QR Payment Flow

```
1. Tap "Pay with QR"
2. Camera opens — scan merchant QR code (FonePay format)
3. Merchant details shown:
   - Merchant name
   - Amount (pre-filled or enter manually)
4. Select source account
5. Confirm with mPIN
6. Payment processed via FonePay gateway
7. Receipt shown and SMS sent
```

---

## Push Notification Templates

```
Deposit:       "NPR {amount} credited to your account {acctNo}. Balance: NPR {balance}"
Withdrawal:    "NPR {amount} debited from your account {acctNo}. Balance: NPR {balance}"
EMI Due:       "Your EMI of NPR {amount} is due on {date}. Loan: {loanNo}"
EMI Overdue:   "Your EMI of NPR {amount} for loan {loanNo} is overdue by {days} days."
FD Maturity:   "Your FD {fdNo} of NPR {amount} matures on {date}. Please visit branch."
Dividend:      "Dividend of NPR {amount} has been credited to your account."
OTP:           "{otp} is your SahakariMS OTP. Valid for 5 minutes. Don't share."
```

---

## Security Features

| Feature | Implementation |
|---------|---------------|
| 4-digit mPIN | bcrypt hashed locally + server-side |
| Biometric auth | platform_biometric Flutter plugin |
| Session timeout | 15 min inactivity auto-lock |
| Transaction PIN | Required for payments > NPR 5,000 |
| Device binding | Max 2 devices per member |
| jailbreak detection | flutter_jailbreak_detection |
| Certificate pinning | flutter_certificate_pinning |
| Sensitive screen protection | FLAG_SECURE on Android |
| Loan application — KYC required | Server-side check |

---

## Offline Capabilities

The mobile banking app has limited offline capabilities:

| Feature | Online | Offline |
|---------|--------|---------|
| View last balance | Yes | Yes (cached) |
| View cached transactions | Yes | Yes (last 30 days) |
| View EMI schedule | Yes | Yes (cached) |
| Perform transactions | Yes | No |
| Download statement | Yes | No |

---

## State Management

```dart
// lib/mobile/features/dashboard/providers/dashboard_provider.dart

@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  @override
  FutureOr<DashboardState> build() async {
    return await _fetchDashboardData();
  }

  Future<DashboardState> _fetchDashboardData() async {
    final api = ref.read(mobileApiServiceProvider);
    final [accounts, recentTxns, loans] = await Future.wait([
      api.getAccountSummaries(),
      api.getRecentTransactions(limit: 10),
      api.getLoanSummaries(),
    ]);

    return DashboardState(
      totalBalance: accounts.fold(0, (sum, a) => sum + a.balance),
      accounts: accounts,
      recentTransactions: recentTxns,
      loans: loans,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchDashboardData());
  }
}
```

---

## API Endpoints (Member App)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/mobile/auth/login` | None | Member mPIN login |
| POST | `/mobile/auth/setup` | OTP | First-time setup |
| POST | `/mobile/auth/refresh` | Refresh | Token refresh |
| GET | `/mobile/dashboard` | Member | Dashboard summary |
| GET | `/mobile/accounts` | Member | All accounts + balances |
| GET | `/mobile/accounts/{id}/transactions` | Member | Transaction history |
| GET | `/mobile/accounts/{id}/statement` | Member | PDF statement |
| POST | `/mobile/transfer` | Member + mPIN | Fund transfer |
| POST | `/mobile/payments/qr` | Member + mPIN | QR payment |
| POST | `/mobile/payments/bill` | Member + mPIN | Bill payment |
| GET | `/mobile/loans` | Member | Loan summaries |
| POST | `/mobile/loans/apply` | Member | Loan application |
| POST | `/mobile/loans/{id}/pay-emi` | Member + mPIN | EMI payment |
| GET | `/mobile/notifications` | Member | Notification list |
| POST | `/mobile/profile/update-phone` | Member + OTP | Change phone |
| POST | `/mobile/devices/register` | Member | Register device |
