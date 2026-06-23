import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../../core/api/repositories/dashboard_repository.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/main_shell.dart';

// ── Activity Models ───────────────────────────────────────────────────────────

class DashboardRecentTxn {
  final String memberName, transactionType, accountNumber;
  final double amount;
  final DateTime transactionDate;
  DashboardRecentTxn({
    required this.memberName,
    required this.transactionType,
    required this.accountNumber,
    required this.amount,
    required this.transactionDate,
  });
  bool get isCredit => transactionType != 'Withdrawal';
  factory DashboardRecentTxn.fromJson(Map<String, dynamic> j) =>
      DashboardRecentTxn(
        memberName: j['memberName'] as String? ?? '',
        transactionType: j['transactionType'] as String? ?? '',
        accountNumber: j['accountNumber'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        transactionDate:
            DateTime.tryParse(j['transactionDate'] as String? ?? '') ??
                DateTime.now(),
      );
}

class DashboardSchemeDist {
  final String schemeType;
  final double totalBalance;
  final int accountCount;
  DashboardSchemeDist(
      {required this.schemeType,
      required this.totalBalance,
      required this.accountCount});
  factory DashboardSchemeDist.fromJson(Map<String, dynamic> j) =>
      DashboardSchemeDist(
        schemeType: j['schemeType'] as String? ?? '',
        totalBalance: (j['totalBalance'] as num?)?.toDouble() ?? 0,
        accountCount: j['accountCount'] as int? ?? 0,
      );
}

class DashboardPendingItem {
  final String title, subtitle, itemType, urgency;
  final DateTime createdAt;
  DashboardPendingItem({
    required this.title,
    required this.subtitle,
    required this.itemType,
    required this.urgency,
    required this.createdAt,
  });
  factory DashboardPendingItem.fromJson(Map<String, dynamic> j) =>
      DashboardPendingItem(
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        itemType: j['itemType'] as String? ?? '',
        urgency: j['urgency'] as String? ?? 'NORMAL',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class DashboardActivity {
  final List<DashboardRecentTxn> recentTransactions;
  final List<DashboardSchemeDist> savingsDistribution;
  final List<DashboardPendingItem> pendingItems;
  DashboardActivity(
      {required this.recentTransactions,
      required this.savingsDistribution,
      required this.pendingItems});
  factory DashboardActivity.fromJson(Map<String, dynamic> j) =>
      DashboardActivity(
        recentTransactions:
            ((j['recentTransactions'] as List?)?.cast<Map<String, dynamic>>() ??
                    [])
                .map(DashboardRecentTxn.fromJson)
                .toList(),
        savingsDistribution: ((j['savingsDistribution'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                [])
            .map(DashboardSchemeDist.fromJson)
            .toList(),
        pendingItems:
            ((j['pendingItems'] as List?)?.cast<Map<String, dynamic>>() ?? [])
                .map(DashboardPendingItem.fromJson)
                .toList(),
      );
  factory DashboardActivity.empty() => DashboardActivity(
      recentTransactions: [], savingsDistribution: [], pendingItems: []);
}

final dashboardActivityProvider =
    FutureProvider<DashboardActivity>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final res = await dio.get('/api/v1/dashboard/activity');
    final envelope = res.data as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>? ?? envelope;
    return DashboardActivity.fromJson(data);
  } catch (_) {
    return DashboardActivity.empty();
  }
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final activityAsync = ref.watch(dashboardActivityProvider);
    final activity = activityAsync.value ?? DashboardActivity.empty();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(dashboardActivityProvider);
          await ref.read(dashboardSummaryProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverPadding(
              padding: const EdgeInsets.all(AppDimensions.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildGreeting(user),
                  const SizedBox(height: AppDimensions.md),
                  _buildKpiRow(context, summaryAsync),
                  const SizedBox(height: AppDimensions.md),
                  _buildQuickActions(context),
                  const SizedBox(height: AppDimensions.md),
                  _buildLoanChart(),
                  const SizedBox(height: AppDimensions.md),
                  _buildSavingsChart(activity.savingsDistribution),
                  const SizedBox(height: AppDimensions.md),
                  _buildRecentTransactions(activity.recentTransactions),
                  const SizedBox(height: AppDimensions.md),
                  _buildPendingApprovals(context, activity.pendingItems),
                  const SizedBox(height: AppDimensions.xxl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppDimensions.sm),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SahakariMS', style: AppTextStyles.titleMedium),
              Text('Head Office', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.go(AppRoutes.notifications),
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const AppBarUserBadge(),
      ],
    );
  }

  Widget _buildGreeting(dynamic user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final name = user?.fullName ?? 'User';
    final branch =
        user?.branchName.isNotEmpty == true ? user!.branchName : 'Head Office';
    final now = DateTime.now();
    final dateStr =
        '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)} ${now.year}';
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white70)),
                const SizedBox(height: AppDimensions.xs / 2),
                Text(name,
                    style: AppTextStyles.headlineSmall
                        .copyWith(color: Colors.white)),
                const SizedBox(height: AppDimensions.xs),
                Text('$branch  â€¢  $dateStr',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white60)),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekday(int w) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _month(int m) => [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m - 1];

  Widget _buildKpiRow(
      BuildContext context, AsyncValue<DashboardSummary> summaryAsync) {
    return summaryAsync.when(
      loading: () => const Center(
          child: Padding(
        padding: EdgeInsets.all(AppDimensions.lg),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Could not load live data. $e',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ),
          ],
        ),
      ),
      data: (s) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.members),
                  child: KpiCard(
                    title: 'Total Members',
                    value: s.totalMembers.toString(),
                    icon: Icons.people_rounded,
                    iconColor: AppColors.primary,
                    subtitle: '+${s.newMembersThisMonth} this month',
                    subtitlePositiveFlag: true,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.savings),
                  child: KpiCard(
                    title: 'Total Savings',
                    value: _formatAmount(s.totalSavings),
                    icon: Icons.savings_rounded,
                    iconColor: AppColors.secondary,
                    subtitle: '↑ ${_formatAmount(s.todayDeposits)} today',
                    subtitlePositiveFlag: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.loans),
                  child: KpiCard(
                    title: 'Loan Portfolio',
                    value: _formatAmount(s.totalLoans),
                    icon: Icons.account_balance_rounded,
                    iconColor: AppColors.accent,
                    subtitle: '${s.activeLoans} active accounts',
                    subtitlePositiveFlag: true,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: KpiCard(
                  title: 'NPA Rate',
                  value: '${s.npaPercent.toStringAsFixed(1)}%',
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.error,
                  subtitle:
                      'Recovery: ${s.loanRecoveryRate.toStringAsFixed(1)}%',
                  subtitlePositiveFlag: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(double v) {
    if (v >= 10000000) return 'NPR ${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return 'NPR ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return 'NPR ${(v / 1000).toStringAsFixed(1)}K';
    return 'NPR ${v.toStringAsFixed(0)}';
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
          label: 'New Member',
          icon: Icons.person_add_rounded,
          color: AppColors.primary,
          onTap: () => context.go('${AppRoutes.members}/register')),
      _QuickAction(
          label: 'Deposit',
          icon: Icons.arrow_downward_rounded,
          color: AppColors.secondary,
          onTap: () => context.go(AppRoutes.savings)),
      _QuickAction(
          label: 'New Loan',
          icon: Icons.add_card_rounded,
          color: AppColors.accent,
          onTap: () => context.go('${AppRoutes.loans}/apply')),
      _QuickAction(
          label: 'Reports',
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF7C3AED),
          onTap: () => context.go(AppRoutes.reports)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: actions.map((a) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: a != actions.last ? AppDimensions.sm : 0),
                child: _buildActionButton(a),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.md, horizontal: AppDimensions.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: const Color(0xFFE8EDF3)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(action.label,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanChart() {
    final now = DateTime.now();
    final monthLabels = List.generate(6, (i) {
      final monthOffset = now.month - 5 + i;
      final month = monthOffset <= 0 ? monthOffset + 12 : monthOffset;
      const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return names[month - 1];
    });

    const values = [65.0, 70.0, 68.0, 75.0, 72.0, 78.0];
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return _ChartCard(
      title: 'Loan Portfolio Trend',
      subtitle: 'Last 6 months (NPR Lakhs)',
      child: SizedBox(
        height: 160,
        child: CustomPaint(
          painter: _BarChartPainter(
            values: values,
            labels: monthLabels,
            maxValue: maxVal,
            barColor: AppColors.primary,
            labelColor: AppColors.textSecondary,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildSavingsChart(List<DashboardSchemeDist> distribution) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      const Color(0xFF7C3AED),
      const Color(0xFFEC4899),
    ];
    final total = distribution.fold<double>(0, (s, d) => s + d.totalBalance);

    if (distribution.isEmpty || total == 0) {
      return const _ChartCard(
        title: 'Savings Distribution',
        subtitle: 'By account type',
        child: SizedBox(
          height: 160,
          child: Center(child: Text('No savings data yet')),
        ),
      );
    }

    return _ChartCard(
      title: 'Savings Distribution',
      subtitle: 'By account type',
      child: SizedBox(
        height: 160,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 35,
                  sections: distribution.asMap().entries.map((e) {
                    final pct = (e.value.totalBalance / total * 100).round();
                    return PieChartSectionData(
                      value: e.value.totalBalance,
                      title: '$pct%',
                      color: colors[e.key % colors.length],
                      radius: 40,
                      titleStyle: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white, fontSize: 10),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: distribution.asMap().entries.map((e) {
                final pct = (e.value.totalBalance / total * 100).round();
                return _LegendItem(
                  color: colors[e.key % colors.length],
                  label: e.value.schemeType,
                  value: '$pct% (${e.value.accountCount})',
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  String _fmtCompact(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Widget _buildRecentTransactions(List<DashboardRecentTxn> transactions) {
    if (transactions.isEmpty) {
      return const _SectionCard(
        title: 'Recent Transactions',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppDimensions.lg),
          child: Center(child: Text('No transactions yet')),
        ),
      );
    }
    return _SectionCard(
      title: 'Recent Transactions',
      child: Column(
        children: transactions
            .map((t) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.isCredit
                              ? AppColors.secondary.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: Icon(
                          t.isCredit
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: t.isCredit
                              ? AppColors.secondary
                              : AppColors.error,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.memberName,
                                style: AppTextStyles.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(t.transactionType,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${t.isCredit ? '+' : '-'}NPR ${_fmtCompact(t.amount)}',
                            style: AppTextStyles.amountSmall.copyWith(
                              color: t.isCredit
                                  ? AppColors.creditAmount
                                  : AppColors.debitAmount,
                            ),
                          ),
                          Text(_fmtTime(t.transactionDate),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildPendingApprovals(
      BuildContext context, List<DashboardPendingItem> items) {
    return _SectionCard(
      title: 'Pending Approvals',
      titleAction: TextButton(
        onPressed: () => context.go(AppRoutes.members),
        child: Text('View All',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
      ),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.lg),
              child: Center(child: Text('No pending approvals 🎉')),
            )
          : Column(
              children: items
                  .asMap()
                  .entries
                  .map((e) => Column(
                        children: [
                          if (e.key > 0) const Divider(height: 1),
                          _ApprovalItem(
                            name: e.value.title,
                            amount: e.value.subtitle,
                            urgency: e.value.urgency,
                            age: _timeAgo(e.value.createdAt),
                          ),
                        ],
                      ))
                  .toList(),
            ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// â”€â”€ Supporting widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _ChartCard(
      {required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          Text(subtitle,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppDimensions.md),
          child,
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? titleAction;
  const _SectionCard(
      {required this.title, required this.child, this.titleAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.titleMedium),
              if (titleAction != null) titleAction!,
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          child,
        ],
      ),
    );
  }
}

class _ApprovalItem extends StatelessWidget {
  final String name, amount, urgency, age;
  const _ApprovalItem(
      {required this.name,
      required this.amount,
      required this.urgency,
      required this.age});

  @override
  Widget build(BuildContext context) {
    final isUrgent = urgency == 'URGENT';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.xs, vertical: 2),
            decoration: BoxDecoration(
              color: isUrgent
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Text(
              urgency,
              style: AppTextStyles.labelSmall.copyWith(
                color: isUrgent ? AppColors.error : AppColors.warning,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(amount,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(age,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label, value;
  const _LegendItem(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$label ', style: AppTextStyles.bodySmall),
          Text(value,
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Bar Chart Painter (replaces fl_chart LineChart for Windows stability) ─────

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double maxValue;
  final Color barColor;
  final Color labelColor;

  const _BarChartPainter({
    required this.values,
    required this.labels,
    required this.maxValue,
    required this.barColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    const topPad = 8.0;
    final chartH = size.height - labelH - topPad;
    final gapW = size.width / values.length;
    final barW = gapW * 0.55;

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFEEF2F7)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH - (chartH * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < values.length; i++) {
      final frac = maxValue > 0 ? values[i] / maxValue : 0.0;
      final barH = (chartH * frac).clamp(2.0, chartH);
      final x = gapW * i + (gapW - barW) / 2;
      final y = topPad + chartH - barH;

      // Bar fill
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barW, barH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()
          ..color = barColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );

      // Top accent
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barW, 3),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        Paint()
          ..color = barColor
          ..style = PaintingStyle.fill,
      );

      // Dot
      canvas.drawCircle(Offset(x + barW / 2, y - 5), 3, Paint()..color = barColor);

      // Month label
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: gapW);
      tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, topPad + chartH + 4));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.values != values || old.maxValue != maxValue;
}

