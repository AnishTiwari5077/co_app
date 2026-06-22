import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Reports', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          _ReportCategory(
            title: 'Financial Reports',
            icon: Icons.account_balance_outlined,
            color: AppColors.primary,
            reports: [
              _ReportItem(title: 'Trial Balance', subtitle: 'Debit/Credit summary by account', icon: Icons.balance_rounded),
              _ReportItem(title: 'Income Statement', subtitle: 'Profit & Loss for fiscal year', icon: Icons.trending_up_rounded),
              _ReportItem(title: 'Balance Sheet', subtitle: 'Assets, Liabilities & Equity', icon: Icons.account_balance_rounded),
              _ReportItem(title: 'Cash Flow Statement', subtitle: 'Cash inflows and outflows', icon: Icons.currency_rupee_rounded),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _ReportCategory(
            title: 'Loan Reports',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.accent,
            reports: [
              _ReportItem(title: 'Loan Portfolio', subtitle: 'All active loans by type', icon: Icons.list_alt_rounded),
              _ReportItem(title: 'NPA Report', subtitle: 'Non-performing assets analysis', icon: Icons.warning_amber_rounded),
              _ReportItem(title: 'Overdue Loans', subtitle: 'Past due installments report', icon: Icons.schedule_outlined),
              _ReportItem(title: 'Loan Recovery', subtitle: 'Monthly EMI collection report', icon: Icons.payments_rounded),
              _ReportItem(title: 'Disbursement Report', subtitle: 'Loans disbursed by period', icon: Icons.send_rounded),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _ReportCategory(
            title: 'Savings Reports',
            icon: Icons.savings_outlined,
            color: AppColors.secondary,
            reports: [
              _ReportItem(title: 'Savings Summary', subtitle: 'Total savings by account type', icon: Icons.summarize_rounded),
              _ReportItem(title: 'Interest Accrual', subtitle: 'Daily interest calculation', icon: Icons.calculate_rounded),
              _ReportItem(title: 'Dormant Accounts', subtitle: 'Inactive accounts > 12 months', icon: Icons.hourglass_empty_rounded),
              _ReportItem(title: 'Fixed Deposit Maturity', subtitle: 'FDs maturing this month', icon: Icons.lock_clock_outlined),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _ReportCategory(
            title: 'Member Reports',
            icon: Icons.people_outline_rounded,
            color: const Color(0xFF7C3AED),
            reports: [
              _ReportItem(title: 'Member List', subtitle: 'All members with status', icon: Icons.people_rounded),
              _ReportItem(title: 'New Members', subtitle: 'Members registered this month', icon: Icons.person_add_rounded),
              _ReportItem(title: 'Member Demographics', subtitle: 'Gender, age, district breakdown', icon: Icons.bar_chart_rounded),
              _ReportItem(title: 'Share Capital Report', subtitle: 'Shares held per member', icon: Icons.pie_chart_rounded),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _ReportCategory(
            title: 'Compliance Reports',
            icon: Icons.gavel_rounded,
            color: AppColors.error,
            reports: [
              _ReportItem(title: 'COPOMIS Export', subtitle: 'Quarterly DoC submission XML', icon: Icons.description_rounded),
              _ReportItem(title: 'PEARLS Ratios', subtitle: 'Credit union performance metrics', icon: Icons.analytics_rounded),
              _ReportItem(title: 'AML Report', subtitle: 'Large transaction flags', icon: Icons.security_rounded),
              _ReportItem(title: 'Audit Trail', subtitle: 'System activity log export', icon: Icons.history_rounded),
            ],
          ),
          const SizedBox(height: AppDimensions.xxl),
        ],
      ),
    );
  }
}

class _ReportCategory extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_ReportItem> reports;

  const _ReportCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: AppDimensions.xs),
            Text(title, style: AppTextStyles.titleMedium.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: const Color(0xFFE8EDF3)),
          ),
          child: Column(
            children: List.generate(reports.length, (i) {
              final r = reports[i];
              return Column(
                children: [
                  InkWell(
                    onTap: () => _showReportOptions(context, r),
                    borderRadius: i == 0
                        ? const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg))
                        : i == reports.length - 1
                            ? const BorderRadius.vertical(bottom: Radius.circular(AppDimensions.radiusLg))
                            : BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                            child: Icon(r.icon, color: color, size: 20),
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title, style: AppTextStyles.titleSmall),
                                Text(r.subtitle,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download_rounded, size: 18),
                                color: AppColors.textSecondary,
                                onPressed: () {},
                                tooltip: 'Export PDF',
                                padding: EdgeInsets.zero,
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < reports.length - 1)
                    const Divider(height: 1, indent: AppDimensions.md),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  void _showReportOptions(BuildContext context, _ReportItem report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.title, style: AppTextStyles.titleLarge),
            Text(report.subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimensions.md),
            const Divider(),
            const SizedBox(height: AppDimensions.sm),
            ListTile(
              leading: const Icon(Icons.visibility_rounded, color: AppColors.primary),
              title: const Text('View Report'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
              title: const Text('Export as PDF'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded, color: AppColors.secondary),
              title: const Text('Export as Excel'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: AppDimensions.md),
          ],
        ),
      ),
    );
  }
}

class _ReportItem {
  final String title, subtitle;
  final IconData icon;
  const _ReportItem({required this.title, required this.subtitle, required this.icon});
}
