import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';

final _mockAccounts = [
  _AccountRow(no: 'SAV-2079-00001', memberName: 'Ram Bahadur Shrestha', type: 'Regular Savings', balance: 'NPR 45,000', status: 'Active', lastTxn: '15 Ashad 2081'),
  _AccountRow(no: 'SAV-2079-00002', memberName: 'Sita Tamang', type: 'Regular Savings', balance: 'NPR 12,500', status: 'Active', lastTxn: '10 Ashad 2081'),
  _AccountRow(no: 'FD-2080-00123', memberName: 'Ram Bahadur Shrestha', type: 'Fixed Deposit', balance: 'NPR 2,00,000', status: 'Active', lastTxn: '01 Poush 2080'),
  _AccountRow(no: 'RD-2081-00045', memberName: 'Kamala Gurung', type: 'Recurring Deposit', balance: 'NPR 30,000', status: 'Active', lastTxn: '01 Ashad 2081'),
  _AccountRow(no: 'SAV-2080-00088', memberName: 'Deepak Thapa', type: 'Regular Savings', balance: 'NPR 60,000', status: 'Active', lastTxn: '05 Ashad 2081'),
  _AccountRow(no: 'SAV-2078-00015', memberName: 'Sunita Karki', type: 'Regular Savings', balance: '—', status: 'Dormant', lastTxn: '12 Mangsir 2079'),
];

class SavingsListPage extends ConsumerStatefulWidget {
  const SavingsListPage({super.key});

  @override
  ConsumerState<SavingsListPage> createState() => _SavingsListPageState();
}

class _SavingsListPageState extends ConsumerState<SavingsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Savings', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelLarge,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Accounts'),
            Tab(text: 'Regular'),
            Tab(text: 'Fixed Deposits'),
            Tab(text: 'Recurring'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                _SumCard(label: 'Total Savings', value: 'NPR 4.5Cr', color: AppColors.secondary),
                const SizedBox(width: AppDimensions.sm),
                _SumCard(label: 'Active Accounts', value: '1,245', color: AppColors.primary),
                const SizedBox(width: AppDimensions.sm),
                _SumCard(label: 'FD Portfolio', value: 'NPR 1.2Cr', color: AppColors.accent),
              ],
            ),
          ),
          // Search
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by account no. or member...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_mockAccounts),
                _buildList(_mockAccounts.where((a) => a.type == 'Regular Savings').toList()),
                _buildList(_mockAccounts.where((a) => a.type == 'Fixed Deposit').toList()),
                _buildList(_mockAccounts.where((a) => a.type == 'Recurring Deposit').toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<_AccountRow> accounts) {
    final filtered = _query.isEmpty
        ? accounts
        : accounts.where((a) =>
            a.no.toLowerCase().contains(_query.toLowerCase()) ||
            a.memberName.toLowerCase().contains(_query.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return const EmptyView(
          icon: Icons.savings_outlined,
          title: 'No accounts found',
          subtitle: 'Try adjusting your search');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) => _AccountCard(account: filtered[i]),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final _AccountRow account;
  const _AccountCard({required this.account});

  Color get _typeColor {
    switch (account.type) {
      case 'Fixed Deposit':
        return AppColors.accent;
      case 'Recurring Deposit':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.secondary;
    }
  }

  IconData get _typeIcon {
    switch (account.type) {
      case 'Fixed Deposit':
        return Icons.lock_clock_outlined;
      case 'Recurring Deposit':
        return Icons.repeat_rounded;
      default:
        return Icons.savings_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('${AppRoutes.savings}/${account.no}'),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: const Color(0xFFE8EDF3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 22),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.memberName,
                      style: AppTextStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Text(account.no,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                      Text(account.type, style: AppTextStyles.bodySmall),
                    ],
                  ),
                  Text('Last: ${account.lastTxn}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: account.status),
                const SizedBox(height: 4),
                Text(account.balance,
                    style: AppTextStyles.amountSmall
                        .copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: color, fontSize: 10)),
            Text(value, style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _AccountRow {
  final String no, memberName, type, balance, status, lastTxn;
  const _AccountRow({
    required this.no,
    required this.memberName,
    required this.type,
    required this.balance,
    required this.status,
    required this.lastTxn,
  });
}
