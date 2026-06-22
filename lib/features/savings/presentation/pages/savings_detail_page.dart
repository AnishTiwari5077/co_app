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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
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
                    padding: const EdgeInsets.fromLTRB(AppDimensions.md, 56, AppDimensions.md, AppDimensions.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                              child: const Icon(Icons.savings_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Regular Savings Account',
                                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
                                  Text(widget.accountId,
                                      style: AppTextStyles.titleSmall.copyWith(color: Colors.white)),
                                ],
                              ),
                            ),
                            const StatusBadge(status: 'Active', isLight: true),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.md),
                        Text('NPR 45,000.00',
                            style: AppTextStyles.headlineLarge.copyWith(color: Colors.white)),
                        Text('Current Balance',
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.white60)),
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
            _DetailsTab(accountId: widget.accountId),
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
                onPressed: () => context.go(AppRoutes.deposit(widget.accountId)),
                icon: Icons.arrow_downward_rounded,
                variant: ButtonVariant.secondary,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: AppButton(
                label: 'Withdraw',
                onPressed: () => context.go(AppRoutes.withdraw(widget.accountId)),
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

class _TransactionsTab extends StatelessWidget {
  final String accountId;
  const _TransactionsTab({required this.accountId});

  @override
  Widget build(BuildContext context) {
    final txns = [
      _TxnRow(date: '15 Ashad 2081', type: 'Deposit', amount: 25000, mode: 'Cash', balance: 45000, receipt: 'RCP-2081-00420', isCredit: true),
      _TxnRow(date: '01 Ashad 2081', type: 'Interest Credit', amount: 271, mode: 'Auto', balance: 20000, receipt: 'INT-2081-04', isCredit: true),
      _TxnRow(date: '25 Jestha 2081', type: 'Withdrawal', amount: 10000, mode: 'Cash', balance: 19729, receipt: 'RCP-2081-00380', isCredit: false),
      _TxnRow(date: '01 Jestha 2081', type: 'Interest Credit', amount: 258, mode: 'Auto', balance: 29729, receipt: 'INT-2081-03', isCredit: true),
      _TxnRow(date: '10 Baisakh 2081', type: 'Deposit', amount: 15000, mode: 'Bank Transfer', balance: 29471, receipt: 'RCP-2081-00310', isCredit: true),
      _TxnRow(date: '01 Baisakh 2081', type: 'Interest Credit', amount: 250, mode: 'Auto', balance: 14471, receipt: 'INT-2081-02', isCredit: true),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: txns.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.xs),
      itemBuilder: (context, i) => _TxnCard(txn: txns[i]),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final String accountId;
  const _DetailsTab({required this.accountId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        InfoSection(title: 'Account Information', rows: [
          InfoRow(label: 'Account Number', value: accountId),
          InfoRow(label: 'Account Type', value: 'Regular Savings'),
          InfoRow(label: 'Scheme', value: 'Standard Saving Scheme (SCH-001)'),
          InfoRow(label: 'Status', value: 'Active'),
          InfoRow(label: 'Opened Date', value: '15 Shrawan 2079'),
          InfoRow(label: 'Branch', value: 'Kathmandu Head Office'),
        ]),
        const SizedBox(height: AppDimensions.md),
        InfoSection(title: 'Scheme Parameters', rows: [
          InfoRow(label: 'Interest Rate', value: '7.5% p.a.'),
          InfoRow(label: 'Minimum Balance', value: 'NPR 500'),
          InfoRow(label: 'Minimum Deposit', value: 'NPR 100'),
          InfoRow(label: 'Interest Calculation', value: 'Daily Product Method'),
          InfoRow(label: 'Interest Posting', value: 'Monthly (Last day)'),
          InfoRow(label: 'TDS on Interest', value: '5%'),
        ]),
        const SizedBox(height: AppDimensions.md),
        InfoSection(title: 'Statistics', rows: [
          InfoRow(label: 'Total Deposits', value: 'NPR 1,40,000'),
          InfoRow(label: 'Total Withdrawals', value: 'NPR 95,000'),
          InfoRow(label: 'Total Interest Earned', value: 'NPR 1,829'),
          InfoRow(label: 'TDS Deducted', value: 'NPR 91'),
          InfoRow(label: 'Accrued Interest', value: 'NPR 185'),
        ]),
      ],
    );
  }
}

class _TxnCard extends StatelessWidget {
  final _TxnRow txn;
  const _TxnCard({required this.txn});

  @override
  Widget build(BuildContext context) {
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: txn.isCredit
                  ? AppColors.secondary.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
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
                Text(txn.type, style: AppTextStyles.bodyMedium),
                Text('${txn.date}  •  ${txn.mode}  •  ${txn.receipt}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${txn.isCredit ? '+' : '-'} NPR ${txn.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: AppTextStyles.amountSmall.copyWith(
                  color: txn.isCredit ? AppColors.creditAmount : AppColors.debitAmount,
                ),
              ),
              Text(
                'Bal: NPR ${txn.balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxnRow {
  final String date, type, mode, receipt;
  final int amount, balance;
  final bool isCredit;
  const _TxnRow({
    required this.date,
    required this.type,
    required this.amount,
    required this.mode,
    required this.balance,
    required this.receipt,
    required this.isCredit,
  });
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
