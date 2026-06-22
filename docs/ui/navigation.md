# SahakariMS — UI: Navigation & Routing

## Overview

SahakariMS uses **GoRouter** for declarative navigation with nested routes, guards, and deep linking. Admin and mobile apps have separate routing trees.

---

## Admin App Route Structure

```
/login                         → LoginScreen
/otp-verify                    → OtpVerifyScreen
/
├── /dashboard                 → DashboardScreen
├── /members
│   ├── /                      → MemberListScreen
│   ├── /new                   → MemberRegistrationScreen
│   └── /:memberId
│       ├── /                  → MemberDetailScreen
│       ├── /edit              → MemberEditScreen
│       └── /accounts         → MemberAccountsScreen
├── /savings
│   ├── /                      → SavingsListScreen
│   ├── /:accountId
│   │   ├── /                  → AccountDetailScreen
│   │   ├── /deposit           → DepositScreen
│   │   └── /withdraw          → WithdrawScreen
│   └── /fixed-deposits        → FDListScreen
├── /loans
│   ├── /                      → LoanListScreen
│   ├── /new                   → LoanApplicationScreen
│   ├── /overdue               → OverdueLoansScreen
│   ├── /npa                   → NpaScreen
│   └── /:loanId
│       ├── /                  → LoanDetailScreen
│       └── /schedule          → LoanScheduleScreen
├── /accounting
│   ├── /                      → AccountingDashboard
│   ├── /chart-of-accounts     → ChartOfAccountsScreen
│   ├── /vouchers              → VoucherListScreen
│   ├── /vouchers/new          → VoucherEntryScreen
│   ├── /ledger                → GeneralLedgerScreen
│   └── /trial-balance         → TrialBalanceScreen
├── /cash
│   └── /counter               → CashCounterScreen
├── /reports
│   ├── /daily-collection      → DailyCollectionReport
│   ├── /loan-outstanding      → LoanOutstandingReport
│   ├── /trial-balance         → TrialBalanceReport
│   └── /copomis               → CopomisExportScreen
└── /settings
    ├── /branch                → BranchSettingsScreen
    ├── /users                 → UserManagementScreen
    └── /roles                 → RoleManagementScreen
```

---

## GoRouter Configuration

```dart
// lib/core/navigation/app_router.dart
@riverpod
GoRouter router(RouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authStateProvider.stream)),

    // Global redirect guard
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginPage) return '/login';
      if (isAuthenticated && isLoginPage) return '/dashboard';
      return null;
    },

    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            name: 'otp-verify',
            builder: (context, state) => OtpVerifyScreen(
              twoFactorToken: state.extra as String,
            ),
          ),
        ],
      ),

      // Shell route for main app with sidebar nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              child: const DashboardScreen(),
            ),
          ),

          GoRoute(
            path: '/members',
            name: 'members',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MemberListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'member-new',
                builder: (context, state) => const MemberRegistrationScreen(),
              ),
              GoRoute(
                path: ':memberId',
                name: 'member-detail',
                builder: (context, state) => MemberDetailScreen(
                  memberId: state.pathParameters['memberId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => MemberEditScreen(
                      memberId: state.pathParameters['memberId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          GoRoute(
            path: '/savings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SavingsListScreen(),
            ),
            routes: [
              GoRoute(
                path: ':accountId',
                builder: (context, state) => AccountDetailScreen(
                  accountId: state.pathParameters['accountId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'deposit',
                    builder: (context, state) => DepositScreen(
                      accountId: state.pathParameters['accountId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'withdraw',
                    builder: (context, state) => WithdrawScreen(
                      accountId: state.pathParameters['accountId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          GoRoute(
            path: '/loans',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LoanListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const LoanApplicationScreen(),
              ),
              GoRoute(
                path: ':loanId',
                builder: (context, state) => LoanDetailScreen(
                  loanId: state.pathParameters['loanId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],

    // Global error screen
    errorBuilder: (context, state) => ErrorScreen(
      error: state.error.toString(),
    ),
  );
}
```

---

## Navigation Guards

### Permission Guard

```dart
// Redirect if user lacks required permission
GoRoute(
  path: '/loans/new',
  redirect: (context, state) {
    final perms = ref.read(currentUserPermissionsProvider);
    if (!perms.contains('LOANS_APPLY')) return '/dashboard';
    return null;
  },
  builder: (context, state) => const LoanApplicationScreen(),
),
```

---

## Navigation Helpers

```dart
// lib/core/navigation/navigation_extensions.dart

extension NavigationExtensions on BuildContext {
  // Named navigation methods (no magic strings in UI code)
  void goToMember(String memberId) =>
      go('/members/$memberId');

  void goToMemberEdit(String memberId) =>
      go('/members/$memberId/edit');

  void goToDeposit(String accountId) =>
      go('/savings/$accountId/deposit');

  void goToLoan(String loanId) =>
      go('/loans/$loanId');

  void goToNewLoan() => go('/loans/new');

  void goBack() => pop();
}
```

---

## Sidebar Navigation Widget

```dart
// lib/shared/widgets/app_sidebar.dart
class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).matchedLocation;

    return NavigationDrawer(
      selectedIndex: _getSelectedIndex(location),
      onDestinationSelected: (index) => _navigateTo(context, index),
      children: [
        // User profile header
        DrawerHeader(
          child: UserProfileHeader(user: user),
        ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Members'),
        ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.savings_outlined),
          selectedIcon: Icon(Icons.savings),
          label: Text('Savings'),
        ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.account_balance_outlined),
          selectedIcon: Icon(Icons.account_balance),
          label: Text('Loans'),
        ),

        const Divider(),

        const NavigationDrawerDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('Accounting'),
        ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          label: Text('Cash Counter'),
        ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: Text('Reports'),
        ),

        const Divider(),

        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }
}
```
