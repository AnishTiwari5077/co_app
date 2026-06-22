import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/common_widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildGreeting(),
                const SizedBox(height: AppDimensions.md),
                _buildKpiRow(),
                const SizedBox(height: AppDimensions.md),
                _buildQuickActions(context),
                const SizedBox(height: AppDimensions.md),
                _buildLoanChart(),
                const SizedBox(height: AppDimensions.md),
                _buildSavingsChart(),
                const SizedBox(height: AppDimensions.md),
                _buildRecentTransactions(),
                const SizedBox(height: AppDimensions.md),
                _buildPendingApprovals(context),
                const SizedBox(height: AppDimensions.xxl),
              ]),
            ),
          ),
        ],
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
          Column(
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
        const SizedBox(width: AppDimensions.xs),
      ],
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
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
                Text('Admin User',
                    style: AppTextStyles.headlineSmall
                        .copyWith(color: Colors.white)),
                const SizedBox(height: AppDimensions.xs),
                Text('Kathmandu Branch  •  Mon, 22 Jun 2081',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white60)),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiCard(
                title: 'Total Members',
                value: '1,248',
                icon: Icons.people_rounded,
                iconColor: AppColors.primary,
                subtitle: '+12 this month',
                subtitlePositiveFlag: true,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: KpiCard(
                title: 'Total Savings',
                value: 'NPR 4.5Cr',
                icon: Icons.savings_rounded,
                iconColor: AppColors.secondary,
                subtitle: '+2.3% MoM',
                subtitlePositiveFlag: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                title: 'Active Loans',
                value: 'NPR 7.8Cr',
                icon: Icons.account_balance_rounded,
                iconColor: AppColors.accent,
                subtitle: '342 accounts',
                subtitlePositiveFlag: true,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: KpiCard(
                title: 'NPA Loans',
                value: 'NPR 18L',
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.error,
                subtitle: '2.3% of portfolio',
                subtitlePositiveFlag: false,
              ),
            ),
          ],
        ),
      ],
    );
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
        Text('Quick Actions', style: AppTextStyles.titleMedium),
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
                color: action.color.withOpacity(0.1),
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
    return _ChartCard(
      title: 'Loan Portfolio Trend',
      subtitle: 'Last 6 months (NPR Lakhs)',
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) =>
                  const FlLine(color: Color(0xFFEEF2F7), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                    if (value.toInt() < months.length) {
                      return Text(months[value.toInt()],
                          style: AppTextStyles.bodySmall);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: const [
                  FlSpot(0, 65),
                  FlSpot(1, 70),
                  FlSpot(2, 68),
                  FlSpot(3, 75),
                  FlSpot(4, 72),
                  FlSpot(5, 78),
                ],
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavingsChart() {
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
                  sections: [
                    PieChartSectionData(
                      value: 45,
                      title: '45%',
                      color: AppColors.primary,
                      radius: 40,
                      titleStyle: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: 30,
                      title: '30%',
                      color: AppColors.secondary,
                      radius: 40,
                      titleStyle: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: 15,
                      title: '15%',
                      color: AppColors.accent,
                      radius: 40,
                      titleStyle: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: 10,
                      title: '10%',
                      color: const Color(0xFF7C3AED),
                      radius: 40,
                      titleStyle: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendItem(color: AppColors.primary, label: 'Regular', value: '45%'),
                _LegendItem(color: AppColors.secondary, label: 'Fixed Deposit', value: '30%'),
                _LegendItem(color: AppColors.accent, label: 'Recurring', value: '15%'),
                _LegendItem(color: const Color(0xFF7C3AED), label: 'Others', value: '10%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final transactions = [
      _TxnItem(name: 'Ram Shrestha', type: 'Deposit', amount: '+NPR 25,000', isCredit: true, time: '10:32 AM'),
      _TxnItem(name: 'Sita Tamang', type: 'EMI Payment', amount: '-NPR 11,634', isCredit: false, time: '10:15 AM'),
      _TxnItem(name: 'Hari Poudel', type: 'Withdrawal', amount: '-NPR 10,000', isCredit: false, time: '09:52 AM'),
      _TxnItem(name: 'Kamala Gurung', type: 'Deposit', amount: '+NPR 50,000', isCredit: true, time: '09:40 AM'),
    ];

    return _SectionCard(
      title: 'Recent Transactions',
      child: Column(
        children: transactions.map((t) => _buildTxnRow(t)).toList(),
      ),
    );
  }

  Widget _buildTxnRow(_TxnItem txn) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: txn.isCredit
                  ? AppColors.secondary.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(
              txn.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: txn.isCredit ? AppColors.secondary : AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.name, style: AppTextStyles.titleSmall),
                Text(txn.type,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                txn.amount,
                style: AppTextStyles.amountSmall.copyWith(
                  color:
                      txn.isCredit ? AppColors.creditAmount : AppColors.debitAmount,
                ),
              ),
              Text(txn.time,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovals(BuildContext context) {
    return _SectionCard(
      title: 'Pending Approvals',
      titleAction: TextButton(
        onPressed: () {},
        child:
            Text('View All', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
      ),
      child: Column(
        children: [
          _ApprovalItem(
            name: 'Loan Application — Ram Shrestha',
            amount: 'NPR 5,00,000',
            urgency: 'URGENT',
            age: '5h 23m',
          ),
          const Divider(height: 1),
          _ApprovalItem(
            name: 'Member Registration — Sita Magar',
            amount: 'New Member',
            urgency: 'NORMAL',
            age: '2h 15m',
          ),
          const Divider(height: 1),
          _ApprovalItem(
            name: 'Large Withdrawal — Hari Poudel',
            amount: 'NPR 2,00,000',
            urgency: 'URGENT',
            age: '4h 10m',
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

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
  const _SectionCard({required this.title, required this.child, this.titleAction});

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

class _TxnItem {
  final String name, type, amount, time;
  final bool isCredit;
  const _TxnItem(
      {required this.name,
      required this.type,
      required this.amount,
      required this.isCredit,
      required this.time});
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
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
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
                    style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(amount,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(age,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
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
