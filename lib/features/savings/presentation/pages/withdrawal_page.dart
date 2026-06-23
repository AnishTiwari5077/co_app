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
import '../../../../core/api/api_client.dart';

// ── Lightweight account summary for balance display ───────────────────────────

class _AccountMini {
  final double balance;
  final double minimumBalance;
  final String accountNumber;
  const _AccountMini(
      {required this.balance,
      required this.minimumBalance,
      required this.accountNumber});

  double get available => (balance - minimumBalance).clamp(0, double.infinity);
}

final _accountMiniProvider =
    FutureProvider.autoDispose.family<_AccountMini, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/savings/accounts/$id');
  final data =
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ??
          res.data as Map<String, dynamic>;
  return _AccountMini(
    accountNumber: data['accountNumber'] as String? ?? id,
    balance: (data['balance'] as num?)?.toDouble() ?? 0,
    minimumBalance: (data['minimumBalance'] as num?)?.toDouble() ?? 0,
  );
});

// ── Page ──────────────────────────────────────────────────────────────────────

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
  String _selectedMode = 'Cash';
  final _modes = ['Cash', 'Cheque', 'Bank Transfer', 'Online'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  Future<void> _processWithdrawal(_AccountMini account) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final success = await ref.read(withdrawProvider.notifier).submit(
          accountId: widget.accountId,
          amount: amount,
          mode: _selectedMode,
          narration: _narrationCtrl.text.trim(),
        );
    if (success && mounted) {
      final result = ref.read(withdrawProvider).result;
      _showSuccess(result);
    } else if (mounted) {
      final error =
          ref.read(withdrawProvider).error ?? 'Withdrawal failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  void _showSuccess(dynamic result) {
    final receiptNo =
        result?.receiptNumber ?? 'RCP-${DateTime.now().millisecondsSinceEpoch}';
    final balance = result?.balanceAfter ?? 0.0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.md),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: AppDimensions.md),
            const Text('Withdrawal Successful!', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text(
                'NPR ${_amountCtrl.text} withdrawn successfully',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.xs),
            Text(
                'New Balance: NPR ${balance.toStringAsFixed(2)}',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Receipt: $receiptNo',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimensions.lg),
            AppButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync =
        ref.watch(_accountMiniProvider(widget.accountId));
    final txnState = ref.watch(withdrawProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Withdrawal', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: accountAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 8),
              const Text('Failed to load account',
                  style: AppTextStyles.titleSmall),
              const SizedBox(height: 4),
              Text(e.toString(),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              TextButton.icon(
                onPressed: () => ref
                    .invalidate(_accountMiniProvider(widget.accountId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (account) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.md),
            children: [
              // Balance summary card
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(color: const Color(0xFFE8EDF3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.accountNumber,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary)),
                          Text(
                              'NPR ${account.balance.toStringAsFixed(2)}',
                              style: AppTextStyles.headlineSmall),
                          Text('Current Balance',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 50,
                        color: const Color(0xFFE8EDF3)),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary)),
                          Text(
                              'NPR ${account.available.toStringAsFixed(2)}',
                              style: AppTextStyles.titleMedium
                                  .copyWith(color: AppColors.secondary)),
                          Text(
                              'Min bal: NPR ${account.minimumBalance.toStringAsFixed(0)}',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10)),
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
                validator: (v) {
                  if (v?.isEmpty == true) return 'Amount required';
                  final amt = double.tryParse(v!) ?? 0;
                  if (amt <= 0) return 'Must be greater than 0';
                  if (amt > account.available) {
                    return 'Exceeds available balance (NPR ${account.available.toStringAsFixed(2)})';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.md),
              // Quick amounts
              Row(
                children: [1000, 5000, 10000, 20000].map((amt) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => _amountCtrl.text = amt.toString(),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMd),
                            border:
                                Border.all(color: const Color(0xFFE0E7EF)),
                          ),
                          child: Text(
                              'NPR ${amt < 1000 ? amt : '${amt ~/ 1000}K'}',
                              style: AppTextStyles.labelSmall,
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.md),
              // Mode selector
              const Text('Payment Mode *', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppDimensions.xs),
              Wrap(
                spacing: AppDimensions.xs,
                children: _modes.map((m) {
                  final sel = _selectedMode == m;
                  return ChoiceChip(
                    label: Text(m),
                    selected: sel,
                    onSelected: (_) => setState(() => _selectedMode = m),
                    selectedColor: AppColors.primary,
                    labelStyle: AppTextStyles.labelSmall.copyWith(
                      color: sel ? Colors.white : AppColors.textPrimary,
                    ),
                    showCheckmark: false,
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
      ),
      bottomNavigationBar: accountAsync.whenData((account) {
        return Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
          ),
          child: AppButton(
            label: 'Process Withdrawal',
            onPressed: () => _processWithdrawal(account),
            isLoading: txnState.isLoading,
            icon: Icons.check_rounded,
          ),
        );
      }).value,
    );
  }
}
