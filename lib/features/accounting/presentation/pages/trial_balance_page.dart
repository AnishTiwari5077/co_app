import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class TrialBalancePage extends ConsumerWidget {
  const TrialBalancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('Export', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Period selector
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text('FY 2080/81  •  As of Ashad 32, 2081',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
                  ),
                  child: Text('Balanced ✓',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary)),
                ),
              ],
            ),
          ),
          // Columns header
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Account', style: AppTextStyles.labelSmall.copyWith(color: Colors.white))),
                Expanded(child: Text('Debit', style: AppTextStyles.labelSmall.copyWith(color: Colors.white), textAlign: TextAlign.right)),
                Expanded(child: Text('Credit', style: AppTextStyles.labelSmall.copyWith(color: Colors.white), textAlign: TextAlign.right)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _GroupHeader('ASSETS'),
                _TBRow(code: '1101', name: 'Cash in Hand', debit: 1_250_000, credit: 0),
                _TBRow(code: '1102', name: 'Cash at Bank', debit: 5_430_000, credit: 0),
                _TBRow(code: '1201', name: 'Business Loans', debit: 38_000_000, credit: 0),
                _TBRow(code: '1202', name: 'Agriculture Loans', debit: 12_500_000, credit: 0),
                _TBRow(code: '1203', name: 'Personal Loans', debit: 18_200_000, credit: 0),
                _TBRow(code: '1290', name: 'Loan Loss Provision (contra)', debit: 0, credit: 900_000),
                _TBRow(code: '1401', name: 'Land and Building', debit: 2_500_000, credit: 0),
                _TBRow(code: '1403', name: 'Computer Equipment', debit: 350_000, credit: 0),
                _TBRow(code: '1490', name: 'Accumulated Depreciation', debit: 0, credit: 180_000),
                _GroupHeader('LIABILITIES'),
                _TBRow(code: '2101', name: 'Regular Savings', debit: 0, credit: 32_000_000),
                _TBRow(code: '2102', name: 'Fixed Deposits', debit: 0, credit: 10_500_000),
                _TBRow(code: '2201', name: 'Paid-up Share Capital', debit: 0, credit: 2_500_000),
                _TBRow(code: '2301', name: 'Interest Payable', debit: 0, credit: 320_000),
                _TBRow(code: '2302', name: 'Tax Payable (TDS)', debit: 0, credit: 48_000),
                _GroupHeader('EQUITY'),
                _TBRow(code: '3101', name: 'Reserve Fund', debit: 0, credit: 4_500_000),
                _TBRow(code: '3201', name: 'Prior Year Surplus', debit: 0, credit: 2_800_000),
                _GroupHeader('INCOME'),
                _TBRow(code: '4101', name: 'Interest on Business Loans', debit: 0, credit: 4_100_000),
                _TBRow(code: '4102', name: 'Interest on Agriculture Loans', debit: 0, credit: 1_250_000),
                _TBRow(code: '4103', name: 'Interest on Personal Loans', debit: 0, credit: 2_050_000),
                _TBRow(code: '4201', name: 'Loan Processing Fee', debit: 0, credit: 180_000),
                _GroupHeader('EXPENSES'),
                _TBRow(code: '5101', name: 'Interest on Member Savings', debit: 2_400_000, credit: 0),
                _TBRow(code: '5201', name: 'Staff Salaries', debit: 1_800_000, credit: 0),
                _TBRow(code: '5401', name: 'Loan Loss Provision Expense', debit: 180_000, credit: 0),
                _TotalsRow(
                  totalDebit: 82_610_000,
                  totalCredit: 82_610_000,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ── Supporting widgets ────────────────────────────────────────────────────────


class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.xs),
      child: Text(title,
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
    );
  }
}

class _TBRow extends StatelessWidget {
  final String code, name;
  final int debit, credit;
  const _TBRow({required this.code, required this.name, required this.debit, required this.credit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF2F7))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text('$code  ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontFamily: 'monospace')),
                Expanded(child: Text(name, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(
            child: Text(
              debit > 0 ? _fmt(debit) : '—',
              style: AppTextStyles.bodySmall.copyWith(
                color: debit > 0 ? AppColors.debitAmount : AppColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              credit > 0 ? _fmt(credit) : '—',
              style: AppTextStyles.bodySmall.copyWith(
                color: credit > 0 ? AppColors.creditAmount : AppColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _TotalsRow extends StatelessWidget {
  final int totalDebit, totalCredit;
  const _TotalsRow({required this.totalDebit, required this.totalCredit});

  @override
  Widget build(BuildContext context) {
    String fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.md),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('TOTAL', style: AppTextStyles.titleSmall.copyWith(color: Colors.white))),
          Expanded(child: Text(fmt(totalDebit), style: AppTextStyles.labelLarge.copyWith(color: Colors.white), textAlign: TextAlign.right)),
          Expanded(child: Text(fmt(totalCredit), style: AppTextStyles.labelLarge.copyWith(color: Colors.white), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
