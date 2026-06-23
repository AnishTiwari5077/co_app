import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class AccountPickerItem {
  final String id, accountCode, accountName, accountType, accountGroup;
  final double currentBalance;
  const AccountPickerItem({
    required this.id, required this.accountCode, required this.accountName,
    required this.accountType, required this.accountGroup,
    required this.currentBalance,
  });
  factory AccountPickerItem.fromJson(Map<String, dynamic> j) =>
      AccountPickerItem(
        id: j['id'] as String? ?? '',
        accountCode: j['accountCode'] as String? ?? '',
        accountName: j['accountName'] as String? ?? '',
        accountType: j['accountType'] as String? ?? '',
        accountGroup: j['accountGroup'] as String? ?? '',
        currentBalance: (j['currentBalance'] as num?)?.toDouble() ?? 0,
      );
  String get display => '$accountCode  $accountName';
}

class LedgerEntry {
  final String voucherNumber, voucherType, entryType;
  final String voucherDate;
  final String? narration;
  final double amount, runningBalance;
  const LedgerEntry({
    required this.voucherNumber, required this.voucherType,
    required this.voucherDate, required this.entryType,
    this.narration, required this.amount, required this.runningBalance,
  });
  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
    voucherNumber: j['voucherNumber'] as String? ?? '',
    voucherType: j['voucherType'] as String? ?? '',
    voucherDate: j['voucherDate'] as String? ?? '',
    entryType: j['entryType'] as String? ?? '',
    narration: j['narration'] as String?,
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    runningBalance: (j['runningBalance'] as num?)?.toDouble() ?? 0,
  );
}

class LedgerData {
  final String accountCode, accountName, accountType;
  final double openingBalance, currentBalance, totalDebit, totalCredit;
  final List<LedgerEntry> entries;
  const LedgerData({
    required this.accountCode, required this.accountName,
    required this.accountType, required this.openingBalance,
    required this.currentBalance, required this.totalDebit,
    required this.totalCredit, required this.entries,
  });
  factory LedgerData.fromJson(Map<String, dynamic> j) => LedgerData(
    accountCode: j['accountCode'] as String? ?? '',
    accountName: j['accountName'] as String? ?? '',
    accountType: j['accountType'] as String? ?? '',
    openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0,
    currentBalance: (j['currentBalance'] as num?)?.toDouble() ?? 0,
    totalDebit: (j['totalDebit'] as num?)?.toDouble() ?? 0,
    totalCredit: (j['totalCredit'] as num?)?.toDouble() ?? 0,
    entries: (j['entries'] as List<dynamic>? ?? [])
        .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _ledgerProvider =
    FutureProvider.autoDispose.family<LedgerData, String>((ref, accountId) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/accounting/ledger/$accountId');
  final data =
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  return LedgerData.fromJson(data);
});

// ── Page ──────────────────────────────────────────────────────────────────────

class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  final _searchCtrl = TextEditingController();
  AccountPickerItem? _selectedAccount;
  List<AccountPickerItem> _suggestions = [];
  bool _searching = false;
  bool _showSuggestions = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().length < 1) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/api/v1/accounting/chart-of-accounts',
            queryParameters: {'search': query.trim(), 'postableOnly': 'false'});
        final raw =
            ((res.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? []);
        if (mounted) {
          setState(() {
            _suggestions = raw
                .map((e) =>
                    AccountPickerItem.fromJson(e as Map<String, dynamic>))
                .toList();
            _showSuggestions = true;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _selectAccount(AccountPickerItem a) {
    setState(() {
      _selectedAccount = a;
      _searchCtrl.text = a.display;
      _suggestions = [];
      _showSuggestions = false;
    });
  }

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
      body: Column(children: [
        // Account picker
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                labelText: 'Search Account',
                hintText: 'Type account code or name...',
                prefixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _selectedAccount = null;
                            _suggestions = [];
                            _showSuggestions = false;
                          });
                        })
                    : null,
              ),
            ),
            if (_showSuggestions && _suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: const Color(0xFFE0E7EF)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (ctx, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      dense: true,
                      onTap: () => _selectAccount(s),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.accountType,
                            style: AppTextStyles.labelSmall
                                .copyWith(
                                    color: AppColors.primary,
                                    fontSize: 9)),
                      ),
                      title: Text(s.accountName,
                          style: AppTextStyles.bodySmall),
                      subtitle: Text(s.accountCode,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11)),
                      trailing: Text(
                        _fmtAmt(s.currentBalance),
                        style: AppTextStyles.labelSmall.copyWith(
                            color: s.currentBalance >= 0
                                ? AppColors.creditAmount
                                : AppColors.debitAmount),
                      ),
                    );
                  },
                ),
              ),
          ]),
        ),

        // Ledger content
        Expanded(
          child: _selectedAccount == null
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: AppColors.textSecondary),
                        const SizedBox(height: AppDimensions.md),
                        Text('Search and select an account',
                            style: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: AppDimensions.xs),
                        Text('to view its ledger',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ]),
                )
              : _LedgerView(accountId: _selectedAccount!.id),
        ),
      ]),
    );
  }

  String _fmtAmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    final fmt = s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'NPR $fmt';
  }
}

