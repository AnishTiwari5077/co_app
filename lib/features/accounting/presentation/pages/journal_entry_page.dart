import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/common_widgets.dart';

class JournalEntryPage extends ConsumerStatefulWidget {
  const JournalEntryPage({super.key});

  @override
  ConsumerState<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends ConsumerState<JournalEntryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _narrationCtrl = TextEditingController();
  final _voucherDateCtrl = TextEditingController(text: '2081-03-15');
  String _selectedVoucherType = 'Journal';
  bool _isPosting = false;

  final _voucherTypes = ['Journal', 'Receipt', 'Payment', 'Contra'];
  final _entries = <_JournalLine>[];

  double get _totalDebit =>
      _entries.fold(0, (s, e) => s + (e.isDebit ? e.amount : 0));
  double get _totalCredit =>
      _entries.fold(0, (s, e) => s + (!e.isDebit ? e.amount : 0));
  bool get _isBalanced => (_totalDebit - _totalCredit).abs() < 0.01;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Add 2 default lines
    _entries.addAll([
      _JournalLine(account: '', isDebit: true, amount: 0),
      _JournalLine(account: '', isDebit: false, amount: 0),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _narrationCtrl.dispose();
    _voucherDateCtrl.dispose();
    super.dispose();
  }

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
            child: Text('Trial Balance', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
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
        // Voucher header
        _buildVoucherHeader(),
        const SizedBox(height: AppDimensions.md),
        // Entries
        _buildEntriesTable(),
        const SizedBox(height: AppDimensions.md),
        // Totals
        _buildTotals(),
        const SizedBox(height: AppDimensions.md),
        // Narration
        AppTextField(
          controller: _narrationCtrl,
          label: 'Narration *',
          hint: 'Being entry for...',
          maxLines: 2,
        ),
        const SizedBox(height: AppDimensions.lg),
        // Buttons
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Voucher Type', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedVoucherType,
                      onChanged: (v) => setState(() => _selectedVoucherType = v!),
                      decoration: const InputDecoration(isDense: true),
                      items: _voucherTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                      _entries.add(_JournalLine(account: '', isDebit: true, amount: 0))),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('Add Line', style: AppTextStyles.labelSmall),
                ),
              ],
            ),
          ),
          // Header
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.xs),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Account', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary))),
                Expanded(child: Text('Dr/Cr', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Amount', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.right)),
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
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.xs),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: entry.account,
              onChanged: (v) => entry.account = v,
              style: AppTextStyles.bodySmall,
              decoration: InputDecoration(
                hintText: 'Select account...',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => entry.isDebit = !entry.isDebit),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: entry.isDebit ? AppColors.error.withOpacity(0.1) : AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Center(
                  child: Text(
                    entry.isDebit ? 'Dr' : 'Cr',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: entry.isDebit ? AppColors.error : AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: entry.amount > 0 ? entry.amount.toStringAsFixed(0) : '',
              onChanged: (v) => setState(() => entry.amount = double.tryParse(v) ?? 0),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            color: AppColors.error,
            onPressed: _entries.length > 2
                ? () => setState(() => _entries.removeAt(index))
                : null,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: _isBalanced ? AppColors.secondary.withOpacity(0.05) : AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: _isBalanced ? AppColors.secondary.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('Total Debit', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              Text('NPR ${_totalDebit.toStringAsFixed(2)}', style: AppTextStyles.amountSmall.copyWith(color: AppColors.error)),
            ],
          ),
          Container(width: 1, height: 30, color: const Color(0xFFE8EDF3)),
          Column(
            children: [
              Text('Total Credit', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              Text('NPR ${_totalCredit.toStringAsFixed(2)}', style: AppTextStyles.amountSmall.copyWith(color: AppColors.secondary)),
            ],
          ),
          Container(width: 1, height: 30, color: const Color(0xFFE8EDF3)),
          Row(
            children: [
              Icon(
                _isBalanced ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: _isBalanced ? AppColors.secondary : AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                _isBalanced ? 'Balanced' : 'Diff: NPR ${(_totalDebit - _totalCredit).abs().toStringAsFixed(2)}',
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
    final vouchers = [
      _VoucherRow(no: 'JV-2081-00145', type: 'Journal', date: '15 Ashad 2081', amount: 'NPR 25,000', narration: 'Interest accrual for Ashad', status: 'Posted'),
      _VoucherRow(no: 'RV-2081-00089', type: 'Receipt', date: '15 Ashad 2081', amount: 'NPR 11,634', narration: 'EMI collection - Ram Shrestha', status: 'Posted'),
      _VoucherRow(no: 'PV-2081-00033', type: 'Payment', date: '14 Ashad 2081', amount: 'NPR 50,000', narration: 'Staff salary for Ashad', status: 'Draft'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: vouchers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) => _VoucherCard(voucher: vouchers[i]),
    );
  }

  Future<void> _postVoucher() async {
    setState(() => _isPosting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voucher JV-2081-00146 posted successfully', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }
}

class _JournalLine {
  String account;
  bool isDebit;
  double amount;
  _JournalLine({required this.account, required this.isDebit, required this.amount});
}

class _VoucherRow {
  final String no, type, date, amount, narration, status;
  const _VoucherRow({required this.no, required this.type, required this.date, required this.amount, required this.narration, required this.status});
}

class _VoucherCard extends StatelessWidget {
  final _VoucherRow voucher;
  const _VoucherCard({required this.voucher});

  @override
  Widget build(BuildContext context) {
    final isPosted = voucher.status == 'Posted';
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
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voucher.narration, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${voucher.no}  •  ${voucher.date}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(voucher.amount, style: AppTextStyles.labelLarge),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPosted ? AppColors.secondary.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(voucher.status,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isPosted ? AppColors.secondary : AppColors.warning,
                      fontSize: 10,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
