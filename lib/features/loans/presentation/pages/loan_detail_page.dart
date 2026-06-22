import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/app_button.dart';

class LoanDetailPage extends ConsumerStatefulWidget {
  final String loanId;
  const LoanDetailPage({super.key, required this.loanId});

  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [_buildHeader(), _buildTabBar()],
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(loanId: widget.loanId),
            _ScheduleTab(loanId: widget.loanId),
            _PaymentsTab(),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
          onPressed: () =>
              context.go('${AppColors.primary}/${widget.loanId}/schedule'),
          tooltip: 'EMI Schedule',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (v) {},
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'reschedule', child: Text('Reschedule Loan')),
            const PopupMenuItem(value: 'prepay', child: Text('Pre-payment')),
            const PopupMenuItem(value: 'waive', child: Text('Waive Penalty')),
            const PopupMenuItem(value: 'noc', child: Text('Generate NOC')),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, Color(0xFF1E4D8C)],
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: const Icon(Icons.account_balance_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.loanId,
                              style: AppTextStyles.titleMedium
                                  .copyWith(color: Colors.white)),
                          Text('Personal Loan',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: Colors.white70)),
                        ],
                      ),
                      const Spacer(),
                      const StatusBadge(status: 'Active', isLight: true),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text('NPR 2,50,000',
                      style: AppTextStyles.headlineLarge
                          .copyWith(color: Colors.white)),
                  Text('Principal Amount',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white60)),
                  const SizedBox(height: AppDimensions.sm),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Outstanding: NPR 1,80,234',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: Colors.white70)),
                          Text('27.9% paid',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.279,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'EMI Schedule'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final String loanId;
  const _OverviewTab({required this.loanId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        // EMI info card
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.secondary, size: 32),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next EMI Due',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.secondary)),
                    Text('NPR 11,634',
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.secondary)),
                    Text('01 Shrawan 2081 (16 Jul 2024)',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              AppButton(
                label: 'Pay',
                onPressed: () {},
                variant: ButtonVariant.secondary,
                icon: Icons.payment_rounded,
                isSmall: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        // Loan details
        _InfoSection(title: 'Loan Details', rows: [
          InfoRow(label: 'Loan Number', value: loanId),
          InfoRow(label: 'Loan Type', value: 'Personal Loan'),
          InfoRow(label: 'Product', value: 'Standard Personal Loan (PL-001)'),
          InfoRow(label: 'Principal Amount', value: 'NPR 2,50,000'),
          InfoRow(label: 'Disbursed Amount', value: 'NPR 2,50,000'),
          InfoRow(label: 'Processing Fee', value: 'NPR 1,250 (0.5%)'),
          InfoRow(label: 'Interest Rate', value: '14% p.a. (Reducing Balance)'),
          InfoRow(label: 'Tenure', value: '24 months'),
          InfoRow(label: 'EMI Amount', value: 'NPR 11,634'),
          InfoRow(label: 'Application Date', value: '15 Poush 2080'),
          InfoRow(label: 'Disbursement Date', value: '22 Poush 2080'),
          InfoRow(label: 'Maturity Date', value: '01 Poush 2082'),
        ]),
        const SizedBox(height: AppDimensions.md),
        _InfoSection(title: 'Outstanding Summary', rows: [
          InfoRow(label: 'Principal Outstanding', value: 'NPR 1,72,614'),
          InfoRow(label: 'Interest Outstanding', value: 'NPR 7,620'),
          InfoRow(label: 'Penalty Outstanding', value: 'NPR 0'),
          InfoRow(label: 'Total Outstanding', value: 'NPR 1,80,234'),
          InfoRow(label: 'Installments Paid', value: '7 of 24'),
          InfoRow(label: 'Installments Remaining', value: '17'),
        ]),
        const SizedBox(height: AppDimensions.md),
        _InfoSection(title: 'Guarantors', rows: [
          InfoRow(label: 'Guarantor 1', value: 'Sita Shrestha (Spouse)'),
          InfoRow(label: 'Guarantor 1 Code', value: 'KTM-2081-009'),
          InfoRow(label: 'Shares Pledged', value: 'NPR 25,000'),
        ]),
        const SizedBox(height: AppDimensions.md),
        _InfoSection(title: 'Collateral', rows: [
          InfoRow(label: 'Type', value: 'Land and Building'),
          InfoRow(label: 'Description', value: 'Residential land at Maharajgunj-5'),
          InfoRow(label: 'Estimated Value', value: 'NPR 45,00,000'),
          InfoRow(label: 'Verified By', value: 'Ram Prasad (Valuer)'),
        ]),
        const SizedBox(height: AppDimensions.xxl),
      ],
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  final String loanId;
  const _ScheduleTab({required this.loanId});

  @override
  Widget build(BuildContext context) {
    final schedules = List.generate(24, (i) {
      final isPaid = i < 7;
      final isCurrent = i == 7;
      return _ScheduleRow(
        installmentNo: i + 1,
        dueDate: '01 ${_month(i)} 208${1 + (i ~/ 12)}',
        principal: 'NPR ${(8_334 + (i * 50)).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
        interest: 'NPR ${(3_300 - (i * 100)).clamp(0, 9999).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
        total: 'NPR 11,634',
        balance: isPaid ? '—' : 'NPR ${(1_72_614 - (i * 8000)).clamp(0, 999999).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
        isPaid: isPaid,
        isCurrent: isCurrent,
      );
    });

    return Column(
      children: [
        // Header row
        Container(
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: AppDimensions.sm),
          child: Row(
            children: ['#', 'Due Date', 'Principal', 'Interest', 'Total', 'Balance']
                .map((h) => Expanded(
                    child: Text(h,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center)))
                .toList(),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: schedules.length,
            itemBuilder: (context, i) => _ScheduleRowWidget(row: schedules[i]),
          ),
        ),
      ],
    );
  }

  String _month(int i) {
    const months = ['Shrawan', 'Bhadra', 'Ashwin', 'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra', 'Baisakh', 'Jestha', 'Ashad'];
    return months[i % 12];
  }
}

