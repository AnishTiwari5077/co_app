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
import '../../../../core/widgets/main_shell.dart';
import 'voucher_pdf_generator.dart';
import 'ledger_page.dart';

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

  String get display => '$accountCode  $accountName';
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
  bool loaded = false; // guard: only load-all once on first tap
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
    // Bikram Sambat ≈ AD + 57 (varies by month; correct for Jan–Jul)
    final now = DateTime.now();
    return '${now.year + 57}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  double get _totalDebit =>
      _entries.fold(0, (s, e) => s + (e.isDebit ? e.amount : 0));
  double get _totalCredit =>
      _entries.fold(0, (s, e) => s + (!e.isDebit ? e.amount : 0));
  bool get _isBalanced => (_totalDebit - _totalCredit).abs() < 0.01 && _totalDebit > 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    // Empty query = load ALL accounts (show on tap)
    line.debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => line.searching = true);
      try {
        final dio = ref.read(dioProvider);
        final params = <String, dynamic>{'postableOnly': 'true'};
        if (query.trim().isNotEmpty) params['search'] = query.trim();
        final response = await dio.get(
          '/api/v1/accounting/chart-of-accounts',
          queryParameters: params,
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
            line.loaded = true; // prevent repeated load-all calls
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

    // Validate: every line that has an amount must have an account
    final linesWithAmount = _entries.where((e) => e.amount > 0).toList();
    final missingAccount = linesWithAmount.where((e) => e.account == null).toList();
    if (missingAccount.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${missingAccount.length} line(s) have an amount but no account selected. '
          'Please select an account for every entry.',
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    if (linesWithAmount.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A voucher needs at least one Debit and one Credit line.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isPosting = true);
    try {
      final dio = ref.read(dioProvider);
      // Parse date string directly — format is YYYY-MM-DD (BS date stored as-is)
      final dateParts = _voucherDateCtrl.text.trim().split('-');
      final y = dateParts.elementAtOrNull(0) ?? '${DateTime.now().year + 57}';
      final m = (dateParts.elementAtOrNull(1) ?? '${DateTime.now().month}').padLeft(2, '0');
      final d = (dateParts.elementAtOrNull(2) ?? '${DateTime.now().day}').padLeft(2, '0');
      final voucherDateStr = '$y-$m-$d';

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
        'voucherDate': voucherDateStr,
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
          for (final e in _entries) {
            e.dispose();
          }
          _entries.clear();
          _entries.addAll([
            _JournalLine(isDebit: true),
            _JournalLine(isDebit: false),
          ]);
          _vouchers = [];
        });
        _loadVouchers();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        // ApiResponse envelope: { "error": { "message": "..." } }
        final data = e.response?.data as Map<String, dynamic>?;
        final msg = (data?['error'] as Map<String, dynamic>?)?['message'] as String?
            ?? data?['message'] as String?
            ?? e.message
            ?? 'Failed to post voucher';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg), backgroundColor: AppColors.error));
      }
    } catch (_) {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // ── Save Draft ────────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    final narration = _narrationCtrl.text.trim();
    if (narration.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Narration is required even for drafts'),
          backgroundColor: AppColors.error));
      return;
    }
    final linesWithData = _entries.where((e) => e.account != null && e.amount > 0).toList();
    if (linesWithData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one account entry to save as draft'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isPosting = true);
    try {
      final dio = ref.read(dioProvider);
      final dateParts = _voucherDateCtrl.text.trim().split('-');
      final y = dateParts.elementAtOrNull(0) ?? '${DateTime.now().year + 57}';
      final m = (dateParts.elementAtOrNull(1) ?? '${DateTime.now().month}').padLeft(2, '0');
      final d = (dateParts.elementAtOrNull(2) ?? '${DateTime.now().day}').padLeft(2, '0');

      await dio.post('/api/v1/accounting/vouchers', data: {
        'voucherType': _selectedVoucherType,
        'voucherDate': '$y-$m-$d',
        'narration': narration,
        'saveAsDraft': true,
        'entries': linesWithData
            .map((e) => {
                  'accountId': e.account!.id,
                  'entryType': e.isDebit ? 'Debit' : 'Credit',
                  'amount': e.amount,
                  'narration': narration,
                })
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Draft saved!',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
          backgroundColor: AppColors.warning,
        ));
        setState(() {
          _isPosting = false;
          _narrationCtrl.clear();
          for (final e in _entries) {
            e.dispose();
          }
          _entries.clear();
          _entries.addAll([_JournalLine(isDebit: true), _JournalLine(isDebit: false)]);
          _vouchers = [];
        });
        _loadVouchers();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        final data = e.response?.data as Map<String, dynamic>?;
        final msg = (data?['error'] as Map<String, dynamic>?)?['message'] as String?
            ?? e.message ?? 'Failed to save draft';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error));
      }
    } catch (_) {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // ── Delete Voucher ──────────────────────────────────────────────────────────

  Future<void> _deleteVoucher(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Voucher', style: AppTextStyles.titleMedium),
        content: const Text('Are you sure you want to delete this voucher? This will reverse any posted entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/api/v1/accounting/vouchers/$id');
      if (mounted) {
        Navigator.pop(context); // Close the detail sheet
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Voucher deleted successfully.', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
          backgroundColor: AppColors.secondary,
        ));
        _loadVouchers();
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data as Map<String, dynamic>?;
        final msg = (data?['error'] as Map<String, dynamic>?)?['message'] as String? ?? e.message ?? 'Failed to delete voucher';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
      }
    }
  }

  // ── Voucher Detail Sheet ──────────────────────────────────────────────────

  void _showVoucherDetail(Map<String, dynamic> v) {
    final entries = (v['entries'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    final status = v['status'] as String? ?? 'Draft';
    final isPosted = status == 'Posted';
    final totalDebit = entries
        .where((e) => e['entryType'] == 'Debit')
        .fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    final totalCredit = entries
        .where((e) => e['entryType'] == 'Credit')
        .fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v['voucherNumber'] as String? ?? '—',
                              style: AppTextStyles.titleMedium),
                          Text('${v['voucherType'] ?? ''}  •  ${v['voucherDate'] ?? ''}',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPosted
                            ? AppColors.secondary.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status,
                          style: AppTextStyles.labelSmall.copyWith(
                              color: isPosted ? AppColors.secondary : AppColors.warning,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      onPressed: () => _deleteVoucher(v['id'] as String),
                      tooltip: 'Delete Voucher',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Narration
              if ((v['narration'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.notes_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(v['narration'] as String,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
                    ],
                  ),
                ),
              // Entries table header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text('Account',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary))),
                    SizedBox(width: 50, child: Text('Type',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center)),
                    SizedBox(width: 90, child: Text('Amount',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              // Entries
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final isDebit = e['entryType'] == 'Debit';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e['accountName'] as String? ?? '—',
                                    style: AppTextStyles.bodySmall,
                                    overflow: TextOverflow.ellipsis),
                                Text(e['accountCode'] as String? ?? '',
                                    style: AppTextStyles.labelSmall
                                        .copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDebit
                                      ? AppColors.error.withValues(alpha: 0.1)
                                      : AppColors.secondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(isDebit ? 'Dr' : 'Cr',
                                    style: AppTextStyles.labelSmall.copyWith(
                                        color: isDebit ? AppColors.error : AppColors.secondary,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              'NPR ${((e['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: isDebit ? AppColors.error : AppColors.secondary,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Totals
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Total Debit',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        Text('NPR ${totalDebit.toStringAsFixed(2)}',
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Total Credit',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        Text('NPR ${totalCredit.toStringAsFixed(2)}',
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.secondary)),
                      ],
                    ),
                  ],
                ),
              ),
              // Download / Print button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => VoucherPdfGenerator.previewAndPrint(context, v),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download / Print PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Accounting', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.push('/accounting/chart-of-accounts'),
            child: Text('Accounts',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.secondary)),
          ),
          TextButton(
            onPressed: () => context.push('/accounting/fiscal-years'),
            child: Text('Fiscal Years',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
          ),
          const AppBarUserBadge(),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelLarge,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Journal Entry'),
            Tab(text: 'Vouchers'),
            Tab(text: 'Ledger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJournalEntry(),
          _buildVoucherList(),
          const LedgerPage(embedded: true),
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
                onPressed: _isPosting ? null : _saveDraft,
                variant: ButtonVariant.outlined,
                icon: Icons.save_outlined,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Post Voucher',
                onPressed: (_isBalanced && !_isPosting) ? _postVoucher : null,
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
                  initialValue: _selectedVoucherType,
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
                const Text('Journal Entries', style: AppTextStyles.titleSmall),
                TextButton.icon(
                  onPressed: () => setState(() =>
                      _entries.add(_JournalLine(isDebit: true))),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Line', style: AppTextStyles.labelSmall),
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
                  onTap: () {
                    if (!entry.loaded) {
                      // First tap: load all accounts
                      _onAccountSearch(entry, '');
                    } else {
                      setState(() => entry.showSuggestions = true);
                    }
                  },
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
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.secondary.withValues(alpha: 0.1),
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
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: Material(
                  color: AppColors.surface,
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
                            color: _typeColor(acc.accountType).withValues(alpha: 0.1),
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
            ? AppColors.secondary.withValues(alpha: 0.05)
            : AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: _isBalanced
              ? AppColors.secondary.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
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
                size: 56, color: AppColors.textSecondary.withValues(alpha: 0.3)),
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
        return GestureDetector(
          onTap: () => _showVoucherDetail(v),
          child: Container(
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
                  color: AppColors.primary.withValues(alpha: 0.1),
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
                      ? AppColors.secondary.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
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
        ), // Container
        ); // GestureDetector
      },
    );
  }
}

// Tiny helper to hold date parts for posting
class DateOnly {
  final int year, month, day;
  const DateOnly(this.year, this.month, this.day);
}
