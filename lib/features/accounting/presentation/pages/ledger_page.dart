import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Re-exported from trial_balance_page.dart
class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Forward to the LedgerPage implemented in trial_balance_page.dart
    // This stub file satisfies the router import
    return const _LedgerPageImpl();
  }
}

class _LedgerPageImpl extends StatelessWidget {
  const _LedgerPageImpl();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('General Ledger', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: const Color(0xFFE8EDF3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1101 — Cash in Hand', style: AppTextStyles.titleMedium),
                Text('Asset  •  Opening Balance: NPR 1,00,000',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppDimensions.md),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.5),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1.2),
                    3: FlexColumnWidth(1.2),
                    4: FlexColumnWidth(1.2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: AppColors.surfaceVariant),
                      children: ['Date', 'Narration', 'Debit', 'Credit', 'Balance'].map((h) =>
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(h, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                          )).toList(),
                    ),
                    ...[
                      ['15 Ashad', 'Deposit - Ram Shrestha', '25,000', '—', '1,25,000'],
                      ['15 Ashad', 'EMI - Sita Tamang', '11,634', '—', '1,36,634'],
                      ['14 Ashad', 'Withdrawal - Hari', '—', '10,000', '1,26,634'],
                      ['13 Ashad', 'Salary Payment', '—', '1,80,000', '1,46,634'],
                    ].map((row) => TableRow(
                      children: row.map((cell) => Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(cell, style: AppTextStyles.bodySmall),
                      )).toList(),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
