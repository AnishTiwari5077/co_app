/// All API endpoint constants for SahakariMS backend.
/// Base URL is configured per environment.
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String login         = '/api/v1/auth/login';
  static const String logout        = '/api/v1/auth/logout';
  static const String refreshToken  = '/api/v1/auth/refresh-token';
  static const String forgotPassword = '/api/v1/auth/forgot-password';
  static const String resetPassword = '/api/v1/auth/reset-password';
  static const String verifyOtp     = '/api/v1/auth/verify-otp';
  static const String changePassword = '/api/v1/auth/change-password';
  static const String me            = '/api/v1/auth/me';

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static const String dashboard     = '/api/v1/dashboard/summary';
  static const String dashboardBranch = '/api/v1/dashboard/branch';

  // ── Members ──────────────────────────────────────────────────────────────
  static const String members       = '/api/v1/members';
  static String memberById(String id)     => '/api/v1/members/$id';
  static String memberKyc(String id)      => '/api/v1/members/$id/kyc';
  static String approveMember(String id)  => '/api/v1/members/$id/approve';
  static String rejectMember(String id)   => '/api/v1/members/$id/reject';
  static String suspendMember(String id)  => '/api/v1/members/$id/suspend';
  static String memberAccounts(String id) => '/api/v1/members/$id/accounts';
  static String memberLoans(String id)    => '/api/v1/members/$id/loans';

  // ── Savings ───────────────────────────────────────────────────────────────
  static const String savingAccounts    = '/api/v1/savings';
  static String savingById(String id)   => '/api/v1/savings/$id';
  static String deposit(String id)      => '/api/v1/savings/accounts/$id/deposit';
  static String withdraw(String id)     => '/api/v1/savings/accounts/$id/withdraw';
  static String statement(String id)    => '/api/v1/savings/accounts/$id/statement';
  static String freezeAccount(String id)   => '/api/v1/savings/accounts/$id/freeze';
  static String unfreezeAccount(String id) => '/api/v1/savings/accounts/$id/unfreeze';

  // ── Loans ─────────────────────────────────────────────────────────────────
  static const String loans           = '/api/v1/loans';
  static String loanById(String id)   => '/api/v1/loans/$id';
  static String approveLoan(String id) => '/api/v1/loans/$id/approve';
  static String rejectLoan(String id)  => '/api/v1/loans/$id/reject';
  static String disburseLoan(String id) => '/api/v1/loans/$id/disburse';
  static String loanSchedule(String id) => '/api/v1/loans/$id/schedule';
  static String recordEmiPayment(String id) => '/api/v1/loans/$id/payment';
  static String loanPayments(String id)     => '/api/v1/loans/$id/payment';

  // ── Shares ────────────────────────────────────────────────────────────────
  static const String shareAccounts    = '/api/v1/shares';
  static String shareById(String id)   => '/api/v1/shares/$id';
  static String purchaseShares(String id) => '/api/v1/shares/$id/purchase';
  static String refundShares(String id)   => '/api/v1/shares/$id/refund';

  // ── Fixed Deposits ────────────────────────────────────────────────────────
  static const String fixedDeposits   = '/api/v1/fixed-deposits';
  static String fdById(String id)     => '/api/v1/fixed-deposits/$id';
  static String fdMature(String id)   => '/api/v1/fixed-deposits/$id/mature';
  static String fdClose(String id)    => '/api/v1/fixed-deposits/$id/close';

  // ── Accounting ────────────────────────────────────────────────────────────
  static const String accounts        = '/api/v1/accounting/accounts';
  static const String vouchers        = '/api/v1/accounting/vouchers';
  static String voucherById(String id) => '/api/v1/accounting/vouchers/$id';
  static const String trialBalance    = '/api/v1/accounting/trial-balance';
  static const String generalLedger   = '/api/v1/accounting/ledger';
  static const String profitAndLoss   = '/api/v1/accounting/profit-loss';
  static const String balanceSheet    = '/api/v1/accounting/balance-sheet';
  static const String fiscalYears     = '/api/v1/accounting/fiscal-years';

  // ── Reports ───────────────────────────────────────────────────────────────
  static const String reports         = '/api/v1/reports';
  static const String dailyReport     = '/api/v1/reports/daily';
  static const String monthlyReport   = '/api/v1/reports/monthly';
  static const String loanReport      = '/api/v1/reports/loans';
  static const String savingsReport   = '/api/v1/reports/savings';
  static const String collectionReport = '/api/v1/reports/collections';
  static const String defaulterList   = '/api/v1/reports/defaulters';
  static const String npaReport       = '/api/v1/reports/npa';

  // ── Branches ──────────────────────────────────────────────────────────────
  static const String branches        = '/api/v1/branches';
  static String branchById(String id) => '/api/v1/branches/$id';

  // ── Users ─────────────────────────────────────────────────────────────────
  static const String users           = '/api/v1/users';
  static String userById(String id)   => '/api/v1/users/$id';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications   = '/api/v1/notifications';
  static String markRead(String id)   => '/api/v1/notifications/$id/read';
  static const String markAllRead     = '/api/v1/notifications/read-all';

  // ── Health ────────────────────────────────────────────────────────────────
  static const String health          = '/health';
  static const String healthReady     = '/health/ready';
}

/// Application-level constants.
class AppConstants {
  AppConstants._();

  static const String appName       = 'SahakariMS';
  static const String appNameNp     = 'सहकारी व्यवस्थापन प्रणाली';
  static const String appVersion    = '1.0.0';
  static const String companyName   = 'SahakariMS Nepal';

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int defaultPageSize  = 20;
  static const int maxPageSize      = 100;

  // ── Cache TTL (seconds) ───────────────────────────────────────────────────
  static const int memberCacheTtl   = 600;   // 10 minutes
  static const int loanCacheTtl     = 300;   // 5 minutes
  static const int dashboardCacheTtl = 60;   // 1 minute
  static const int balanceCacheTtl  = 30;    // 30 seconds

  // ── Secure Storage Keys ───────────────────────────────────────────────────
  static const String accessTokenKey  = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey       = 'user_id';
  static const String branchIdKey     = 'branch_id';
  static const String userRoleKey     = 'user_role';
  static const String themeKey        = 'theme_mode';

  // ── Financial ─────────────────────────────────────────────────────────────
  static const String currencySymbol  = 'NPR';
  static const String currencyCode    = 'NPR';
  static const int    decimalPlaces   = 2;
  static const double minLoanAmount   = 1000.0;
  static const double maxLoanAmount   = 50000000.0;
  static const int    maxLoanMonths   = 360;

  // ── Nepal-specific ────────────────────────────────────────────────────────
  static const String phonePrefix     = '+977';
  static const int    phoneLengthNp   = 10;
  static const String fiscalYearStart = '07-01'; // Shrawan 1 (BS)
  static const String dateFormatAd    = 'yyyy-MM-dd';
  static const String dateFormatBs    = 'YYYY-MM-DD';
  static const String displayDate     = 'dd MMM yyyy';
  static const String displayDateFull = 'EEEE, dd MMMM yyyy';
  static const String displayDateTime = 'dd MMM yyyy, hh:mm a';

  // ── UI ────────────────────────────────────────────────────────────────────
  static const Duration animDuration     = Duration(milliseconds: 300);
  static const Duration animDurationFast = Duration(milliseconds: 150);
  static const Duration animDurationSlow = Duration(milliseconds: 500);
  static const double borderRadius       = 12.0;
  static const double borderRadiusLg    = 20.0;
  static const double cardElevation     = 0.0;

  // ── API ───────────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int maxRetries          = 3;
}
