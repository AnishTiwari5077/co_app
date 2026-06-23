import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class TrialBalanceRow {
  final String accountCode, accountName, accountType;
  final double debit, credit;
  const TrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debit,
    required this.credit,
  });
  factory TrialBalanceRow.fromJson(Map<String, dynamic> j) => TrialBalanceRow(
    accountCode: j['accountCode'] as String? ?? '',
    accountName: j['accountName'] as String? ?? '',
    accountType: j['accountType'] as String? ?? '',
    debit: (j['debitBalance'] as num?)?.toDouble() ?? 0,
    credit: (j['creditBalance'] as num?)?.toDouble() ?? 0,
  );
}

class TrialBalance {
  final String asOfDate, branchName;
  final double totalDebit, totalCredit;
  final bool isBalanced;
  final List<TrialBalanceRow> accounts;
  const TrialBalance({
    required this.asOfDate, required this.branchName,
    required this.totalDebit, required this.totalCredit,
    required this.isBalanced, required this.accounts,
  });
  factory TrialBalance.fromJson(Map<String, dynamic> j) => TrialBalance(
    asOfDate: j['asOfDate'] as String? ?? '',
    branchName: j['branchName'] as String? ?? '',
    totalDebit: (j['totalDebit'] as num?)?.toDouble() ?? 0,
    totalCredit: (j['totalCredit'] as num?)?.toDouble() ?? 0,
    isBalanced: j['isBalanced'] as bool? ?? false,
    accounts: (j['accounts'] as List<dynamic>? ?? [])
        .map((e) => TrialBalanceRow.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _trialBalanceProvider = FutureProvider.autoDispose<TrialBalance>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/accounting/trial-balance');
  final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  return TrialBalance.fromJson(data);
});

// ── Page ──────────────────────────────────────────────────────────────────────

class TrialBalancePage extends ConsumerWidget {
  const TrialBalancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tbAsync = ref.watch(_trialBalanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Trial Balance', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_trialBalanceProvider),
          ),
        ],
      ),
      body: tbAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: AppDimensions.md),
            Text('Could not load trial balance', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimensions.xs),
            Text(e.toString(),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.md),
            TextButton.icon(
              onPressed: () => ref.invalidate(_trialBalanceProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
        data: (tb) {
          // Group accounts by type
          final groups = <String, List<TrialBalanceRow>>{};
          for (final row in tb.accounts) {
            groups.putIfAbsent(row.accountType, () => []).add(row);
          }
          final typeOrder = ['Asset', 'Liability', 'Equity', 'Income', 'Expense'];
          final orderedGroups = typeOrder
              .where((t) => groups.containsKey(t))
              .map((t) => MapEntry(t, groups[t]!))
              .toList();
          // Add any remaining types not in typeOrder
          for (final entry in groups.entries) {
            if (!typeOrder.contains(entry.key)) {
              orderedGroups.add(entry);
            }
          }

          return Column(children: [
            // Header info bar
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md, vertical: AppDimensions.sm),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${tb.branchName}  •  As of ${tb.asOfDate}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tb.isBalanced
                        ? AppColors.secondary.withOpacity(0.12)
                        : AppColors.error.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusRound),
                  ),
                  child: Text(
                    tb.isBalanced ? 'Balanced ✓' : 'Unbalanced ✗',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: tb.isBalanced
                            ? AppColors.secondary
                            : AppColors.error),
                  ),
                ),
              ]),
            ),

            // Column headers
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md, vertical: AppDimensions.sm),
              child: Row(children: [
                Expanded(
                    flex: 4,
                    child: Text('Account',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white))),
                Expanded(
                    child: Text('Debit',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white),
                        textAlign: TextAlign.right)),
                Expanded(
                    child: Text('Credit',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white),
                        textAlign: TextAlign.right)),
              ]),
            ),

            // Account rows
            Expanded(
              child: ListView(
                children: [
                  for (final group in orderedGroups) ...[
                    _GroupHeader(group.key.toUpperCase()),
                    for (final row in group.value)
                      _TBRow(row: row),
                  ],
                  _TotalsRow(
                    totalDebit: tb.totalDebit,
                    totalCredit: tb.totalCredit,
                  ),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.xs),
      child: Text(title,
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
    );
  }
}

class _TBRow extends StatelessWidget {
  final TrialBalanceRow row;
  const _TBRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF2F7))),
      ),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Row(children: [
            Text('${row.accountCode}  ',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace')),
            Expanded(
                child: Text(row.accountName,
                    style: AppTextStyles.bodySmall,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
        Expanded(
          child: Text(
            row.debit > 0 ? _fmt(row.debit) : '—',
            style: AppTextStyles.bodySmall.copyWith(
                color: row.debit > 0
                    ? AppColors.debitAmount
                    : AppColors.textSecondary),
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          child: Text(
            row.credit > 0 ? _fmt(row.credit) : '—',
            style: AppTextStyles.bodySmall.copyWith(
                color: row.credit > 0
                    ? AppColors.creditAmount
                    : AppColors.textSecondary),
            textAlign: TextAlign.right,
          ),
        ),
      ]),
    );
  }

  String _fmt(double n) {
    final s = n.toStringAsFixed(0);
    return s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _TotalsRow extends StatelessWidget {
  final double totalDebit, totalCredit;
  const _TotalsRow({required this.totalDebit, required this.totalCredit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.md),
      child: Row(children: [
        Expanded(
            flex: 4,
            child: Text('TOTAL',
                style: AppTextStyles.titleSmall.copyWith(color: Colors.white))),
        Expanded(
            child: Text(_fmt(totalDebit),
                style:
                    AppTextStyles.labelLarge.copyWith(color: Colors.white),
                textAlign: TextAlign.right)),
        Expanded(
            child: Text(_fmt(totalCredit),
                style:
                    AppTextStyles.labelLarge.copyWith(color: Colors.white),
                textAlign: TextAlign.right)),
      ]),
    );
  }

  String _fmt(double n) {
    final s = n.toStringAsFixed(0);
    return s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
