import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../core/api/api_client.dart';
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
  String _selectedMode = 'Cash';
  final _modes = ['Cash', 'Cheque', 'Bank Transfer', 'Online'];

  // Real account info
  String _accountNumber = '';
  String _memberName = '';
  double _currentBalance = 0;
  bool _loadingAccount = true;

  @override
  void initState() {
    super.initState();
    _fetchAccountInfo();
  }

  Future<void> _fetchAccountInfo() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/v1/savings/accounts/${widget.accountId}');
      final envelope = res.data as Map<String, dynamic>;
      final data = envelope['data'] as Map<String, dynamic>? ?? envelope;
      if (mounted) {
        setState(() {
          _accountNumber = data['accountNumber'] as String? ?? widget.accountId;
          _memberName = data['memberName'] as String? ?? '';
          _currentBalance = (data['balance'] as num?)?.toDouble() ?? 0;
          _loadingAccount = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAccount = false);
    }
  }

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
    final receiptNo = result?.receiptNumber ?? 'RCP-${DateTime.now().millisecondsSinceEpoch}';
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
              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 40),
            ),
            const SizedBox(height: AppDimensions.md),
            const Text('Deposit Successful!', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text('NPR ${_amountCtrl.text} deposited to account',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.xs),
            Text('New Balance: NPR ${balance.toStringAsFixed(2)}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Receipt: $receiptNo',
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
        title: const Text('Deposit', style: AppTextStyles.titleLarge),
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
            // Account info header
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
                    child: _loadingAccount
                        ? const SizedBox(
                            height: 48,
                            child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_accountNumber,
                                  style: AppTextStyles.titleSmall.copyWith(color: Colors.white)),
                              Text(_memberName,
                                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                              Text(
                                'Current Balance: NPR ${_currentBalance.toStringAsFixed(2).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            const Text('Deposit Amount', style: AppTextStyles.titleMedium),
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
                const Text('Payment Mode', style: AppTextStyles.bodyMedium),
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
