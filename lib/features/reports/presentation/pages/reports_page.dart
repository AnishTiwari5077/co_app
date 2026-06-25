import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/main_shell.dart';
import 'reports_pdf_generator.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _membersReportProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/members', queryParameters: {'pageSize': 10000});
  final envelope = res.data as Map<String, dynamic>;
  return (envelope['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
});

final _loansReportProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/loans', queryParameters: {'pageSize': 10000});
  final envelope = res.data as Map<String, dynamic>;
  return (envelope['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
});

final _savingsReportProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/savings/accounts', queryParameters: {'pageSize': 10000});
  final envelope = res.data as Map<String, dynamic>;
  return (envelope['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
});


// ── Page ──────────────────────────────────────────────────────────────────────

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh data',
            onPressed: () {
              ref.invalidate(_membersReportProvider);
              ref.invalidate(_loansReportProvider);
              ref.invalidate(_savingsReportProvider);
            },
          ),
          const AppBarUserBadge(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          _ReportCategory(
            title: 'Financial Reports',
            icon: Icons.account_balance_outlined,
            color: AppColors.primary,
            reports: [

              _ReportItem(
                title: 'Member List',
                subtitle: 'All registered members with status',
                icon: Icons.people_rounded,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'Member List Report',
                        'All registered members', Icons.people_rounded,
                        AppColors.primary, () async {
                      final members = await ref.read(_membersReportProvider.future);
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewMemberList(ctx, members);
                      }
                    }),
              ),
              _ReportItem(
                title: 'Savings Summary',
                subtitle: 'All savings accounts & balances',
                icon: Icons.savings_rounded,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'Savings Summary Report',
                        'All savings accounts', Icons.savings_rounded,
                        AppColors.secondary, () async {
                      final accounts = await ref.read(_savingsReportProvider.future);
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewSavingsSummary(ctx, accounts);
                      }
                    }),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _ReportCategory(
            title: 'Loan Reports',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.accent,
            reports: [
              _ReportItem(
                title: 'Loan Portfolio',
                subtitle: 'All active loans by status',
                icon: Icons.list_alt_rounded,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'Loan Portfolio Report',
                        'All loans', Icons.list_alt_rounded, AppColors.accent,
                        () async {
                      final loans = await ref.read(_loansReportProvider.future);
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewLoanPortfolio(ctx, loans);
                      }
                    }),
              ),
              _ReportItem(
                title: 'NPA Report',
                subtitle: 'Non-performing assets (overdue > 90 days)',
                icon: Icons.warning_amber_rounded,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'NPA Report',
                        'Non-performing assets', Icons.warning_amber_rounded,
                        AppColors.error, () async {
                      final loans = await ref.read(_loansReportProvider.future);
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewNpaReport(ctx, loans);
                      }
                    }),
              ),
              _ReportItem(
                title: 'Overdue Loans',
                subtitle: 'Past due installments report',
                icon: Icons.schedule_outlined,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'Overdue Loans',
                        'Loans with outstanding overdue amounts',
                        Icons.schedule_outlined, AppColors.error, () async {
                      final loans = await ref.read(_loansReportProvider.future);
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewOverdueLoans(ctx, loans);
                      }
                    }),
              ),
              _ReportItem(
                title: 'Disbursed Loans',
                subtitle: 'All disbursed loans',
                icon: Icons.send_rounded,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'Disbursed Loans Report',
                        'All loans with Disbursed status',
                        Icons.send_rounded, AppColors.accent, () async {
                      final loans = await ref.read(_loansReportProvider.future);
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewLoanPortfolio(
                            ctx, loans,
                            statusFilter: 'Disbursed');
                      }
                    }),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _ReportCategory(
            title: 'Member Reports',
            icon: Icons.people_outline_rounded,
            color: const Color(0xFF7C3AED),
            reports: [
              _ReportItem(
                title: 'Active Members',
                subtitle: 'Members with Active status',
                icon: Icons.person_rounded,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'Active Members Report',
                        'All active members', Icons.person_rounded,
                        const Color(0xFF7C3AED), () async {
                      final all = await ref.read(_membersReportProvider.future);
                      final members =
                          all.where((m) => m['status'] == 'Active').toList();
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewMemberList(ctx, members);
                      }
                    }),
              ),
              _ReportItem(
                title: 'Pending Approvals',
                subtitle: 'Members awaiting activation',
                icon: Icons.pending_actions_rounded,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'Pending Members Report',
                        'Members awaiting approval',
                        Icons.pending_actions_rounded, AppColors.accent,
                        () async {
                      final all = await ref.read(_membersReportProvider.future);
                      final members =
                          all.where((m) => m['status'] == 'Pending').toList();
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewMemberList(ctx, members);
                      }
                    }),
              ),
              _ReportItem(
                title: 'Full Member Registry',
                subtitle: 'All members with full details',
                icon: Icons.people_rounded,
                onTap: (ctx, ref) =>
                    _showReportSheet(ctx, ref, 'Member Registry',
                        'Complete member list', Icons.people_rounded,
                        const Color(0xFF7C3AED), () async {
                      final members =
                          await ref.read(_membersReportProvider.future);
                      if (ctx.mounted) {
                        await ReportsPdfGenerator.previewMemberList(ctx, members);
                      }
                    }),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xxl),
        ],
      ),
    );
  }


  static Future<void> _showReportSheet(
    BuildContext ctx,
    WidgetRef ref,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Future<void> Function() onGenerate,
  ) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleLarge),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppDimensions.md),
            const Divider(),
            const SizedBox(height: AppDimensions.sm),
            _GenerateButton(
              label: 'Export as PDF',
              icon: Icons.picture_as_pdf_rounded,
              color: color,
              onTap: () async {
                Navigator.pop(sheetCtx);
                try {
                  await onGenerate();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Failed: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              },
            ),
            const SizedBox(height: AppDimensions.md),
          ],
        ),
      ),
    );
  }
}

// ── Reusable generate button ──────────────────────────────────────────────────

class _GenerateButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
  const _GenerateButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                await widget.onTap();
                if (mounted) setState(() => _loading = false);
              },
        style: FilledButton.styleFrom(
          backgroundColor: widget.color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(widget.icon, size: 18),
        label: Text(_loading ? 'Generating...' : widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Report Category & Item widgets ────────────────────────────────────────────

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
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppDimensions.xs),
          Text(title,
              style: AppTextStyles.titleMedium.copyWith(color: color)),
        ]),
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
              return Column(children: [
                Consumer(
                  builder: (ctx, ref, _) => InkWell(
                    onTap: () => r.onTap(ctx, ref),
                    borderRadius: i == 0
                        ? const BorderRadius.vertical(
                            top: Radius.circular(AppDimensions.radiusLg))
                        : i == reports.length - 1
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(AppDimensions.radiusLg))
                            : BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
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
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf_rounded,
                                  size: 14, color: color),
                              const SizedBox(width: 4),
                              Text('PDF',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: color)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                      ]),
                    ),
                  ),
                ),
                if (i < reports.length - 1)
                  const Divider(height: 1, indent: AppDimensions.md),
              ]);
            }),
          ),
        ),
      ],
    );
  }
}

class _ReportItem {
  final String title, subtitle;
  final IconData icon;
  final Future<void> Function(BuildContext ctx, WidgetRef ref) onTap;
  const _ReportItem(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});
}
