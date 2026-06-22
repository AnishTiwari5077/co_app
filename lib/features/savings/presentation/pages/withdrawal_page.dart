import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class WithdrawalPage extends ConsumerStatefulWidget {
  final String accountId;
  const WithdrawalPage({super.key, required this.accountId});

  @override
  ConsumerState<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends ConsumerState<WithdrawalPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  bool _isLoading = false;
  bool _requiresApproval = false;

  final _currentBalance = 45000;
  final _minimumBalance = 500;
  final _pledgedBalance = 0;

  int get _availableBalance => _currentBalance - (_pledgedBalance + _minimumBalance);

  void _onAmountChanged(String value) {
    final amt = int.tryParse(value) ?? 0;
    setState(() {
      _requiresApproval = amt > 100000; // NPR 1L requires manager approval
    });
  }

  Future<void> _processWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiresApproval) {
      _showApprovalDialog();
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccess();
    }
  }

  void _showApprovalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            Text('Manager Approval Required', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Text(
          'Withdrawals above NPR 1,00,000 require manager approval (Rule SAV-W-006). '
          'This request will be sent for approval.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _showSuccess(); },
            child: const Text('Send for Approval'),
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
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
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: AppDimensions.md),
            Text('Withdrawal Successful!', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text('NPR ${_amountCtrl.text} withdrawn from ${widget.accountId}',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.xs),
            Text('Receipt: RCP-2081-00422', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
            const SizedBox(height: AppDimensions.lg),
            AppButton(label: 'Done', onPressed: () { Navigator.pop(ctx); context.pop(); }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Withdrawal', style: AppTextStyles.titleLarge),
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
            // Balance card
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(color: const Color(0xFFE8EDF3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.accountId,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        Text('NPR $_currentBalance',
                            style: AppTextStyles.headlineSmall),
                        Text('Current Balance',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    width: 1, height: 50, color: const Color(0xFFE8EDF3)),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available to Withdraw',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        Text('NPR $_availableBalance',
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.secondary)),
                        Text('Min balance: NPR $_minimumBalance',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            AppTextField(
              controller: _amountCtrl,
              label: 'Withdrawal Amount (NPR) *',
              hint: '0',
              prefixIcon: Icons.currency_rupee_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onAmountChanged,
              validator: (v) {
                if (v?.isEmpty == true) return 'Amount required';
                final amt = int.tryParse(v!) ?? 0;
                if (amt <= 0) return 'Must be greater than 0';
                if (amt > _availableBalance) {
                  return 'Insufficient balance. Max: NPR $_availableBalance';
                }
                return null;
              },
            ),
            if (_requiresApproval) ...[
              const SizedBox(height: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Amount > NPR 1,00,000 requires manager approval (Rule SAV-W-006)',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            // Quick amounts
            Row(
              children: [1000, 5000, 10000, 20000].map((amt) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        _amountCtrl.text = amt.toString();
                        _onAmountChanged(amt.toString());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(color: const Color(0xFFE0E7EF)),
                        ),
                        child: Text('NPR ${amt < 1000 ? amt : '${amt ~/ 1000}K'}',
                            style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.md),
            AppTextField(
              controller: _narrationCtrl,
              label: 'Narration / Purpose',
              hint: 'e.g., Emergency withdrawal',
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
        child: AppButton(
          label: _requiresApproval ? 'Request Approval' : 'Process Withdrawal',
          onPressed: _processWithdrawal,
          isLoading: _isLoading,
          icon: _requiresApproval ? Icons.send_rounded : Icons.check_rounded,
        ),
      ),
    );
  }
}
