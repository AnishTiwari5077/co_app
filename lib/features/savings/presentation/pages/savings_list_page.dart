import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/main_shell.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class SavingAccountItem {
  final String id, accountNumber, memberName, accountType, status;
  final double balance;
  final String? lastTransactionDate;

  SavingAccountItem({
    required this.id, required this.accountNumber, required this.memberName,
    required this.accountType, required this.balance,
    required this.status, this.lastTransactionDate,
  });

  factory SavingAccountItem.fromJson(Map<String, dynamic> j) => SavingAccountItem(
    id: j['id'] as String? ?? '',
    accountNumber: j['accountNumber'] as String? ?? '',
    memberName: j['memberName'] as String? ?? '',
    accountType: j['accountType'] as String? ?? 'Regular',
    balance: (j['balance'] as num?)?.toDouble() ?? 0,
    status: j['status'] as String? ?? 'Active',
    lastTransactionDate: j['lastTransactionDate'] as String?,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

class _SavingsState {
  final List<SavingAccountItem> items;
  final bool isLoading;
  final String? error;
  final int totalCount;
  final Map<String, dynamic>? summary;

  const _SavingsState({
    this.items = const [], this.isLoading = false,
    this.error, this.totalCount = 0, this.summary,
  });
  _SavingsState copyWith({List<SavingAccountItem>? items, bool? isLoading, String? error, int? totalCount, Map<String, dynamic>? summary}) =>
      _SavingsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        totalCount: totalCount ?? this.totalCount,
        summary: summary ?? this.summary,
      );
}

class _SavingsNotifier extends StateNotifier<_SavingsState> {
  final dynamic _dio;
  _SavingsNotifier(this._dio) : super(const _SavingsState()) {
    load();
  }

  Future<void> load({String? search, String? accountType}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/api/v1/savings/accounts', queryParameters: {
        'pageSize': 50,
        if (search != null && search.isNotEmpty) 'search': search,
        if (accountType != null) 'accountType': accountType,
      });
      final envelope = response.data as Map<String, dynamic>;
      final raw = (envelope['data'] as List<dynamic>? ?? []);
      final items = raw.map((e) => SavingAccountItem.fromJson(e as Map<String, dynamic>)).toList();
      final pagination = envelope['pagination'] as Map<String, dynamic>?;
      final totalCount = pagination?['totalCount'] as int? ?? items.length;
      final summary = envelope['summary'] as Map<String, dynamic>?;
      state = state.copyWith(isLoading: false, items: items, totalCount: totalCount, summary: summary);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final _savingsListProvider = StateNotifierProvider.autoDispose<_SavingsNotifier, _SavingsState>((ref) {
  return _SavingsNotifier(ref.watch(dioProvider));
});

// ── Page ──────────────────────────────────────────────────────────────────────

class SavingsListPage extends ConsumerStatefulWidget {
  const SavingsListPage({super.key});

  @override
  ConsumerState<SavingsListPage> createState() => _SavingsListPageState();
}

class _SavingsListPageState extends ConsumerState<SavingsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_savingsListProvider);
    final all = state.items;

    List<SavingAccountItem> filter(List<SavingAccountItem> src) {
      if (_query.isEmpty) return src;
      final q = _query.toLowerCase();
      return src.where((a) =>
        a.accountNumber.toLowerCase().contains(q) ||
        a.memberName.toLowerCase().contains(q)).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Savings', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await context.push('/savings/open');
              if (mounted) ref.read(_savingsListProvider.notifier).load();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Open Account'),
            style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
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
          tabs: const [
            Tab(text: 'All Accounts'),
            Tab(text: 'Regular'),
            Tab(text: 'Fixed Deposits'),
            Tab(text: 'Recurring'),
          ],
        ),
      ),
      body: state.isLoading && all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && all.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 48),
                      const SizedBox(height: AppDimensions.md),
                      const Text('Could not load savings', style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppDimensions.xs),
                      Text(state.error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppDimensions.md),
                      TextButton.icon(
                        onPressed: () => ref.read(_savingsListProvider.notifier).load(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildSummary(state),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(
                          AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search by account no. or member...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  })
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => ref.read(_savingsListProvider.notifier).load(),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList(filter(all)),
                            _buildList(filter(all.where((a) => a.accountType == 'Regular').toList())),
                            _buildList(filter(all.where((a) => a.accountType == 'FixedDeposit').toList())),
                            _buildList(filter(all.where((a) => a.accountType == 'RecurringDeposit').toList())),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await context.push('/savings/open');
        if (mounted) ref.read(_savingsListProvider.notifier).load();
      },
      backgroundColor: AppColors.secondary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Open Account'),
    ),
    );
  }

  Widget _buildSummary(_SavingsState state) {
    final summary = state.summary ?? {};
    final totalSavings = (summary['totalSavings'] as num?)?.toDouble() ?? 0.0;
    final activeCount = summary['activeAccounts'] ?? 0;
    final fdTotal = (summary['fdPortfolio'] as num?)?.toDouble() ?? 0.0;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          _SumCard(label: 'Total Savings', value: _fmt(totalSavings), color: AppColors.secondary),
          const SizedBox(width: AppDimensions.sm),
          _SumCard(label: 'Active Accounts', value: '$activeCount', color: AppColors.primary),
          const SizedBox(width: AppDimensions.sm),
          _SumCard(label: 'FD Portfolio', value: _fmt(fdTotal), color: AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildList(List<SavingAccountItem> accounts) {
    if (accounts.isEmpty) {
      return const EmptyView(
          icon: Icons.savings_outlined,
          title: 'No accounts found',
          subtitle: 'Try adjusting your search');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: accounts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) => _AccountCard(account: accounts[i]),
    );
  }

  String _fmt(double v) {
    if (v >= 10000000) return 'NPR ${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return 'NPR ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return 'NPR ${(v / 1000).toStringAsFixed(0)}K';
    return 'NPR ${v.toStringAsFixed(0)}';
  }
}

