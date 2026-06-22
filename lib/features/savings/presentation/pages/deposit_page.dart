import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/savings_provider.dart';

class DepositPage extends ConsumerStatefulWidget {
  final String accountId;
  const DepositPage({super.key, required this.accountId});

  @override
  ConsumerState<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends ConsumerState<DepositPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  final _chequeCtrl = TextEditingController();
  bool _isLoading = false;
  String _selectedMode = 'Cash';
  final _modes = ['Cash', 'Cheque', 'Bank Transfer', 'Online'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    _chequeCtrl.dispose();
    super.dispose();
  }

  Future<void> _processDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final success = await ref.read(depositProvider.notifier).submit(
      accountId: widget.accountId,
      amount: amount,
      mode: _selectedMode,
      narration: _narrationCtrl.text.trim(),
      chequeNo: _chequeCtrl.text.trim(),
    );
    if (success && mounted) {
      final result = ref.read(depositProvider).result;
      _showSuccess(result);
    } else if (mounted) {
      final error = ref.read(depositProvider).error ?? 'Deposit failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  void _showSuccess(dynamic result) {
    final txnId = result?.transactionId ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}';
    final balance = result?.balanceAfter ?? 0.0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.md),
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 40),
            ),
            const SizedBox(height: AppDimensions.md),
            Text('Deposit Successful!', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text('NPR ${_amountCtrl.text} deposited to account',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.xs),
            Text('New Balance: NPR ${balance.toStringAsFixed(2)}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Receipt: $txnId',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
            const SizedBox(height: AppDimensions.lg),
            Row(
              children: [
                Expanded(child: AppButton(label: 'Print Receipt', onPressed: () => Navigator.pop(ctx),
                    variant: ButtonVariant.outlined, icon: Icons.print_rounded)),
                const SizedBox(width: AppDimensions.sm),
                Expanded(child: AppButton(label: 'Done', onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                })),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Deposit', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.md),
          children: [
            // Account info
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.accountId, style: AppTextStyles.titleSmall.copyWith(color: Colors.white)),
                        Text('Ram Bahadur Shrestha', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                        Text('Current Balance: NPR 45,000.00', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text('Deposit Amount', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              controller: _amountCtrl,
              label: 'Amount (NPR) *',
              hint: '0',
              prefixIcon: Icons.currency_rupee_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v?.isEmpty == true) return 'Amount required';
                final amt = int.tryParse(v!) ?? 0;
                if (amt < 100) return 'Minimum deposit is NPR 100';
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.md),
            // Quick amounts
            Row(
              children: [5000, 10000, 25000, 50000].map((amt) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _amountCtrl.text = amt.toString()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: const Color(0xFFE0E7EF)),
                        ),
                        child: Text('NPR ${amt ~/ 1000}K',
                            style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.md),
            // Mode selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Mode', style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppDimensions.xs),
                Wrap(
                  spacing: AppDimensions.xs,
                  runSpacing: AppDimensions.xs,
                  children: _modes.map((m) {
                    final sel = _selectedMode == m;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMode = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.secondary : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: sel ? AppColors.secondary : const Color(0xFFE0E7EF)),
                        ),
                        child: Text(m, style: AppTextStyles.labelLarge.copyWith(color: sel ? Colors.white : AppColors.textPrimary)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            if (_selectedMode == 'Cheque') ...[
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                controller: _chequeCtrl,
                label: 'Cheque Number *',
                hint: 'XXXXXXXXXX',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => _selectedMode == 'Cheque' && (v?.isEmpty == true) ? 'Cheque number required' : null,
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              controller: _narrationCtrl,
              label: 'Narration / Remarks',
              hint: 'e.g., Monthly savings deposit',
              maxLines: 2,
            ),
            const SizedBox(height: AppDimensions.xxl),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
        ),
        child: Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(depositProvider);
            return AppButton(
              label: 'Process Deposit',
              onPressed: _processDeposit,
              isLoading: state.isLoading,
              icon: Icons.check_rounded,
              variant: ButtonVariant.secondary,
            );
          },
        ),
      ),
    );
  }
}
