import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class SavingAccountDetail {
  final String id, accountNumber, memberName, memberId;
  final String accountType, schemeName, schemeCode, status, branch;
  final double balance, interestRate, minimumBalance, totalDeposits,
      totalWithdrawals, totalInterest;
  final double? minimumDeposit;
  final bool withdrawalAllowed;
  final String openDate;

  SavingAccountDetail({
    required this.id, required this.accountNumber, required this.memberName,
    required this.memberId, required this.accountType, required this.schemeName,
    required this.schemeCode, required this.status, required this.branch,
    required this.balance, required this.interestRate, required this.minimumBalance,
    required this.totalDeposits, required this.totalWithdrawals,
    required this.totalInterest, this.minimumDeposit, required this.withdrawalAllowed,
    required this.openDate,
  });

  factory SavingAccountDetail.fromJson(Map<String, dynamic> j) => SavingAccountDetail(
    id: j['id'] as String? ?? '',
    accountNumber: j['accountNumber'] as String? ?? '',
    memberName: j['memberName'] as String? ?? '',
    memberId: j['memberId'] as String? ?? '',
    accountType: j['accountType'] as String? ?? 'Regular',
    schemeName: j['schemeName'] as String? ?? '',
    schemeCode: j['schemeCode'] as String? ?? '',
    status: j['status'] as String? ?? 'Active',
    branch: j['branch'] as String? ?? 'Head Office',
    balance: (j['balance'] as num?)?.toDouble() ?? 0,
    interestRate: (j['interestRate'] as num?)?.toDouble() ?? 0,
    minimumBalance: (j['minimumBalance'] as num?)?.toDouble() ?? 0,
    minimumDeposit: (j['minimumDeposit'] as num?)?.toDouble(),
    withdrawalAllowed: j['withdrawalAllowed'] as bool? ?? true,
    openDate: j['openDate'] as String? ?? '',
    totalDeposits: (j['totalDeposits'] as num?)?.toDouble() ?? 0,
    totalWithdrawals: (j['totalWithdrawals'] as num?)?.toDouble() ?? 0,
    totalInterest: (j['totalInterest'] as num?)?.toDouble() ?? 0,
  );
}

class SavingTxnItem {
  final String id, receiptNumber, transactionType, mode;
  final double amount, balanceAfter;
  final String? narration;
  final DateTime transactionDate;

  SavingTxnItem({
    required this.id, required this.receiptNumber, required this.transactionType,
    required this.mode, required this.amount, required this.balanceAfter,
    this.narration, required this.transactionDate,
  });

  factory SavingTxnItem.fromJson(Map<String, dynamic> j) => SavingTxnItem(
    id: j['id'] as String? ?? '',
    receiptNumber: j['receiptNumber'] as String? ?? '',
    transactionType: j['transactionType'] as String? ?? '',
    mode: j['mode'] as String? ?? 'Cash',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    balanceAfter: (j['balanceAfter'] as num?)?.toDouble() ?? 0,
    narration: j['narration'] as String?,
    transactionDate: DateTime.tryParse(j['transactionDate'] as String? ?? '') ?? DateTime.now(),
  );

  bool get isCredit => transactionType != 'Withdrawal';
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _accountDetailProvider = FutureProvider.autoDispose
    .family<SavingAccountDetail, String>((ref, accountId) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/savings/accounts/$accountId');
  final envelope = res.data as Map<String, dynamic>;
  final data = envelope['data'] as Map<String, dynamic>? ?? envelope;
  return SavingAccountDetail.fromJson(data);
});

class _TxnState {
  final List<SavingTxnItem> items;
  final bool isLoading;
  final String? error;
  const _TxnState({this.items = const [], this.isLoading = false, this.error});
}

class _TxnNotifier extends StateNotifier<_TxnState> {
  final dynamic _dio;
  final String _accountId;
  _TxnNotifier(this._dio, this._accountId) : super(const _TxnState()) {
    load();
  }

