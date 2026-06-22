import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';

// ── Mock data ────────────────────────────────────────────────────────────────
final _mockMembers = [
  _MemberRow(code: 'KTM-2081-001', name: 'Ram Bahadur Shrestha', phone: '9841000001', status: 'Active', savings: 'NPR 45,000', loans: 'NPR 2,50,000'),
  _MemberRow(code: 'KTM-2081-002', name: 'Sita Tamang', phone: '9845000002', status: 'Active', savings: 'NPR 12,500', loans: '—'),
  _MemberRow(code: 'KTM-2081-003', name: 'Hari Poudel', phone: '9861000003', status: 'Pending', savings: 'NPR 5,000', loans: '—'),
  _MemberRow(code: 'KTM-2081-004', name: 'Kamala Gurung', phone: '9843000004', status: 'Active', savings: 'NPR 1,20,000', loans: 'NPR 5,00,000'),
  _MemberRow(code: 'KTM-2081-005', name: 'Bikash KC', phone: '9862000005', status: 'Suspended', savings: 'NPR 8,000', loans: 'NPR 80,000'),
  _MemberRow(code: 'KTM-2081-006', name: 'Rita Magar', phone: '9841000006', status: 'Active', savings: 'NPR 30,000', loans: '—'),
  _MemberRow(code: 'KTM-2081-007', name: 'Deepak Thapa', phone: '9845000007', status: 'Active', savings: 'NPR 60,000', loans: 'NPR 1,50,000'),
  _MemberRow(code: 'KTM-2081-008', name: 'Sunita Karki', phone: '9861000008', status: 'Inactive', savings: '—', loans: '—'),
];

class MemberListPage extends ConsumerStatefulWidget {
  const MemberListPage({super.key});

  @override
  ConsumerState<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends ConsumerState<MemberListPage> {
  final _searchCtrl = TextEditingController();
  String _filterStatus = 'All';
  String _query = '';

  final _statuses = ['All', 'Active', 'Pending', 'Suspended', 'Inactive'];

  List<_MemberRow> get _filtered => _mockMembers.where((m) {
        final matchSearch = _query.isEmpty ||
            m.name.toLowerCase().contains(_query.toLowerCase()) ||
            m.code.toLowerCase().contains(_query.toLowerCase()) ||
            m.phone.contains(_query);
        final matchStatus =
            _filterStatus == 'All' || m.status == _filterStatus;
        return matchSearch && matchStatus;
      }).toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Members', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('${AppRoutes.members}/register'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('New Member', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, code, phone...',
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
          // Status chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md, vertical: 8),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.xs),
              itemBuilder: (context, i) {
                final s = _statuses[i];
                final selected = _filterStatus == s;
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterStatus = s),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary,
                  labelStyle: AppTextStyles.labelSmall.copyWith(
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                  showCheckmark: false,
                  side: BorderSide(
                    color: selected ? AppColors.primary : const Color(0xFFE0E7EF),
                  ),
                );
              },
            ),
          ),
          // Count bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.xs),
            child: Row(
              children: [
                Text('${_filtered.length} members',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          // List
          Expanded(
            child: _filtered.isEmpty
                ? const EmptyView(
                    icon: Icons.people_outline_rounded,
                    title: 'No members found',
                    subtitle: 'Try adjusting your search or filters')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppDimensions.md, 0,
                        AppDimensions.md, AppDimensions.xxl),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.sm),
                    itemBuilder: (context, i) =>
                        _MemberCard(member: _filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Members', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimensions.md),
            Wrap(
              spacing: AppDimensions.sm,
              children: _statuses.map((s) {
                final selected = _filterStatus == s;
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _filterStatus = s);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.md),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final _MemberRow member;
  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('${AppRoutes.members}/${member.code}'),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: const Color(0xFFE8EDF3)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.7),
                    AppColors.primaryLight
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Center(
                child: Text(
                  member.name.split(' ').map((w) => w[0]).take(2).join(),
                  style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(member.name,
                            style: AppTextStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      StatusBadge(status: member.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(member.code,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.savings_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(member.savings, style: AppTextStyles.bodySmall),
                      const SizedBox(width: AppDimensions.sm),
                      if (member.loans != '—') ...[
                        const Icon(Icons.account_balance_outlined,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(member.loans, style: AppTextStyles.bodySmall),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _MemberRow {
  final String code, name, phone, status, savings, loans;
  const _MemberRow(
      {required this.code,
      required this.name,
      required this.phone,
      required this.status,
      required this.savings,
      required this.loans});
}