class _PaymentsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final payments = [
      _PaymentRow(date: '01 Ashad 2081', principal: 'NPR 8,084', interest: 'NPR 3,550', penalty: '—', total: 'NPR 11,634', mode: 'Cash', receipt: 'RCP-0089'),
      _PaymentRow(date: '01 Jestha 2081', principal: 'NPR 7,990', interest: 'NPR 3,644', penalty: '—', total: 'NPR 11,634', mode: 'Cash', receipt: 'RCP-0078'),
      _PaymentRow(date: '01 Baisakh 2081', principal: 'NPR 7,896', interest: 'NPR 3,738', penalty: 'NPR 200', total: 'NPR 11,834', mode: 'Bank Transfer', receipt: 'RCP-0067'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) => _PaymentCard(payment: payments[i]),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String title;
  final List<InfoRow> rows;
  const _InfoSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
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
            child: Text(title, style: AppTextStyles.titleSmall),
          ),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }
}

class _ScheduleRow {
  final int installmentNo;
  final String dueDate, principal, interest, total, balance;
  final bool isPaid, isCurrent;
  const _ScheduleRow({
    required this.installmentNo,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.total,
    required this.balance,
    required this.isPaid,
    required this.isCurrent,
  });
}

class _ScheduleRowWidget extends StatelessWidget {
  final _ScheduleRow row;
  const _ScheduleRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: row.isCurrent
          ? AppColors.primary.withOpacity(0.05)
          : row.isPaid
              ? AppColors.secondary.withOpacity(0.03)
              : Colors.transparent,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (row.isPaid)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.secondary, size: 14)
                else if (row.isCurrent)
                  const Icon(Icons.radio_button_checked_rounded,
                      color: AppColors.primary, size: 14)
                else
                  const Icon(Icons.radio_button_unchecked_rounded,
                      color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 4),
                Text('${row.installmentNo}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: row.isCurrent
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: row.isCurrent ? FontWeight.w700 : null,
                    )),
              ],
            ),
          ),
          Expanded(
            child: Text(row.dueDate,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(row.principal,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(row.interest,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(row.total,
                style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(row.balance,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow {
  final String date, principal, interest, penalty, total, mode, receipt;
  const _PaymentRow({
    required this.date,
    required this.principal,
    required this.interest,
    required this.penalty,
    required this.total,
    required this.mode,
    required this.receipt,
  });
}

class _PaymentCard extends StatelessWidget {
  final _PaymentRow payment;
  const _PaymentCard({required this.payment});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(payment.date, style: AppTextStyles.titleSmall),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
                ),
                child: Text('PAID',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.secondary)),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoPair(label: 'Principal', value: payment.principal),
              _InfoPair(label: 'Interest', value: payment.interest),
              _InfoPair(label: 'Penalty', value: payment.penalty),
              _InfoPair(label: 'Total', value: payment.total),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              const Icon(Icons.receipt_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${payment.receipt}  •  ${payment.mode}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
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
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, fontSize: 10)),
        Text(value, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
