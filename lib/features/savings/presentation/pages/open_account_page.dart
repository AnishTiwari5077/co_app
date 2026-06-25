import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/repositories/member_repository.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class SavingScheme {
  final String id, schemeCode, schemeName, schemeType;
  final double interestRate, minimumBalance;
  final double? minimumDeposit;
  final int? minTenureMonths, maxTenureMonths;
  final bool withdrawalAllowed;

  SavingScheme({
    required this.id,
    required this.schemeCode,
    required this.schemeName,
    required this.schemeType,
    required this.interestRate,
    required this.minimumBalance,
    this.minimumDeposit,
    this.minTenureMonths,
    this.maxTenureMonths,
    required this.withdrawalAllowed,
  });

  factory SavingScheme.fromJson(Map<String, dynamic> j) => SavingScheme(
        id: j['id'] as String? ?? '',
        schemeCode: j['schemeCode'] as String? ?? '',
        schemeName: j['schemeName'] as String? ?? '',
        schemeType: j['schemeType'] as String? ?? 'Regular',
        interestRate: (j['interestRate'] as num?)?.toDouble() ?? 0,
        minimumBalance: (j['minimumBalance'] as num?)?.toDouble() ?? 0,
        minimumDeposit: (j['minimumDeposit'] as num?)?.toDouble(),
        minTenureMonths: j['minTenureMonths'] as int?,
        maxTenureMonths: j['maxTenureMonths'] as int?,
        withdrawalAllowed: j['withdrawalAllowed'] as bool? ?? true,
      );

  IconData get icon {
    switch (schemeType) {
      case 'FixedDeposit':
        return Icons.lock_clock_rounded;
      case 'RecurringDeposit':
        return Icons.repeat_rounded;
      default:
        return Icons.savings_rounded;
    }
  }

  Color get color {
    switch (schemeType) {
      case 'FixedDeposit':
        return AppColors.accent;
      case 'RecurringDeposit':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.secondary;
    }
  }

  String get typeLabel {
    switch (schemeType) {
      case 'FixedDeposit':
        return 'Fixed Deposit';
      case 'RecurringDeposit':
        return 'Recurring';
      default:
        return 'Regular';
    }
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class OpenAccountPage extends ConsumerStatefulWidget {
  const OpenAccountPage({super.key});

  @override
  ConsumerState<OpenAccountPage> createState() => _OpenAccountPageState();
}

class _OpenAccountPageState extends ConsumerState<OpenAccountPage> {
  // Step state
  int _step = 0; // 0 = Member, 1 = Scheme, 2 = Deposit

  // Member search
  final _memberSearchCtrl = TextEditingController();
  MemberListItem? _selectedMember;
  List<MemberListItem> _memberSuggestions = [];
  bool _searchingMembers = false;
  bool _showMemberSuggestions = false;
  Timer? _memberDebounce;

  // Scheme
  List<SavingScheme> _schemes = [];
  bool _loadingSchemes = false;
  SavingScheme? _selectedScheme;

  // Deposit
  final _amountCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController(); // optional custom account number
  String _depositMode = 'Cash';
  final _modes = ['Cash', 'Cheque', 'Bank Transfer', 'Online'];

  // Submission
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSchemes();
  }

  @override
  void dispose() {
    _memberDebounce?.cancel();
    _memberSearchCtrl.dispose();
    _amountCtrl.dispose();
    _accountNumberCtrl.dispose();
    super.dispose();
  }

  // ── Load schemes ──────────────────────────────────────────────────────────

  Future<void> _loadSchemes() async {
    setState(() => _loadingSchemes = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/v1/savings/schemes');
      final envelope = response.data as Map<String, dynamic>;
      final raw = (envelope['data'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _schemes =
              raw.map((e) => SavingScheme.fromJson(e as Map<String, dynamic>)).toList();
          _loadingSchemes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSchemes = false);
    }
  }

  // ── Member search ─────────────────────────────────────────────────────────

  void _onMemberSearch(String query) {
    _memberDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _memberSuggestions = [];
        _showMemberSuggestions = false;
      });
      return;
    }
    _memberDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searchingMembers = true);
      try {
        final repo = ref.read(memberRepositoryProvider);
        final result = await repo.getMembers(search: query.trim(), pageSize: 8);
        if (mounted) {
          setState(() {
            _memberSuggestions = result.data;
            _showMemberSuggestions = true;
            _searchingMembers = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searchingMembers = false);
      }
    });
  }

  void _selectMember(MemberListItem m) {
    setState(() {
      _selectedMember = m;
      _memberSearchCtrl.text = m.fullName;
      _showMemberSuggestions = false;
      _memberSuggestions = [];
    });
  }

  void _clearMember() {
    setState(() {
      _selectedMember = null;
      _memberSearchCtrl.clear();
      _memberSuggestions = [];
      _showMemberSuggestions = false;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final member = _selectedMember;
    final scheme = _selectedScheme;
    if (member == null || scheme == null) return;

    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final minDeposit = scheme.minimumDeposit ?? 0;
    if (amount < minDeposit) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Minimum initial deposit is NPR ${minDeposit.toStringAsFixed(0)}'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final customNumber = _accountNumberCtrl.text.trim();
      final response = await dio.post('/api/v1/savings/accounts', data: {
        'memberId': member.id,
        'schemeId': scheme.id,
        'initialDeposit': amount,
        'depositMode': _depositMode,
        if (customNumber.isNotEmpty) 'customAccountNumber': customNumber,
      });
      final envelope = response.data as Map<String, dynamic>;
      final data = (envelope['data'] as Map<String, dynamic>?) ?? {};
      final accountNumber = data['accountNumber'] as String? ?? '—';
      final balance = (data['balance'] as num?)?.toDouble() ?? amount;

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccess(accountNumber, balance);
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final msg = (e.response?.data as Map<String, dynamic>?)?['message']
                as String? ??
            'Failed to open account';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error));
      }
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccess(String accountNumber, double balance) {
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
                color: AppColors.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.savings_rounded,
                  color: AppColors.secondary, size: 40),
            ),
            const SizedBox(height: AppDimensions.md),
            const Text('Account Opened!', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text(accountNumber,
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.primary)),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Opening balance: NPR ${balance.toStringAsFixed(2)}',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),
            AppButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/savings');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Open Savings Account', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(child: _buildStepContent()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Member', 'Scheme', 'Deposit'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
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
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                )),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(steps[i],
                        style: AppTextStyles.bodySmall.copyWith(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight:
                                isActive ? FontWeight.w600 : null)),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(
                          bottom: 18, left: 4, right: 4),
                      color: isDone
                          ? AppColors.secondary
                          : AppColors.surfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: [
          _buildMemberStep(),
          _buildSchemeStep(),
          _buildDepositStep(),
        ][_step],
      ),
    );
  }

  // ── Step 1: Member ────────────────────────────────────────────────────────

  Widget _buildMemberStep() {
    return Column(
      key: const ValueKey('member'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Member', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),

        if (_selectedMember == null) ...[
          TextField(
            controller: _memberSearchCtrl,
            onChanged: _onMemberSearch,
            decoration: InputDecoration(
              labelText: 'Search Member',
              hintText: 'Type name, code or phone...',
              prefixIcon: _searchingMembers
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Icon(Icons.search_rounded),
              suffixIcon: _memberSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _clearMember)
                  : null,
            ),
          ),

          if (_showMemberSuggestions && _memberSuggestions.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(color: const Color(0xFFE0E7EF)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                child: Material(
                  color: AppColors.surface,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _memberSuggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (ctx, i) {
                      final m = _memberSuggestions[i];
                      final isActive = m.status == 'Active';
                      return ListTile(
                        onTap: () => _selectMember(m),
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.surfaceVariant,
                          child: Text(
                            m.fullName.isNotEmpty
                                ? m.fullName[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        title: Text(m.fullName, style: AppTextStyles.titleSmall),
                        subtitle: Text(
                          '${m.memberCode}  •  ${m.phone}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.secondary.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Text(m.status,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: isActive
                                    ? AppColors.secondary
                                    : AppColors.error,
                                fontSize: 10,
                              )),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          if (_showMemberSuggestions &&
              _memberSuggestions.isEmpty &&
              !_searchingMembers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
              child: Center(
                child: Text('No members found',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ),
            ),
        ] else ...[
          // Selected member card
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  radius: 24,
                  child: Text(
                    _selectedMember!.fullName.isNotEmpty
                        ? _selectedMember!.fullName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedMember!.fullName,
                          style: AppTextStyles.titleSmall),
                      Text(
                          '${_selectedMember!.memberCode}  •  ${_selectedMember!.phone}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.primary)),
                      Text('Status: ${_selectedMember!.status}',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: _clearMember,
                ),
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.secondary),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Step 2: Scheme ────────────────────────────────────────────────────────

  Widget _buildSchemeStep() {
    if (_loadingSchemes) {
      return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()));
    }

    if (_schemes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.savings_outlined,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: AppDimensions.sm),
            Text('No active schemes found',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimensions.xs),
            Text('Please add saving schemes in the admin panel.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey('scheme'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Savings Scheme', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        ..._schemes.map((scheme) {
          final isSelected = _selectedScheme?.id == scheme.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedScheme = scheme),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: AppDimensions.sm),
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.color.withValues(alpha: 0.06)
                    : AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: isSelected
                      ? scheme.color
                      : const Color(0xFFE8EDF3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.color.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Icon(scheme.icon, color: scheme.color, size: 24),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(scheme.schemeName,
                                style: AppTextStyles.titleSmall),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(scheme.typeLabel,
                                  style: AppTextStyles.labelSmall
                                      .copyWith(
                                          color: scheme.color,
                                          fontSize: 10)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${scheme.interestRate}% p.a.  •  Min bal: NPR ${scheme.minimumBalance.toStringAsFixed(0)}'
                          '${scheme.minimumDeposit != null ? '  •  Min deposit: NPR ${scheme.minimumDeposit!.toStringAsFixed(0)}' : ''}',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary),
                        ),
                        if (scheme.minTenureMonths != null)
                          Text(
                            'Tenure: ${scheme.minTenureMonths}–${scheme.maxTenureMonths ?? '∞'} months',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded,
                        color: scheme.color, size: 22),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Step 3: Deposit ───────────────────────────────────────────────────────

  Widget _buildDepositStep() {
    final scheme = _selectedScheme;
    final minDeposit = scheme?.minimumDeposit ?? 0;

    return Column(
      key: const ValueKey('deposit'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8)
              ],
            ),
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusXl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    radius: 20,
                    child: Text(
                      _selectedMember?.fullName.isNotEmpty == true
                          ? _selectedMember!.fullName[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.titleSmall
                          .copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedMember?.fullName ?? '—',
                            style: AppTextStyles.titleSmall
                                .copyWith(color: Colors.white)),
                        Text(_selectedMember?.memberCode ?? '—',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              const Divider(color: Colors.white24),
              const SizedBox(height: AppDimensions.xs),
              if (scheme != null)
                Row(
                  children: [
                    Icon(scheme.icon, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(scheme.schemeName,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white)),
                    const Spacer(),
                    Text('${scheme.interestRate}% p.a.',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: Colors.white)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.lg),

        const Text('Initial Deposit', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.sm),

        // Optional custom account number
        TextField(
          controller: _accountNumberCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Account Number (optional)',
            hintText: 'e.g. SAV-2083-00010  — leave blank to auto-generate',
            prefixIcon: Icon(Icons.tag_rounded),
            helperText: 'If left blank, the system will generate one automatically',
          ),
        ),
        const SizedBox(height: AppDimensions.md),

        TextFormField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: AppTextStyles.titleLarge,
          decoration: InputDecoration(
            labelText: 'Amount (NPR)',
            hintText: '0',

            helperText: minDeposit > 0
                ? 'Minimum: NPR ${minDeposit.toStringAsFixed(0)}'
                : null,
          ),
        ),
        const SizedBox(height: AppDimensions.md),

        // Quick amounts
        Row(
          children: [5000, 10000, 25000, 50000].map((amt) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _amountCtrl.text = amt.toString()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: const Color(0xFFE0E7EF)),
                    ),
                    child: Text('NPR ${amt ~/ 1000}K',
                        style: AppTextStyles.labelSmall,
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimensions.md),

        const Text('Deposit Mode', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppDimensions.xs),
        Wrap(
          spacing: AppDimensions.xs,
          runSpacing: AppDimensions.xs,
          children: _modes.map((m) {
            final sel = _depositMode == m;
            return GestureDetector(
              onTap: () => setState(() => _depositMode = m),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.sm),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                      color: sel
                          ? AppColors.primary
                          : const Color(0xFFE0E7EF)),
                ),
                child: Text(m,
                    style: AppTextStyles.labelLarge.copyWith(
                        color: sel
                            ? Colors.white
                            : AppColors.textPrimary)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLastStep = _step == 2;
    final canProceed = switch (_step) {
      0 => _selectedMember != null,
      1 => _selectedScheme != null,
      2 => (double.tryParse(_amountCtrl.text) ?? 0) > 0,
      _ => false,
    };

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: AppButton(
                label: 'Back',
                onPressed: () => setState(() => _step--),
                variant: ButtonVariant.outlined,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              label: isLastStep ? 'Open Account' : 'Next  →',
              onPressed: canProceed
                  ? () {
                      if (!isLastStep) {
                        setState(() => _step++);
                      } else {
                        _submit();
                      }
                    }
                  : null,
              isLoading: _isSubmitting,
              icon: isLastStep
                  ? Icons.savings_rounded
                  : Icons.arrow_forward_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
