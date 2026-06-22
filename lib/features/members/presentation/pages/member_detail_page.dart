import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';

class MemberDetailPage extends ConsumerStatefulWidget {
  final String memberId;
  const MemberDetailPage({super.key, required this.memberId});

  @override
  ConsumerState<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends ConsumerState<MemberDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        headerSliverBuilder: (context, innerScrolled) => [
          _buildSliverHeader(),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: AppTextStyles.labelLarge,
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Savings'),
                  Tab(text: 'Loans'),
                  Tab(text: 'Shares'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ProfileTab(memberId: widget.memberId),
            _SavingsTab(),
            _LoansTab(),
            _SharesTab(),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          onPressed: () {},
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {},
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'suspend', child: Text('Suspend Member')),
            const PopupMenuItem(value: 'close', child: Text('Close Account')),
            const PopupMenuItem(value: 'export', child: Text('Export Profile')),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md, 56, AppDimensions.md, AppDimensions.md),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusXl),
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ram Bahadur Shrestha',
                            style: AppTextStyles.headlineSmall
                                .copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(widget.memberId,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusRound),
                              ),
                              child: Text('Active',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusRound),
                              ),
                              child: Text('KYC ✓',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String memberId;
  const _ProfileTab({required this.memberId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        _InfoSection(title: 'Personal Information', rows: [
          InfoRow(label: 'Full Name', value: 'Ram Bahadur Shrestha'),
          InfoRow(label: 'Full Name (NP)', value: 'राम बहादुर श्रेष्ठ'),
          InfoRow(label: 'Date of Birth', value: '15 Falgun 2035 (27 Feb 1979)'),
          InfoRow(label: 'Age', value: '46 years'),
          InfoRow(label: 'Gender', value: 'Male'),
          InfoRow(label: 'Blood Group', value: 'B+'),
          InfoRow(label: 'Marital Status', value: 'Married'),
          InfoRow(label: 'Occupation', value: 'Business'),
          InfoRow(label: 'Education', value: 'Bachelor\'s Degree'),
        ]),
        const SizedBox(height: AppDimensions.md),
        _InfoSection(title: 'Contact Information', rows: [
          InfoRow(label: 'Primary Phone', value: '9841000001'),
          InfoRow(label: 'Secondary Phone', value: '01-4400001'),
          InfoRow(label: 'Email', value: 'ram.shrestha@email.com'),
        ]),
        const SizedBox(height: AppDimensions.md),
        _InfoSection(title: 'Address', rows: [
          InfoRow(label: 'Province', value: 'Bagmati Province'),
          InfoRow(label: 'District', value: 'Kathmandu'),
          InfoRow(label: 'Municipality', value: 'Kathmandu Metropolitan City'),
          InfoRow(label: 'Ward', value: '5'),
          InfoRow(label: 'Tole', value: 'Maharajgunj'),
        ]),
        const SizedBox(height: AppDimensions.md),
        _InfoSection(title: 'Identity Documents', rows: [
          InfoRow(label: 'Citizenship No.', value: '23-01-75-00001'),
          InfoRow(label: 'Issued District', value: 'Kathmandu'),
          InfoRow(label: 'Issued Date', value: '2075-01-20'),
          InfoRow(label: 'PAN No.', value: '***-***-***'),
        ]),
        const SizedBox(height: AppDimensions.md),
        _InfoSection(title: 'Membership Details', rows: [
          InfoRow(label: 'Member Code', value: memberId),
          InfoRow(label: 'Membership Date', value: '15 Shrawan 2079'),
          InfoRow(label: 'Membership Fee', value: 'NPR 500'),
          InfoRow(label: 'KYC Status', value: 'Verified ✓'),
          InfoRow(label: 'KYC Verified By', value: 'Suman Adhikari (Manager)'),
          InfoRow(label: 'Approved By', value: 'Suman Adhikari'),
          InfoRow(label: 'Branch', value: 'Kathmandu Head Office'),
        ]),
        const SizedBox(height: AppDimensions.xxl),
      ],
    );
  }
}

class _SavingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        _SavingsAccountCard(
          accountNo: 'SAV-2079-00001',
          type: 'Regular Savings',
          balance: 'NPR 45,000.00',
          interestRate: '7.5%',
          status: 'Active',
          openDate: '15 Shrawan 2079',
        ),
        const SizedBox(height: AppDimensions.sm),
        _SavingsAccountCard(
          accountNo: 'FD-2080-00123',
          type: 'Fixed Deposit',
          balance: 'NPR 2,00,000.00',
          interestRate: '11%',
          status: 'Active',
          openDate: '01 Poush 2080',
          maturityDate: '01 Poush 2081',
        ),
      ],
    );
  }
}

class _LoansTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        _LoanAccountCard(
          loanNo: 'LN-2080-00089',
          type: 'Personal Loan',
          principal: 'NPR 2,50,000',
          outstanding: 'NPR 1,80,234',
          emi: 'NPR 11,634',
          nextEmiDate: '01 Shrawan 2081',
          status: 'Active',
        ),
      ],
    );
  }
}

class _SharesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share Account',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white70)),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('250',
                            style: AppTextStyles.headlineMedium
                                .copyWith(color: Colors.white)),
                        Text('Shares Held',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white70)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('NPR 25,000',
                            style: AppTextStyles.headlineSmall
                                .copyWith(color: Colors.white)),
                        Text('Total Value',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: AppDimensions.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('@ NPR 100 / share',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70)),
                    Text('Last dividend: 15%',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          _InfoSection(title: 'Dividend History', rows: [
            InfoRow(label: 'FY 2080/81', value: 'NPR 3,750 (15%)'),
            InfoRow(label: 'FY 2079/80', value: 'NPR 3,000 (12%)'),
            InfoRow(label: 'FY 2078/79', value: 'NPR 2,500 (10%)'),
          ]),
        ],
      ),
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
          ...rows.map((r) => r),
        ],
      ),
    );
  }
}

class _SavingsAccountCard extends StatelessWidget {
  final String accountNo, type, balance, interestRate, status, openDate;
  final String? maturityDate;
  const _SavingsAccountCard({
    required this.accountNo,
    required this.type,
    required this.balance,
    required this.interestRate,
    required this.status,
    required this.openDate,
    this.maturityDate,
  });

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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Icon(Icons.savings_rounded,
                    color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type, style: AppTextStyles.titleSmall),
                    Text(accountNo,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text(balance,
              style: AppTextStyles.amountMedium
                  .copyWith(color: AppColors.secondary)),
          const SizedBox(height: AppDimensions.xs),
          Row(
            children: [
              Text('Rate: $interestRate',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              Text('Opened: $openDate',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          if (maturityDate != null) ...[
            const SizedBox(height: 4),
            Text('Matures: $maturityDate',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _LoanAccountCard extends StatelessWidget {
  final String loanNo, type, principal, outstanding, emi, nextEmiDate, status;
  const _LoanAccountCard({
    required this.loanNo,
    required this.type,
    required this.principal,
    required this.outstanding,
    required this.emi,
    required this.nextEmiDate,
    required this.status,
  });

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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type, style: AppTextStyles.titleSmall),
                    Text(loanNo,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountCell(label: 'Principal', value: principal),
              _AmountCell(label: 'Outstanding', value: outstanding),
              _AmountCell(label: 'EMI', value: emi),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text('Next EMI: $nextEmiDate',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  final String label, value;
  const _AmountCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.amountSmall),
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
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
