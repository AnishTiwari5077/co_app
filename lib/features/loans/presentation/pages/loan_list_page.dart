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

// ── Model ─────────────────────────────────────────────────────────────────────

class LoanListItem {
  final String id, loanNumber, memberName, productName, status;
  final double appliedAmount, outstandingBalance, emiAmount;
  final String? nextEmiDate;
  final int overdueDays;

  LoanListItem({
    required this.id, required this.loanNumber, required this.memberName,
    required this.productName, required this.appliedAmount,
    required this.outstandingBalance, required this.emiAmount,
    required this.status, this.nextEmiDate, required this.overdueDays,
  });

  factory LoanListItem.fromJson(Map<String, dynamic> j) => LoanListItem(
    id: j['id'] as String? ?? '',
    loanNumber: j['loanNumber'] as String? ?? '',
    memberName: j['memberName'] as String? ?? '',
    productName: j['productName'] as String? ?? '',
    appliedAmount: (j['appliedAmount'] as num?)?.toDouble() ?? 0,
    outstandingBalance: (j['outstandingBalance'] as num?)?.toDouble() ?? 0,
    emiAmount: (j['emiAmount'] as num?)?.toDouble() ?? 0,
    status: j['status'] as String? ?? '',
    nextEmiDate: j['nextEmiDate'] as String?,
    overdueDays: j['overdueDays'] as int? ?? 0,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

class _LoanListState {
  final List<LoanListItem> items;
  final bool isLoading;
  final String? error;
  final int totalCount;
  const _LoanListState({
    this.items = const [], this.isLoading = false,
    this.error, this.totalCount = 0,
  });
  _LoanListState copyWith({List<LoanListItem>? items, bool? isLoading, String? error, int? totalCount}) =>
      _LoanListState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        totalCount: totalCount ?? this.totalCount,
      );
}

class _LoanListNotifier extends StateNotifier<_LoanListState> {
  final dynamic _dio;
  _LoanListNotifier(this._dio) : super(const _LoanListState()) {
    load();
  }

  Future<void> load({String? search, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/api/v1/loans', queryParameters: {
        'pageSize': 50,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status != 'All') 'status': status,
      });
      final envelope = response.data as Map<String, dynamic>;
      final raw = (envelope['data'] as List<dynamic>? ?? []);
      final items = raw.map((e) => LoanListItem.fromJson(e as Map<String, dynamic>)).toList();
      final pagination = envelope['pagination'] as Map<String, dynamic>?;
      final total = pagination?['totalCount'] as int? ?? items.length;
      state = state.copyWith(isLoading: false, items: items, totalCount: total);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final _loanListProvider = StateNotifierProvider.autoDispose<_LoanListNotifier, _LoanListState>((ref) {
  return _LoanListNotifier(ref.watch(dioProvider));
});

// ── Page ──────────────────────────────────────────────────────────────────────

class LoanListPage extends ConsumerStatefulWidget {
  const LoanListPage({super.key});

  @override
  ConsumerState<LoanListPage> createState() => _LoanListPageState();
}

class _LoanListPageState extends ConsumerState<LoanListPage>
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
    final loanState = ref.watch(_loanListProvider);
    final all = loanState.items;