  Future<void> load() async {
    state = const _TxnState(isLoading: true);
    try {
      final res = await _dio.get(
          '/api/v1/savings/accounts/$_accountId/transactions',
          queryParameters: {'pageSize': 50});
      final envelope = res.data as Map<String, dynamic>;
      final raw = (envelope['data'] as List<dynamic>? ?? []);
      final items = raw
          .map((e) => SavingTxnItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = _TxnState(items: items);
    } catch (e) {
      state = _TxnState(error: e.toString());
    }
  }
}

final _txnProvider = StateNotifierProvider.autoDispose
    .family<_TxnNotifier, _TxnState, String>((ref, accountId) {
  return _TxnNotifier(ref.watch(dioProvider), accountId);
});

// ── Page ──────────────────────────────────────────────────────────────────────

class SavingsDetailPage extends ConsumerStatefulWidget {
  final String accountId;
  const SavingsDetailPage({super.key, required this.accountId});

  @override
  ConsumerState<SavingsDetailPage> createState() => _SavingsDetailPageState();
}

class _SavingsDetailPageState extends ConsumerState<SavingsDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatAmount(double v) {
    final s = v.toStringAsFixed(2);
    // Indian grouping
    final parts = s.split('.');
    final buf = StringBuffer();
    final digits = parts[0];
    if (digits.length <= 3) {
      buf.write(digits);
    } else {
      final last3 = digits.substring(digits.length - 3);
      final rest = digits.substring(0, digits.length - 3);
      final groups = <String>[];
      for (var i = rest.length; i > 0; i -= 2) {
        groups.insert(0, rest.substring(i > 2 ? i - 2 : 0, i));
      }
      buf.write(groups.join(','));
      buf.write(',');
      buf.write(last3);
    }
    return 'NPR $buf.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_accountDetailProvider(widget.accountId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: detailAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Account Detail')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                const Text('Failed to load account', style: AppTextStyles.titleSmall),
                const SizedBox(height: 4),
                Text(e.toString(),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.invalidate(_accountDetailProvider(widget.accountId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (detail) => _buildScaffold(context, detail),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, SavingAccountDetail detail) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () {
                  ref.invalidate(_accountDetailProvider(widget.accountId));
                  ref.invalidate(_txnProvider(widget.accountId));
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.secondary, Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppDimensions.md, 56, AppDimensions.md, AppDimensions.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                              child: const Icon(Icons.savings_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${detail.schemeName} (${detail.accountType})',
                                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(detail.accountNumber,
                                      style: AppTextStyles.titleSmall.copyWith(color: Colors.white)),
                                ],
                              ),
                            ),
                            StatusBadge(status: detail.status, isLight: true),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.md),
                        Text(_formatAmount(detail.balance),
                            style: AppTextStyles.headlineLarge.copyWith(color: Colors.white)),
                        Text('Current Balance',
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.white60)),
                        Text(detail.memberName,
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.white54),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.secondary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.secondary,
                labelStyle: AppTextStyles.labelLarge,
                tabs: const [
                  Tab(text: 'Transactions'),
                  Tab(text: 'Details'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _TransactionsTab(accountId: widget.accountId),
            _DetailsTab(detail: detail),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Deposit',
                onPressed: () async {
                  await context.push(AppRoutes.deposit(widget.accountId));
                  // Refresh after returning
                  ref.invalidate(_accountDetailProvider(widget.accountId));
                  ref.invalidate(_txnProvider(widget.accountId));
                },
                icon: Icons.arrow_downward_rounded,
                variant: ButtonVariant.secondary,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: AppButton(
                label: 'Withdraw',
                onPressed: () async {
                  if (!detail.withdrawalAllowed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Early withdrawal from ${detail.accountType} accounts may incur penalties.',
                        ),
                        backgroundColor: AppColors.accent,
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'Proceed',
                          textColor: Colors.white,
                          onPressed: () async {
                            await context.push(AppRoutes.withdraw(widget.accountId));
                            ref.invalidate(_accountDetailProvider(widget.accountId));
                            ref.invalidate(_txnProvider(widget.accountId));
                          },
                        ),
                      ),
                    );
                    return;
                  }
                  await context.push(AppRoutes.withdraw(widget.accountId));
                  ref.invalidate(_accountDetailProvider(widget.accountId));
                  ref.invalidate(_txnProvider(widget.accountId));
                },
                icon: Icons.arrow_upward_rounded,
                variant: ButtonVariant.outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transactions Tab ──────────────────────────────────────────────────────────

