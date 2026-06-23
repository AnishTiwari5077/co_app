import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../providers/member_provider.dart';
import '../../../../core/api/repositories/member_repository.dart';
import '../../../../core/widgets/main_shell.dart';

class MemberListPage extends ConsumerStatefulWidget {
  const MemberListPage({super.key});

  @override
  ConsumerState<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends ConsumerState<MemberListPage> {
  final _searchCtrl = TextEditingController();
  String _filterStatus = 'All';

  final _statuses = ['All', 'Active', 'Pending', 'Suspended', 'Inactive'];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      ref.read(memberListProvider.notifier).search(_searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyStatusFilter(String status) {
    setState(() => _filterStatus = status);
    ref.read(memberListProvider.notifier).filterByStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(memberListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Members', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(memberListProvider.notifier).refresh(),
          ),
          const AppBarUserBadge(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('${AppRoutes.members}/register');
          // Refresh list when returning from registration
          if (context.mounted) {
            ref.read(memberListProvider.notifier).refresh();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('New Member',
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
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
              decoration: InputDecoration(
                hintText: 'Search by name, code, phone...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(memberListProvider.notifier).search('');
                        })
                    : null,
              ),
            ),
          ),
          // Status filter chips
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
                  onSelected: (_) => _applyStatusFilter(s),
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
          // Member list
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: AppDimensions.sm),
                    const Text('Failed to load members',
                        style: AppTextStyles.titleSmall),
                    const SizedBox(height: AppDimensions.xs),
                    Text(e.toString(),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppDimensions.md),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(memberListProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (members) {
                if (members.isEmpty) {
                  return const EmptyView(
                    icon: Icons.people_outline_rounded,
                    title: 'No members found',
                    subtitle: 'Try adjusting your search or filters',
                  );
                }
                return Column(
                  children: [
                    // Count bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: AppDimensions.xs),
                      child: Row(
                        children: [
                          Text('${members.length} members',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppDimensions.md,
                            0, AppDimensions.md, AppDimensions.xxl),
                        itemCount: members.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppDimensions.sm),
                        itemBuilder: (context, i) =>
                            _MemberCard(member: members[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final MemberListItem member;
  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final initials = member.fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

    final savingsText = member.totalSavings != null && member.totalSavings! > 0
        ? 'NPR ${member.totalSavings!.toStringAsFixed(0)}'
        : null;
    final loansText = member.totalLoans != null && member.totalLoans! > 0
        ? 'NPR ${member.totalLoans!.toStringAsFixed(0)}'
        : null;

    return GestureDetector(
      onTap: () async {
        await context.push('${AppRoutes.members}/${member.id}');
        // Refresh list when returning from detail (status may have changed)
        if (context.mounted) {
          final container = ProviderScope.containerOf(context, listen: false);
          container.read(memberListProvider.notifier).refresh();
        }
      },
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
                    AppColors.primary.withValues(alpha: 0.7),
                    AppColors.primaryLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: Colors.white),
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
                        child: Text(member.fullName,
                            style: AppTextStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      StatusBadge(status: member.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.memberCode,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  if (savingsText != null || loansText != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (savingsText != null) ...[
                          const Icon(Icons.savings_outlined,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(savingsText,
                              style: AppTextStyles.bodySmall),
                        ],
                        if (loansText != null) ...[
                          const SizedBox(width: AppDimensions.sm),
                          const Icon(Icons.account_balance_outlined,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(loansText,
                              style: AppTextStyles.bodySmall),
                        ],
                      ],
                    ),
                  ],
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
