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
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../core/api/api_client.dart';

// ── Chart of Account model ────────────────────────────────────────────────────

class ChartOfAccountItem {
  final String id, accountCode, accountName, accountType, accountGroup;
  final double currentBalance;

  ChartOfAccountItem({
    required this.id,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.accountGroup,
    required this.currentBalance,
  });

  factory ChartOfAccountItem.fromJson(Map<String, dynamic> j) =>
      ChartOfAccountItem(
        id: j['id'] as String? ?? '',
        accountCode: j['accountCode'] as String? ?? '',
        accountName: j['accountName'] as String? ?? '',
        accountType: j['accountType'] as String? ?? '',
        accountGroup: j['accountGroup'] as String? ?? '',
        currentBalance: (j['currentBalance'] as num?)?.toDouble() ?? 0,
      );

  String get display => '${accountCode}  ${accountName}';
}

// ── Journal line model ────────────────────────────────────────────────────────

class _JournalLine {
  ChartOfAccountItem? account;
  bool isDebit;
  double amount;
  final TextEditingController amountCtrl;
  final TextEditingController searchCtrl;
  List<ChartOfAccountItem> suggestions = [];
  bool showSuggestions = false;
  bool searching = false;
  Timer? debounce;

  _JournalLine({this.account, required this.isDebit, this.amount = 0})
      : amountCtrl = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(0) : ''),
        searchCtrl = TextEditingController(text: account?.display ?? '');

  void dispose() {
    debounce?.cancel();
    amountCtrl.dispose();
    searchCtrl.dispose();
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class JournalEntryPage extends ConsumerStatefulWidget {
  const JournalEntryPage({super.key});

  @override
  ConsumerState<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends ConsumerState<JournalEntryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _narrationCtrl = TextEditingController();
  final _voucherDateCtrl = TextEditingController(
      text: _nepaliDateToday());
  String _selectedVoucherType = 'Journal';
  bool _isPosting = false;

  final _voucherTypes = ['Journal', 'Receipt', 'Payment', 'Contra'];
  final _entries = <_JournalLine>[];

  // Voucher list state
  List<Map<String, dynamic>> _vouchers = [];
  bool _loadingVouchers = false;

  static String _nepaliDateToday() {
    // Simple fallback — real NP date conversion would use a library
    final now = DateTime.now();
    return '${now.year - 57}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  double get _totalDebit =>
      _entries.fold(0, (s, e) => s + (e.isDebit ? e.amount : 0));
  double get _totalCredit =>
      _entries.fold(0, (s, e) => s + (!e.isDebit ? e.amount : 0));
  bool get _isBalanced => (_totalDebit - _totalCredit).abs() < 0.01 && _totalDebit > 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _vouchers.isEmpty) {
        _loadVouchers();
      }
    });
    _entries.addAll([
      _JournalLine(isDebit: true),
      _JournalLine(isDebit: false),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _narrationCtrl.dispose();
    _voucherDateCtrl.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Account search ────────────────────────────────────────────────────────

  void _onAccountSearch(_JournalLine line, String query) {
    line.debounce?.cancel();
    if (query.trim().length < 1) {
      setState(() {
        line.suggestions = [];
        line.showSuggestions = false;
      });
      return;
    }
    line.debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => line.searching = true);
      try {
        final dio = ref.read(dioProvider);
        final response = await dio.get(
          '/api/v1/accounting/chart-of-accounts',
          queryParameters: {'search': query.trim(), 'postableOnly': 'true'},
        );
        final envelope = response.data as Map<String, dynamic>;
        final raw = (envelope['data'] as List?) ?? [];
        final items = raw
            .map((e) => ChartOfAccountItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            line.suggestions = items;
            line.showSuggestions = true;
            line.searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => line.searching = false);
      }
    });
  }

  void _selectAccount(_JournalLine line, ChartOfAccountItem account) {
    setState(() {
      line.account = account;
      line.searchCtrl.text = account.display;
      line.suggestions = [];
      line.showSuggestions = false;
    });
  }

  // ── Load vouchers ─────────────────────────────────────────────────────────

  Future<void> _loadVouchers() async {
    setState(() => _loadingVouchers = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/v1/accounting/vouchers');
      final envelope = response.data as Map<String, dynamic>;
      final raw = (envelope['data'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _vouchers = raw.map((e) => e as Map<String, dynamic>).toList();
          _loadingVouchers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  // ── Post Voucher ──────────────────────────────────────────────────────────

  Future<void> _postVoucher() async {
    if (!_isBalanced) return;
    final narration = _narrationCtrl.text.trim();
    if (narration.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Narration is required'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isPosting = true);
    try {
      final dio = ref.read(dioProvider);
      // Parse date: YYYY-MM-DD
      final dateParts = _voucherDateCtrl.text.split('-');
      final today = DateOnly(
          int.tryParse(dateParts.elementAtOrNull(0) ?? '') ?? DateTime.now().year,
          int.tryParse(dateParts.elementAtOrNull(1) ?? '') ?? DateTime.now().month,
          int.tryParse(dateParts.elementAtOrNull(2) ?? '') ?? DateTime.now().day);

      final entries = _entries
          .where((e) => e.account != null && e.amount > 0)
          .map((e) => {
                'accountId': e.account!.id,
                'entryType': e.isDebit ? 'Debit' : 'Credit',
                'amount': e.amount,
                'narration': narration,
              })
          .toList();

      await dio.post('/api/v1/accounting/vouchers', data: {
        'voucherType': _selectedVoucherType,
        'voucherDate': '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        'narration': narration,
        'entries': entries,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Voucher posted successfully!',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
          backgroundColor: AppColors.secondary,
        ));
        // Reset form
        setState(() {
          _isPosting = false;
          _narrationCtrl.clear();
          for (final e in _entries) e.dispose();
          _entries.clear();
          _entries.addAll([
            _JournalLine(isDebit: true),
            _JournalLine(isDebit: false),
          ]);
          _vouchers = [];
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        final msg = (e.response?.data as Map<String, dynamic>?)?['message']
            as String? ?? e.message ?? 'Failed to post voucher';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg), backgroundColor: AppColors.error));
      }
    } catch (_) {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Accounting', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.go('/accounting/trial-balance'),
            child: Text('Trial Balance',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(text: 'Journal Entry'),
            Tab(text: 'Vouchers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJournalEntry(),
          _buildVoucherList(),
        ],
      ),
    );
  }

  Widget _buildJournalEntry() {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        _buildVoucherHeader(),
        const SizedBox(height: AppDimensions.md),
        _buildEntriesTable(),
        const SizedBox(height: AppDimensions.md),
        _buildTotals(),
        const SizedBox(height: AppDimensions.md),
        AppTextField(
          controller: _narrationCtrl,
          label: 'Narration *',
          hint: 'Being entry for...',
          maxLines: 2,
        ),
        const SizedBox(height: AppDimensions.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Save Draft',
                onPressed: () {},
                variant: ButtonVariant.outlined,
                icon: Icons.save_outlined,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Post Voucher',
                onPressed: _isBalanced ? _postVoucher : null,
                isLoading: _isPosting,
                icon: Icons.check_circle_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoucherHeader() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voucher Type',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedVoucherType,
                  onChanged: (v) => setState(() => _selectedVoucherType = v!),
                  decoration: const InputDecoration(isDense: true),
                  items: _voucherTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: AppTextField(
              controller: _voucherDateCtrl,
              label: 'Date (BS)',
              hint: 'YYYY-MM-DD',
              prefixIcon: Icons.calendar_today_outlined,
              keyboardType: TextInputType.datetime,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Journal Entries', style: AppTextStyles.titleSmall),
                TextButton.icon(
                  onPressed: () => setState(() =>
                      _entries.add(_JournalLine(isDebit: true))),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('Add Line', style: AppTextStyles.labelSmall),
                ),
              ],
            ),
          ),
          // Header row
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.xs),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Account',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Dr/Cr',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Amount',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.right)),
                const SizedBox(width: 32),
              ],
            ),
          ),
          ...List.generate(_entries.length, (i) => _buildEntryRow(i)),
        ],
      ),
    );
  }

  Widget _buildEntryRow(int index) {
    final entry = _entries[index];
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── Account search field ───────────────────────────────────
              Expanded(
                flex: 3,
                child: TextField(
                  controller: entry.searchCtrl,
                  onChanged: (v) {
                    if (entry.account != null) {
                      setState(() => entry.account = null);
                    }
                    _onAccountSearch(entry, v);
                  },
                  style: AppTextStyles.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Search account...',
                    hintStyle: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    prefixIcon: entry.searching
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5)))
                        : entry.account != null
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.secondary, size: 16)
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // ── Dr/Cr toggle ───────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => entry.isDebit = !entry.isDebit),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: entry.isDebit
                          ? AppColors.error.withOpacity(0.1)
                          : AppColors.secondary.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Center(
                      child: Text(
                        entry.isDebit ? 'Dr' : 'Cr',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: entry.isDebit
                              ? AppColors.error
                              : AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // ── Amount field ───────────────────────────────────────────
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: entry.amountCtrl,
                  onChanged: (v) =>
                      setState(() => entry.amount = double.tryParse(v) ?? 0),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: '0',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.remove_circle_outline_rounded, size: 18),
                color: AppColors.error,
                onPressed: _entries.length > 2
                    ? () => setState(() {
                          _entries[index].dispose();
                          _entries.removeAt(index);
                        })
                    : null,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          // ── Suggestions dropdown ───────────────────────────────────────
          if (entry.showSuggestions && entry.suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 4),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: const Color(0xFFE0E7EF)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: entry.suggestions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 12),
                itemBuilder: (ctx, i) {
                  final acc = entry.suggestions[i];
                  return ListTile(
                    dense: true,
                    onTap: () => _selectAccount(entry, acc),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _typeColor(acc.accountType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(acc.accountType[0],
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _typeColor(acc.accountType),
                            fontSize: 10,
                          )),
                    ),
                    title: Text(acc.accountName,
                        style: AppTextStyles.bodySmall),
                    subtitle: Text(acc.accountCode,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    trailing: Text(
                        'NPR ${acc.currentBalance.toStringAsFixed(0)}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
          if (entry.showSuggestions &&
              entry.suggestions.isEmpty &&
              !entry.searching)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4, left: 8),
              child: Text('No accounts found',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Asset':
        return AppColors.primary;
      case 'Liability':
        return AppColors.error;
      case 'Equity':
        return const Color(0xFF7C3AED);
      case 'Income':
        return AppColors.secondary;
      case 'Expense':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildTotals() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: _isBalanced
            ? AppColors.secondary.withOpacity(0.05)
            : AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: _isBalanced
              ? AppColors.secondary.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('Total Debit',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              Text('NPR ${_totalDebit.toStringAsFixed(2)}',
                  style: AppTextStyles.amountSmall
                      .copyWith(color: AppColors.error)),
            ],
          ),
          Container(width: 1, height: 30, color: const Color(0xFFE8EDF3)),
          Column(
            children: [
              Text('Total Credit',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              Text('NPR ${_totalCredit.toStringAsFixed(2)}',
                  style: AppTextStyles.amountSmall
                      .copyWith(color: AppColors.secondary)),
            ],
          ),
          Container(width: 1, height: 30, color: const Color(0xFFE8EDF3)),
          Row(
            children: [
              Icon(
                _isBalanced
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: _isBalanced ? AppColors.secondary : AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                _isBalanced
                    ? 'Balanced'
                    : 'Diff: NPR ${(_totalDebit - _totalCredit).abs().toStringAsFixed(2)}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: _isBalanced ? AppColors.secondary : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherList() {
    if (_loadingVouchers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 56, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: AppDimensions.sm),
            Text('No vouchers yet',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimensions.xs),
            Text('Post your first journal entry',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: _vouchers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) {
        final v = _vouchers[i];
        final status = v['status'] as String? ?? 'Draft';
        final isPosted = status == 'Posted';
        return Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: const Color(0xFFE8EDF3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v['narration'] as String? ?? '—',
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        '${v['voucherNumber'] ?? '—'}  •  ${v['voucherDate'] ?? '—'}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPosted
                      ? AppColors.secondary.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(status,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isPosted ? AppColors.secondary : AppColors.warning,
                      fontSize: 10,
                    )),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Tiny helper to hold date parts for posting
class DateOnly {
  final int year, month, day;
  const DateOnly(this.year, this.month, this.day);
}