class _TransactionsTab extends ConsumerWidget {
  final String accountId;
  const _TransactionsTab({required this.accountId});

  String _nepaliMonth(int m) =>
      ['Baisakh','Jestha','Ashad','Shrawan','Bhadra','Ashwin',
       'Kartik','Mangsir','Poush','Magh','Falgun','Chaitra'][m - 1];

  String _formatDate(DateTime dt) {
    // Display in local time
    final local = dt.toLocal();
    return '${local.day} ${_nepaliMonth(local.month)} ${local.year}';
  }

  String _formatAmount(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_txnProvider(accountId));

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 8),
            const Text('Failed to load transactions',
                style: AppTextStyles.titleSmall),
            const SizedBox(height: 4),
            Text(state.error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: () => ref.read(_txnProvider(accountId).notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const EmptyView(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        subtitle: 'Deposit to get started',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.xs),
      itemBuilder: (context, i) {
        final txn = state.items[i];
        return Container(
          padding: const EdgeInsets.all(AppDimensions.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: const Color(0xFFEEF2F7)),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: txn.isCredit
                      ? AppColors.secondary.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  txn.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: txn.isCredit ? AppColors.secondary : AppColors.error,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(txn.transactionType, style: AppTextStyles.bodyMedium),
                    Text(
                      '${_formatDate(txn.transactionDate)}  •  ${txn.mode}  •  ${txn.receiptNumber}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${txn.isCredit ? '+' : '-'} NPR ${_formatAmount(txn.amount)}',
                    style: AppTextStyles.amountSmall.copyWith(
                      color: txn.isCredit ? AppColors.creditAmount : AppColors.debitAmount,
                    ),
                  ),
                  Text(
                    'Bal: NPR ${_formatAmount(txn.balanceAfter)}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Details Tab ───────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final SavingAccountDetail detail;
  const _DetailsTab({required this.detail});

  String _fmtAmt(double v) => 'NPR ${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  /// Convert ISO date string "2026-06-23" → "23 June 2026"
  String _fmtDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        InfoSection(title: 'Account Information', rows: [
          InfoRow(label: 'Account Number', value: detail.accountNumber),
          InfoRow(label: 'Member', value: detail.memberName),
          InfoRow(label: 'Account Type', value: detail.accountType),
          InfoRow(label: 'Scheme', value: '${detail.schemeName} (${detail.schemeCode})'),
          InfoRow(label: 'Status', value: detail.status),
          InfoRow(label: 'Opened Date', value: _fmtDate(detail.openDate)),
          InfoRow(label: 'Branch', value: detail.branch),
        ]),
        const SizedBox(height: AppDimensions.md),
        InfoSection(title: 'Scheme Parameters', rows: [
          InfoRow(label: 'Interest Rate', value: '${detail.interestRate.toStringAsFixed(2)}% p.a.'),
          InfoRow(label: 'Minimum Balance', value: _fmtAmt(detail.minimumBalance)),
          if (detail.minimumDeposit != null)
            InfoRow(label: 'Minimum Deposit', value: _fmtAmt(detail.minimumDeposit!)),
          InfoRow(label: 'Withdrawal Allowed', value: detail.withdrawalAllowed ? 'Yes' : 'No'),
        ]),
        const SizedBox(height: AppDimensions.md),
        InfoSection(title: 'Statistics', rows: [
          InfoRow(label: 'Current Balance', value: _fmtAmt(detail.balance)),
          InfoRow(label: 'Total Deposits', value: _fmtAmt(detail.totalDeposits)),
          InfoRow(label: 'Total Withdrawals', value: _fmtAmt(detail.totalWithdrawals)),
          InfoRow(label: 'Total Interest Earned', value: _fmtAmt(detail.totalInterest)),
        ]),
      ],
    );
  }
}

// ── Tab bar delegate ──────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: AppColors.surface, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
