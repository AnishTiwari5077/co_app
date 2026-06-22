import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../router/app_routes.dart';

/// Bottom navigation shell for all main features.
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _destinations = [
    _NavItem(AppRoutes.dashboard, Icons.dashboard_outlined, Icons.dashboard,
        'Dashboard'),
    _NavItem(AppRoutes.members, Icons.people_outline, Icons.people, 'Members'),
    _NavItem(AppRoutes.loans, Icons.account_balance_outlined,
        Icons.account_balance, 'Loans'),
    _NavItem(
        AppRoutes.savings, Icons.savings_outlined, Icons.savings, 'Savings'),
    _NavItem(AppRoutes.accounting, Icons.receipt_long_outlined,
        Icons.receipt_long, 'Accounting'),
  ];

  int _selectedIndex(String location) {
    for (int i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _selectedIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: _buildNavBar(context, selectedIndex),
      floatingActionButton: _buildContextFab(context, location),
    );
  }

  Widget _buildNavBar(BuildContext context, int selectedIndex) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_destinations[i].path),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _destinations
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon:
                      Icon(item.selectedIcon, color: AppColors.primary),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }

  Widget? _buildContextFab(BuildContext context, String location) {
    if (location.startsWith(AppRoutes.members) &&
        location == AppRoutes.members) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoutes.members}/register'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('New Member'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    if (location.startsWith(AppRoutes.loans) && location == AppRoutes.loans) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoutes.loans}/apply'),
        icon: const Icon(Icons.add_chart_outlined),
        label: const Text('Apply Loan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    if (location.startsWith(AppRoutes.savings) &&
        location == AppRoutes.savings) {
      return FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: const Text('Deposit'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      );
    }
    return null;
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.path, this.icon, this.selectedIcon, this.label);
}
