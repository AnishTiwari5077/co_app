/// All named route path constants for SahakariMS.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const String login = '/login';
  static const String otp   = '/otp';

  // Main
  static const String dashboard     = '/dashboard';
  static const String members       = '/members';
  static const String loans         = '/loans';
  static const String savings       = '/savings';
  static const String accounting    = '/accounting';
  static const String reports       = '/reports';
  static const String notifications = '/notifications';
  static const String settings      = '/settings';

  // Member sub-routes
  static const String memberRegister = '/members/register';
  static String memberDetail(String id) => '/members/$id';

  // Loan sub-routes
  static const String loanApply = '/loans/apply';
  static String loanDetail(String id)  => '/loans/$id';
  static String emiSchedule(String id) => '/loans/$id/schedule';

  // Savings sub-routes
  static const String savingsOpen      = '/savings/open';
  static String savingsDetail(String id) => '/savings/$id';
  static String deposit(String id)       => '/savings/$id/deposit';
  static String withdraw(String id)      => '/savings/$id/withdraw';

  // Accounting sub-routes
  static const String trialBalance = '/accounting/trial-balance';
  static const String ledger       = '/accounting/ledger';
  static const String fiscalYears  = '/accounting/fiscal-years';
}