// ── Ledger view ───────────────────────────────────────────────────────────────

class _LedgerView extends ConsumerWidget {
  final String accountId;
  const _LedgerView({required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(_ledgerProvider(accountId));
    return ledgerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 48),
          const SizedBox(height: AppDimensions.md),
          Text('Could not load ledger',
              style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.xs),
          Text(e.toString(),
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppDimensions.md),
          TextButton.icon(
            onPressed: () => ref.invalidate(_ledgerProvider(accountId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ]),
      ),
      data: (ledger) => Column(children: [
        // Account summary card
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: AppDimensions.sm),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${ledger.accountCode} — ${ledger.accountName}',
                    style: AppTextStyles.titleSmall),
                Text('${ledger.accountType}  •  Current Balance: ${_fmtAmt(ledger.currentBalance)}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Dr: ${_fmtK(ledger.totalDebit)}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.debitAmount)),
              Text('Cr: ${_fmtK(ledger.totalCredit)}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.creditAmount)),
            ]),
          ]),
        ),

        // Table header
        Container(
          color: AppColors.primary.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: AppDimensions.xs),
          child: Row(children: [
            Expanded(flex: 2,
                child: Text('Date',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.primary))),
            Expanded(flex: 4,
                child: Text('Narration',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.primary))),
            Expanded(child: Text('Debit',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.primary),
                textAlign: TextAlign.right)),
            Expanded(child: Text('Credit',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.primary),
                textAlign: TextAlign.right)),
            Expanded(child: Text('Balance',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.primary),
                textAlign: TextAlign.right)),
          ]),
        ),

        // Entries
        Expanded(
          child: ledger.entries.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: AppDimensions.sm),
                    Text('No transactions yet',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                  ]),
                )
              : ListView.separated(
                  itemCount: ledger.entries.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFEEF2F7)),
                  itemBuilder: (context, i) {
                    final e = ledger.entries[i];
                    final isDebit = e.entryType == 'Debit';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: AppDimensions.xs),
                      child: Row(children: [
                        Expanded(flex: 2,
                          child: Text(
                            e.voucherDate.length >= 10
                                ? e.voucherDate.substring(0, 10)
                                : e.voucherDate,
                            style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                          ),
                        ),
                        Expanded(flex: 4,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.narration ?? e.voucherType,
                                style: AppTextStyles.bodySmall,
                                overflow: TextOverflow.ellipsis),
                            Text(e.voucherNumber,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10)),
                          ]),
                        ),
                        Expanded(
                          child: Text(
                            isDebit ? _fmtK(e.amount) : '—',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: isDebit
                                    ? AppColors.debitAmount
                                    : AppColors.textSecondary),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            !isDebit ? _fmtK(e.amount) : '—',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: !isDebit
                                    ? AppColors.creditAmount
                                    : AppColors.textSecondary),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _fmtK(e.runningBalance.abs()),
                            style: AppTextStyles.labelSmall.copyWith(
                                color: e.runningBalance >= 0
                                    ? AppColors.textPrimary
                                    : AppColors.error),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  String _fmtAmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    final fmt = s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'NPR $fmt';
  }

  String _fmtK(double v) {
    if (v.abs() >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
