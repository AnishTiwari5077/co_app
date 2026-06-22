import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';

final _mockLoans = [
  _LoanRow(loanNo: 'LN-2080-00089', memberName: 'Ram Bahadur Shrestha', memberCode: 'KTM-2081-001', type: 'Personal Loan', amount: 'NPR 2,50,000', outstanding: 'NPR 1,80,234', emi: 'NPR 11,634', nextEmiDate: '01 Shrawan 2081', status: 'Active', overdueDays: 0),
  _LoanRow(loanNo: 'LN-2080-00090', memberName: 'Kamala Gurung', memberCode: 'KTM-2081-004', type: 'Business Loan', amount: 'NPR 5,00,000', outstanding: 'NPR 4,12,500', emi: 'NPR 22,500', nextEmiDate: '15 Ashad 2081', status: 'Active', overdueDays: 0),
  _LoanRow(loanNo: 'LN-2079-00055', memberName: 'Bikash KC', memberCode: 'KTM-2081-005', type: 'Agriculture Loan', amount: 'NPR 80,000', outstanding: 'NPR 72,000', emi: 'NPR 4,500', nextEmiDate: '10 Jestha 2081', status: 'Overdue', overdueDays: 42),
  _LoanRow(loanNo: 'LN-2081-00010', memberName: 'Deepak Thapa', memberCode: 'KTM-2081-007', type: 'Home Loan', amount: 'NPR 1,50,000', outstanding: 'NPR 1,50,000', emi: 'NPR 6,250', nextEmiDate: '01 Shrawan 2081', status: 'Disbursed', overdueDays: 0),
  _LoanRow(loanNo: 'LN-2081-00011', memberName: 'Anita Rai', memberCode: 'KTM-2081-010', type: 'Personal Loan', amount: 'NPR 1,00,000', outstanding: 'NPR 1,00,000', emi: '—', nextEmiDate: '—', status: 'Pending', overdueDays: 0),
];

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Loans', style: AppTextStyles.titleLarge),
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
        onPressed: () => context.go('${AppRoutes.loans}/apply'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: Text('New Loan', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
      ),
      body: Column(
        children: [
          // KPI summary bar
          _buildLoanSummary(),
          // Search
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLoanList(_mockLoans),
                _buildLoanList(_mockLoans.where((l) => l.status == 'Active').toList()),
                _buildLoanList(_mockLoans.where((l) => l.status == 'Overdue').toList()),
                _buildLoanList(_mockLoans.where((l) => l.status == 'Pending').toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanSummary() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          _SummaryChip(label: 'Portfolio', value: 'NPR 7.8Cr', color: AppColors.primary),
          const SizedBox(width: AppDimensions.sm),
          _SummaryChip(label: 'Active', value: '342', color: AppColors.secondary),
          const SizedBox(width: AppDimensions.sm),
          _SummaryChip(label: 'Overdue', value: '18', color: AppColors.error),
          const SizedBox(width: AppDimensions.sm),
          _SummaryChip(label: 'NPA', value: '2.3%', color: AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildLoanList(List<_LoanRow> loans) {
    final filtered = _query.isEmpty
        ? loans
        : loans.where((l) =>
            l.loanNo.toLowerCase().contains(_query.toLowerCase()) ||
            l.memberName.toLowerCase().contains(_query.toLowerCase())).toList();

    if (filtered.isEmpty) {
      return const EmptyView(
          icon: Icons.account_balance_outlined,
          title: 'No loans found',
          subtitle: 'Try adjusting your search');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.md, AppDimensions.md, AppDimensions.xxl),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) => _LoanCard(loan: filtered[i]),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final _LoanRow loan;
  const _LoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('${AppRoutes.loans}/${loan.loanNo}'),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: loan.status == 'Overdue'
                ? AppColors.error.withOpacity(0.3)
                : const Color(0xFFE8EDF3),
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
                    color: _loanTypeColor(loan.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(_loanTypeIcon(loan.type),
                      color: _loanTypeColor(loan.type), size: 20),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loan.memberName, style: AppTextStyles.titleSmall),
                      Text(loan.loanNo,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.primary)),
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
                _InfoPair(label: 'Type', value: loan.type),
                _InfoPair(label: 'Amount', value: loan.amount),
                _InfoPair(label: 'Outstanding', value: loan.outstanding),
              ],
            ),
            if (loan.status == 'Overdue') ...[
              const SizedBox(height: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${loan.overdueDays} days overdue — EMI ${loan.emi} pending',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ] else if (loan.nextEmiDate != '—') ...[
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Next EMI: ${loan.nextEmiDate}  •  ${loan.emi}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _loanTypeColor(String type) {
    switch (type) {
      case 'Business Loan':
        return AppColors.accent;
      case 'Agriculture Loan':
        return AppColors.secondary;
      case 'Home Loan':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.primary;
    }
  }

  IconData _loanTypeIcon(String type) {
    switch (type) {
      case 'Business Loan':
        return Icons.business_center_rounded;
      case 'Agriculture Loan':
        return Icons.agriculture_rounded;
      case 'Home Loan':
        return Icons.home_rounded;
      default:
        return Icons.account_balance_rounded;
    }
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
        Text(label,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.labelLarge),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm, vertical: AppDimensions.xs),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: color, fontSize: 10)),
            Text(value,
                style: AppTextStyles.labelLarge
                    .copyWith(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LoanRow {
  final String loanNo, memberName, memberCode, type, amount, outstanding, emi, nextEmiDate, status;
  final int overdueDays;
  const _LoanRow({
    required this.loanNo,
    required this.memberName,
    required this.memberCode,
    required this.type,
    required this.amount,
    required this.outstanding,
    required this.emi,
    required this.nextEmiDate,
    required this.status,
    required this.overdueDays,
  });
}
