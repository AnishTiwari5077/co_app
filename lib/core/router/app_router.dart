import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/members/presentation/pages/member_list_page.dart';
import '../../features/members/presentation/pages/member_detail_page.dart';
import '../../features/members/presentation/pages/member_registration_page.dart';
import '../../features/loans/presentation/pages/loan_list_page.dart';
import '../../features/loans/presentation/pages/loan_detail_page.dart';
import '../../features/loans/presentation/pages/loan_application_page.dart';
import '../../features/loans/presentation/pages/emi_schedule_page.dart';
import '../../features/savings/presentation/pages/savings_list_page.dart';
import '../../features/savings/presentation/pages/savings_detail_page.dart';
import '../../features/savings/presentation/pages/deposit_page.dart';
import '../../features/savings/presentation/pages/withdrawal_page.dart';
import '../../features/accounting/presentation/pages/journal_entry_page.dart';
import '../../features/accounting/presentation/pages/trial_balance_page.dart';
import '../../features/accounting/presentation/pages/ledger_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../widgets/main_shell.dart';

import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isOnLogin = state.matchedLocation.startsWith(AppRoutes.login) ||
          state.matchedLocation.startsWith(AppRoutes.otp);

      if (!isLoggedIn && !isOnLogin) return AppRoutes.login;
      if (isLoggedIn && isOnLogin) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        name: 'otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpPage(phone: phone);
        },
      ),

      // ── Main Shell (bottom nav) ────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const DashboardPage(),
            ),
          ),

          // Members
          GoRoute(
            path: AppRoutes.members,
            name: 'members',
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const MemberListPage(),
            ),
            routes: [
              GoRoute(
                path: 'register',
                name: 'member-register',
                builder: (context, state) => const MemberRegistrationPage(),
              ),
              GoRoute(
                path: ':id',
                name: 'member-detail',
                builder: (context, state) => MemberDetailPage(
                  memberId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          // Loans
          GoRoute(
            path: AppRoutes.loans,
            name: 'loans',
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const LoanListPage(),
            ),
            routes: [
              GoRoute(
                path: 'apply',
                name: 'loan-apply',
                builder: (context, state) {
                  final memberId = state.uri.queryParameters['memberId'];
                  return LoanApplicationPage(memberId: memberId);
                },
              ),
              GoRoute(
                path: ':id',
                name: 'loan-detail',
                builder: (context, state) => LoanDetailPage(
                  loanId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'schedule',
                    name: 'emi-schedule',
                    builder: (context, state) => EmiSchedulePage(
                      loanId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Savings
          GoRoute(
            path: AppRoutes.savings,
            name: 'savings',
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const SavingsListPage(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                name: 'savings-detail',
                builder: (context, state) => SavingsDetailPage(
                  accountId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'deposit',
                    name: 'deposit',
                    builder: (context, state) => DepositPage(
                      accountId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'withdraw',
                    name: 'withdraw',
                    builder: (context, state) => WithdrawalPage(
                      accountId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Accounting
          GoRoute(
            path: AppRoutes.accounting,
            name: 'accounting',
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const JournalEntryPage(),
            ),
            routes: [
              GoRoute(
                path: 'trial-balance',
                name: 'trial-balance',
                builder: (context, state) => const TrialBalancePage(),
              ),
              GoRoute(
                path: 'ledger',
                name: 'ledger',
                builder: (context, state) => const LedgerPage(),
              ),
            ],
          ),

          // Reports
          GoRoute(
            path: AppRoutes.reports,
            name: 'reports',
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const ReportsPage(),
            ),
          ),

          // Notifications
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const NotificationsPage(),
            ),
          ),

          // Settings
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _noTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 200),
  );
}
