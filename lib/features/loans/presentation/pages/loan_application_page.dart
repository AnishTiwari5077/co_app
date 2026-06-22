import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class LoanApplicationPage extends ConsumerStatefulWidget {
  final String? memberId;
  const LoanApplicationPage({super.key, this.memberId});

  @override
  ConsumerState<LoanApplicationPage> createState() =>
      _LoanApplicationPageState();
}

class _LoanApplicationPageState extends ConsumerState<LoanApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _emiCalculated = false;

  final _memberSearchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '');
  final _purposeCtrl = TextEditingController();
  final _guarantorCtrl = TextEditingController();
  final _collateralCtrl = TextEditingController();
  final _collateralValueCtrl = TextEditingController();

  String _selectedProduct = 'Personal Loan';
  int _selectedTenure = 12;
  double _calculatedEmi = 0;
  double _totalInterest = 0;

  final _products = ['Personal Loan', 'Business Loan', 'Agriculture Loan', 'Home Loan', 'Microfinance Loan'];
  final _tenures = [3, 6, 12, 18, 24, 36, 48, 60];
  final _productRates = {
    'Personal Loan': 14.0,
    'Business Loan': 13.0,
    'Agriculture Loan': 11.0,
    'Home Loan': 12.0,
    'Microfinance Loan': 15.0,
  };
  final _productMaxAmounts = {
    'Personal Loan': 500000,
    'Business Loan': 5000000,
    'Agriculture Loan': 1000000,
    'Home Loan': 10000000,
    'Microfinance Loan': 200000,
  };

  void _calculateEmi() {
    final principal = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (principal <= 0) return;

    final rate = (_productRates[_selectedProduct] ?? 14) / 12 / 100;
    final n = _selectedTenure;
    final emi = principal * rate * (1 + rate).pow(n) / ((1 + rate).pow(n) - 1);
    setState(() {
      _calculatedEmi = emi;
      _totalInterest = (emi * n) - principal;
      _emiCalculated = true;
    });
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
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
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.secondary, size: 40),
            ),
            const SizedBox(height: AppDimensions.md),
            Text('Loan Applied!', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Application LN-2081-00042 submitted. Awaiting manager approval.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),
            AppButton(
              label: 'View Application',
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
  void dispose() {
    _memberSearchCtrl.dispose();
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _guarantorCtrl.dispose();
    _collateralCtrl.dispose();
    _collateralValueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Loan Application', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(child: _buildStep()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Member', 'Product', 'Security', 'Review'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.secondary
                            : isActive
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : Text('${i + 1}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isActive ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                )),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(steps[i],
                        style: AppTextStyles.bodySmall.copyWith(
                            color: isActive ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: isActive ? FontWeight.w600 : null)),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
                      color: isDone ? AppColors.secondary : AppColors.surfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: [
          _buildMemberStep(),
          _buildProductStep(),
          _buildSecurityStep(),
          _buildReviewStep(),
        ][_currentStep],
      ),
    );
  }

  Widget _buildMemberStep() {
    return Column(
      key: const ValueKey('member'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Member', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        AppTextField(
          controller: _memberSearchCtrl,
          label: 'Search Member',
          hint: 'Name, code or phone...',
          prefixIcon: Icons.search_rounded,
          initialValue: widget.memberId,
          validator: (v) => v?.isEmpty == true ? 'Member required' : null,
        ),
        const SizedBox(height: AppDimensions.sm),
        if (widget.memberId != null) ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ram Bahadur Shrestha', style: AppTextStyles.titleSmall),
                      Text(widget.memberId ?? '',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.primary)),
                      Text('Active  •  KYC ✓  •  Shares: 250',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: AppColors.secondary),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          // Eligibility check
          _EligibilityCard(
            checks: [
              _Check(label: 'Minimum 6 months membership', passed: true),
              _Check(label: 'KYC verified', passed: true),
              _Check(label: 'Minimum 10 shares held', passed: true),
              _Check(label: 'No overdue EMIs', passed: true),
              _Check(label: 'Age 18-65', passed: true),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProductStep() {
    final rate = _productRates[_selectedProduct] ?? 14;
    final maxAmount = _productMaxAmounts[_selectedProduct] ?? 500000;

    return Column(
      key: const ValueKey('product'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Loan Product', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        // Product selector
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: _products.map((p) {
            final selected = _selectedProduct == p;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedProduct = p;
                _emiCalculated = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: selected ? AppColors.primary : const Color(0xFFE0E7EF),
                  ),
                ),
                child: Text(p,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: selected ? Colors.white : AppColors.textPrimary,
                    )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimensions.md),
        // Product info
        Container(
          padding: const EdgeInsets.all(AppDimensions.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProductStat(label: 'Interest Rate', value: '${rate}% p.a.'),
              _ProductStat(label: 'Max Amount', value: 'NPR ${(maxAmount / 100000).toStringAsFixed(0)}L'),
              _ProductStat(label: 'Max Tenure', value: '60 months'),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        AppTextField(
          controller: _amountCtrl,
          label: 'Loan Amount (NPR) *',
          hint: '0.00',
          prefixIcon: Icons.currency_rupee_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v?.isEmpty == true) return 'Amount required';
            final amt = int.tryParse(v!) ?? 0;
            if (amt < 10000) return 'Minimum NPR 10,000';
            if (amt > maxAmount) return 'Maximum NPR ${maxAmount.toString()}';
            return null;
          },
          onChanged: (v) => setState(() => _emiCalculated = false),
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _purposeCtrl,
          label: 'Loan Purpose *',
          hint: 'e.g., Business expansion, home renovation...',
          maxLines: 2,
          validator: (v) => v?.isEmpty == true ? 'Purpose required' : null,
        ),
        const SizedBox(height: AppDimensions.sm),
        // Tenure
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tenure (months) *', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimensions.xs),
            Wrap(
              spacing: AppDimensions.xs,
              runSpacing: AppDimensions.xs,
              children: _tenures.map((t) {
                final selected = _selectedTenure == t;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedTenure = t;
                    _emiCalculated = false;
                  }),
                  child: Container(
                    width: 52,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(
                        color: selected ? AppColors.primary : const Color(0xFFE0E7EF),
                      ),
                    ),
                    child: Center(
                      child: Text('$t',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: selected ? Colors.white : AppColors.textPrimary,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        AppButton(
          label: 'Calculate EMI',
          onPressed: _calculateEmi,
          variant: ButtonVariant.outlined,
          icon: Icons.calculate_rounded,
        ),
        if (_emiCalculated) ...[
          const SizedBox(height: AppDimensions.md),
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.secondary.withOpacity(0.1), AppColors.secondary.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text('EMI Calculation Result', style: AppTextStyles.titleSmall),
                const SizedBox(height: AppDimensions.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _EmiStat(label: 'Monthly EMI', value: 'NPR ${_calculatedEmi.toStringAsFixed(0)}'),
                    _EmiStat(label: 'Total Interest', value: 'NPR ${_totalInterest.toStringAsFixed(0)}'),
                    _EmiStat(label: 'Total Payable', value: 'NPR ${(_calculatedEmi * _selectedTenure).toStringAsFixed(0)}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSecurityStep() {
    return Column(
      key: const ValueKey('security'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security & Guarantors', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        AppTextField(
          controller: _guarantorCtrl,
          label: 'Guarantor Name / Code',
          hint: 'Search guarantor...',
          prefixIcon: Icons.person_search_rounded,
        ),
        const SizedBox(height: AppDimensions.sm),
        Text('Collateral', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.sm),
        _CollateralTypeSelector(),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _collateralCtrl,
          label: 'Collateral Description',
          hint: 'e.g., Land at Kathmandu Ward-5',
          maxLines: 2,
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _collateralValueCtrl,
          label: 'Estimated Value (NPR)',
          hint: '0',
          prefixIcon: Icons.currency_rupee_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      key: const ValueKey('review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & Submit', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        _ReviewSection(title: 'Member', rows: [
          'Ram Bahadur Shrestha',
          widget.memberId ?? '—',
          'KYC Verified',
        ]),
        const SizedBox(height: AppDimensions.sm),
        _ReviewSection(title: 'Loan Details', rows: [
          'Product: $_selectedProduct',
          'Amount: NPR ${_amountCtrl.text}',
          'Tenure: $_selectedTenure months',
          'Rate: ${_productRates[_selectedProduct]}% p.a.',
          if (_emiCalculated) 'EMI: NPR ${_calculatedEmi.toStringAsFixed(0)}',
        ]),
        const SizedBox(height: AppDimensions.sm),
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.07),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 6),
                  Text('Submission Note', style: AppTextStyles.titleSmall.copyWith(color: AppColors.warning)),
                ],
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'This application will be sent to the Branch Manager for review. '
                'After manager approval, the loan will be disbursed via cash counter.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: AppButton(
                label: 'Back',
                onPressed: () => setState(() => _currentStep--),
                variant: ButtonVariant.outlined,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              label: _currentStep == 3 ? 'Submit Application' : 'Next',
              onPressed: () {
                if (_currentStep < 3) {
                  setState(() => _currentStep++);
                } else {
                  _submitApplication();
                }
              },
              isLoading: _isLoading,
              icon: _currentStep == 3 ? Icons.send_rounded : Icons.arrow_forward_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _Check {
  final String label;
  final bool passed;
  const _Check({required this.label, required this.passed});
}

class _EligibilityCard extends StatelessWidget {
  final List<_Check> checks;
  const _EligibilityCard({required this.checks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Eligibility Check', style: AppTextStyles.titleSmall),
          const SizedBox(height: AppDimensions.sm),
          ...checks.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      c.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: c.passed ? AppColors.secondary : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(c.label, style: AppTextStyles.bodySmall),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ProductStat extends StatelessWidget {
  final String label, value;
  const _ProductStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.titleSmall),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _EmiStat extends StatelessWidget {
  final String label, value;
  const _EmiStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.amountSmall.copyWith(color: AppColors.secondary)),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _CollateralTypeSelector extends StatefulWidget {
  @override
  State<_CollateralTypeSelector> createState() => _CollateralTypeSelectorState();
}

class _CollateralTypeSelectorState extends State<_CollateralTypeSelector> {
  String _selected = 'Land';
  final _types = ['Land', 'Gold', 'Vehicle', 'Building', 'FD'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.xs,
      children: _types.map((t) {
        final sel = _selected == t;
        return ChoiceChip(
          label: Text(t),
          selected: sel,
          onSelected: (_) => setState(() => _selected = t),
          selectedColor: AppColors.primary,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: sel ? Colors.white : AppColors.textPrimary,
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final List<String> rows;
  const _ReviewSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleSmall),
          const SizedBox(height: AppDimensions.xs),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(r, style: AppTextStyles.bodySmall),
              )),
        ],
      ),
    );
  }
}

extension _NumPow on double {
  double pow(int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= this;
    }
    return result;
  }
}
