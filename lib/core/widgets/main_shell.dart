import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../router/app_routes.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/models/entities.dart';

// ─── Nav item definition ──────────────────────────────────────────────────────
class _NavItem {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final List<String> allowedRoles; // empty = all roles

  const _NavItem(this.path, this.icon, this.selectedIcon, this.label,
      {this.allowedRoles = const []});

  bool isVisibleFor(UserEntity user) {
    if (allowedRoles.isEmpty) return true;
    return allowedRoles.any(user.hasRole);
  }
}

// ─── All possible nav items ───────────────────────────────────────────────────
const _allDestinations = [
  _NavItem(AppRoutes.dashboard, Icons.dashboard_outlined, Icons.dashboard,
      'Dashboard'),
  _NavItem(AppRoutes.members, Icons.people_outline, Icons.people, 'Members',
      allowedRoles: ['ADMIN', 'MANAGER', 'CASHIER', 'LOAN_OFFICER']),
  _NavItem(AppRoutes.loans, Icons.account_balance_outlined,
      Icons.account_balance, 'Loans',
      allowedRoles: ['ADMIN', 'MANAGER', 'LOAN_OFFICER']),
  _NavItem(AppRoutes.savings, Icons.savings_outlined, Icons.savings, 'Savings',
      allowedRoles: ['ADMIN', 'MANAGER', 'CASHIER']),
  _NavItem(AppRoutes.accounting, Icons.receipt_long_outlined,
      Icons.receipt_long, 'Accounting',
      allowedRoles: ['ADMIN', 'MANAGER', 'ACCOUNTANT']),
];

/// Returns filtered tabs for a user, guaranteed >= 2 items.
List<_NavItem> _tabsFor(UserEntity user) {
  final visible =
      _allDestinations.where((d) => d.isVisibleFor(user)).toList();
  // NavigationBar requires at least 2 items; pad with Dashboard if needed
  if (visible.length >= 2) return visible;
  final result = <_NavItem>{...visible, _allDestinations[0]}.toList();
  if (result.length >= 2) return result;
  return [_allDestinations[0], _allDestinations[1]]; // absolute fallback
}

/// Role badge colours
Color _roleColor(UserEntity u) {
  if (u.isAdmin) return const Color(0xFFDC2626);
  if (u.isManager) return const Color(0xFFD97706);
  if (u.isCashier) return const Color(0xFF16A34A);
  if (u.isLoanOfficer) return const Color(0xFF2563EB);
  return const Color(0xFF7C3AED);
}

String _roleLabel(UserEntity u) {
  if (u.isAdmin) return 'ADMIN';
  if (u.isManager) return 'MANAGER';
  if (u.isCashier) return 'CASHIER';
  if (u.isLoanOfficer) return 'LOAN OFFICER';
  return 'ACCOUNTANT';
}

/// Navigation shell — shows only tabs the logged-in user is allowed to see.
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // ── Loading / unauthenticated: never render NavigationBar ────────────────
    if (authState.isLoading || !authState.isAuthenticated) {
      return Scaffold(body: child);
    }

    final user = authState.user!;
    final tabs = _tabsFor(user);
    final location = GoRouterState.of(context).matchedLocation;

    int selectedIndex = 0;
    for (int i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].path)) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          child,
          // User menu in top-right — tap to see profile & logout
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(child: _UserMenuButton(user: user, ref: ref)),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) => context.go(tabs[i].path),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: AppColors.primary.withOpacity(0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: tabs
              .map((item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon:
                        Icon(item.selectedIcon, color: AppColors.primary),
                    label: item.label,
                  ))
              .toList(),
        ),
      ),
      floatingActionButton: _fab(context, location, user),
    );
  }

  Widget? _fab(BuildContext context, String location, UserEntity user) {
    if (location == AppRoutes.members &&
        (user.isAdmin || user.isManager || user.isCashier)) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoutes.members}/register'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('New Member'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    if (location == AppRoutes.loans &&
        (user.isAdmin || user.isManager || user.isLoanOfficer)) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoutes.loans}/apply'),
        icon: const Icon(Icons.add_chart_outlined),
        label: const Text('Apply Loan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    if (location == AppRoutes.savings &&
        (user.isAdmin || user.isManager || user.isCashier)) {
      return FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => const _QuickTransactionSheet(),
          );
        },
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: const Text('Deposit / Withdraw'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    return null;
  }
}

// ─── User Menu Button (tappable role badge + logout) ─────────────────────────
class _UserMenuButton extends StatelessWidget {
  final UserEntity user;
  final WidgetRef ref;
  const _UserMenuButton({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(user);

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 8),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        onSelected: (value) async {
          if (value == 'logout') {
            // Show confirmation dialog
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Sign Out'),
                content: Text(
                    'Are you sure you want to sign out, ${user.fullName.split(' ').first}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626)),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ref.read(authStateProvider.notifier).logout();
            }
          }
        },
        itemBuilder: (_) => [
          // User info header
          PopupMenuItem<String>(
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            user.email.isNotEmpty ? user.email : user.username,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    _roleLabel(user),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.branchName.isNotEmpty
                      ? '🏢 ${user.branchName}'
                      : '🏢 Head Office',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          // Logout
          const PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                SizedBox(width: 12),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        // The trigger: colored role badge
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                _roleLabel(user),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Quick Transaction Bottom Sheet ──────────────────────────────────────────
class _QuickTransactionSheet extends StatelessWidget {
  const _QuickTransactionSheet();

  void _askAccountAndNavigate(BuildContext context, String actionType) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(actionType == 'deposit' ? 'Deposit' : 'Withdrawal',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the savings account number:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. SAV-2079-00001',
                prefixIcon: const Icon(Icons.savings_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final id = ctrl.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(ctx);
              Navigator.pop(context);
              final route = actionType == 'deposit'
                  ? '/savings/$id/deposit'
                  : '/savings/$id/withdraw';
              context.push(route);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Quick Transaction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Select an action to perform',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 20),
          _ActionTile(
            icon: Icons.arrow_downward_rounded,
            iconColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFDCFCE7),
            title: 'Deposit',
            subtitle: 'Credit funds to a savings account',
            onTap: () => _askAccountAndNavigate(context, 'deposit'),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEE2E2),
            title: 'Withdraw',
            subtitle: 'Debit funds from a savings account',
            onTap: () => _askAccountAndNavigate(context, 'withdraw'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon, required this.iconColor, required this.bgColor,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