    // Filter by search query client-side
    List<LoanListItem> filter(List<LoanListItem> src) {
      if (_query.isEmpty) return src;
      final q = _query.toLowerCase();
      return src.where((l) =>
        l.loanNumber.toLowerCase().contains(q) ||
        l.memberName.toLowerCase().contains(q)).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Loans', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelLarge,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Overdue'),
            Tab(text: 'Pending'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('${AppRoutes.loans}/apply');
          if (mounted) ref.read(_loanListProvider.notifier).load();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: Text('Apply Loan', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
      ),
      body: loanState.isLoading && all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : loanState.error != null && all.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 48),
                      const SizedBox(height: AppDimensions.md),
                      const Text('Could not load loans', style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppDimensions.xs),
                      Text(loanState.error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppDimensions.md),
                      TextButton.icon(
                        onPressed: () => ref.read(_loanListProvider.notifier).load(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildSummary(all),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(
                          AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search by loan no., member name...',
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
                        onRefresh: () => ref.read(_loanListProvider.notifier).load(),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList(filter(all)),
                            _buildList(filter(all.where((l) => l.status == 'Active').toList())),
                            _buildList(filter(all.where((l) => l.status == 'Overdue' || l.overdueDays > 0).toList())),
                            _buildList(filter(all.where((l) => l.status == 'Pending').toList())),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummary(List<LoanListItem> all) {
    final active = all.where((l) => l.status == 'Active').length;
    final overdue = all.where((l) => l.overdueDays > 0).length;
    final total = all.fold<double>(0, (s, l) => s + l.outstandingBalance);
    final npa = all.where((l) => l.status == 'NPA').length;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          _SummaryChip(label: 'Portfolio', value: _fmt(total), color: AppColors.primary),
          const SizedBox(width: AppDimensions.sm),
          _SummaryChip(label: 'Active', value: '$active', color: AppColors.secondary),
          const SizedBox(width: AppDimensions.sm),
          _SummaryChip(label: 'Overdue', value: '$overdue', color: AppColors.error),
          const SizedBox(width: AppDimensions.sm),
          _SummaryChip(label: 'NPA', value: '$npa', color: AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildList(List<LoanListItem> loans) {
    if (loans.isEmpty) {
      return const EmptyView(
          icon: Icons.account_balance_outlined,
          title: 'No loans found',
          subtitle: 'Try adjusting your search');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.md, AppDimensions.md, AppDimensions.xxl),
      itemCount: loans.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) => _LoanCard(loan: loans[i]),
    );
  }

  String _fmt(double v) {
    if (v >= 10000000) return 'NPR ${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return 'NPR ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return 'NPR ${(v / 1000).toStringAsFixed(0)}K';
    return 'NPR ${v.toStringAsFixed(0)}';
  }
}

class _LoanCard extends StatelessWidget {
  final LoanListItem loan;
  const _LoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final isOverdue = loan.overdueDays > 0;
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.loans}/${loan.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: isOverdue ? AppColors.error.withValues(alpha: 0.3) : const Color(0xFFE8EDF3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 20),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loan.memberName, style: AppTextStyles.titleSmall),
                      Text(loan.loanNumber,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
                StatusBadge(status: loan.status),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            const Divider(height: 1),
            const SizedBox(height: AppDimensions.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoPair(label: 'Type', value: loan.productName),
                _InfoPair(label: 'Amount', value: _fmtAmt(loan.appliedAmount)),
                _InfoPair(label: 'Outstanding', value: _fmtAmt(loan.outstandingBalance)),
              ],
            ),
            if (isOverdue) ...[
              const SizedBox(height: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${loan.overdueDays} days overdue  —  EMI ${_fmtAmt(loan.emiAmount)} pending',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ] else if (loan.nextEmiDate != null) ...[
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Next EMI: ${loan.nextEmiDate}  •  ${_fmtAmt(loan.emiAmount)}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _typeColor {
    final t = loan.productName.toLowerCase();
    if (t.contains('business')) return AppColors.accent;
    if (t.contains('agri')) return AppColors.secondary;
    if (t.contains('home') || t.contains('hous')) return const Color(0xFF7C3AED);
    return AppColors.primary;
  }

  IconData get _typeIcon {
    final t = loan.productName.toLowerCase();
    if (t.contains('business')) return Icons.business_center_rounded;
    if (t.contains('agri')) return Icons.agriculture_rounded;
    if (t.contains('home') || t.contains('hous')) return Icons.home_rounded;
    return Icons.account_balance_rounded;
  }

  String _fmtAmt(double v) {
    if (v >= 100000) return 'NPR ${(v / 100000).toStringAsFixed(1)}L';
    final s = v.toStringAsFixed(0);
    if (s.length <= 3) return 'NPR $s';
    return 'NPR ${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
}

class _InfoPair extends StatelessWidget {
  final String label, value;
  const _InfoPair({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.labelLarge),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: color, fontSize: 10)),
            Text(value, style: AppTextStyles.labelLarge.copyWith(color: color, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
