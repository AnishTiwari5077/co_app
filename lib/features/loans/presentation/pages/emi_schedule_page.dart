import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class EmiSchedulePage extends ConsumerWidget {
  final String loanId;
  const EmiSchedulePage({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = List.generate(24, (i) {
      final isPaid = i < 7;
      final isCurrent = i == 7;
      final principal = 8334 + (i * 55);
      final interest = (3300 - (i * 95)).clamp(0, 9999);
      return _ScheduleItem(
        no: i + 1,
        dueDate: '01 ${_month(i)} 208${1 + (i ~/ 12)}',
        principal: principal,
        interest: interest,
        emi: 11634,
        balance: isPaid ? 0 : (1_72_614 - (i * 8500)).clamp(0, 999999),
        isPaid: isPaid,
        isCurrent: isCurrent,
      );
    });

    final paidCount = schedule.where((s) => s.isPaid).length;
    final totalPaid = paidCount * 11634;
    final outstanding = 1_80_234;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('EMI Schedule', style: AppTextStyles.titleLarge),
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
            label: Text('PDF', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                _SummaryStat(label: 'Loan ID', value: loanId, color: AppColors.primary),
                const SizedBox(width: AppDimensions.sm),
                _SummaryStat(label: 'Paid', value: 'NPR ${totalPaid.toString()}', color: AppColors.secondary),
                const SizedBox(width: AppDimensions.sm),
                _SummaryStat(label: 'Outstanding', value: 'NPR $outstanding', color: AppColors.error),
              ],
            ),
          ),
          // Progress bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$paidCount / 24 installments paid',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    Text('${(paidCount / 24 * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: paidCount / 24,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(child: _Th('Due Date')),
                Expanded(child: _Th('Principal')),
                Expanded(child: _Th('Interest')),
                Expanded(child: _Th('EMI')),
                Expanded(child: _Th('Balance')),
              ],
            ),
          ),
          // Table rows
          Expanded(
            child: ListView.builder(
              itemCount: schedule.length,
              itemBuilder: (context, i) => _ScheduleRow(item: schedule[i]),
            ),
          ),
        ],
      ),
    );
  }

  String _month(int i) {
    const months = ['Shrawan', 'Bhadra', 'Ashwin', 'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra', 'Baisakh', 'Jestha', 'Ashad'];
    return months[i % 12];
  }
}

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center);
  }
}

class _ScheduleItem {
  final int no, principal, interest, emi, balance;
  final String dueDate;
  final bool isPaid, isCurrent;
  const _ScheduleItem({
    required this.no,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.emi,
    required this.balance,
    required this.isPaid,
    required this.isCurrent,
  });
}

class _ScheduleRow extends StatelessWidget {
  final _ScheduleItem item;
  const _ScheduleRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: item.isCurrent
          ? AppColors.primary.withOpacity(0.04)
          : item.isPaid
              ? AppColors.secondary.withOpacity(0.03)
              : null,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: item.isPaid
                ? const Icon(Icons.check_circle_rounded,
                    color: AppColors.secondary, size: 16)
                : item.isCurrent
                    ? const Icon(Icons.radio_button_checked_rounded,
                        color: AppColors.primary, size: 16)
                    : Text('${item.no}',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(item.dueDate,
                style: AppTextStyles.bodySmall.copyWith(
                    color: item.isCurrent
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: item.isCurrent ? FontWeight.w600 : null),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(_fmt(item.principal),
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(_fmt(item.interest),
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(_fmt(item.emi),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textPrimary),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
                item.isPaid
                    ? '—'
                    : _fmt(item.balance),
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _SummaryStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryStat(
      {required this.label, required this.value, required this.color});

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
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: color, fontSize: 10)),
            Text(value,
                style: AppTextStyles.labelSmall
                    .copyWith(color: color, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