class _AccountCard extends StatelessWidget {
  final SavingAccountItem account;
  const _AccountCard({required this.account});

  Color get _typeColor {
    switch (account.accountType) {
      case 'FixedDeposit': return AppColors.accent;
      case 'RecurringDeposit': return const Color(0xFF7C3AED);
      default: return AppColors.secondary;
    }
  }

  IconData get _typeIcon {
    switch (account.accountType) {
      case 'FixedDeposit': return Icons.lock_clock_outlined;
      case 'RecurringDeposit': return Icons.repeat_rounded;
      default: return Icons.savings_rounded;
    }
  }

  String get _typeLabel {
    switch (account.accountType) {
      case 'FixedDeposit': return 'Fixed Deposit';
      case 'RecurringDeposit': return 'Recurring Deposit';
      default: return 'Regular Savings';
    }
  }

  String _fmtBalance(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    if (intPart.length <= 3) return 'NPR $s';
    final buf = StringBuffer('NPR ');
    for (int i = 0; i < intPart.length; i++) {
      if (i != 0 && (intPart.length - i) % 2 == 0 && intPart.length > 3) buf.write(',');
      buf.write(intPart[i]);
    }
    buf.write('.${parts[1]}');
    return buf.toString();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.savings}/${account.id}'),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 22),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.memberName,
                      style: AppTextStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Text(account.accountNumber,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                      Text(_typeLabel, style: AppTextStyles.bodySmall),
                    ],
                  ),
                  Text('Last: ${_fmtDate(account.lastTransactionDate)}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: account.status),
                const SizedBox(height: 4),
                Text(_fmtBalance(account.balance),
                    style: AppTextStyles.amountSmall
                        .copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: color, fontSize: 10)),
            Text(value, style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
