import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
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

  final _notifications = [
    _NotifItem(
      title: 'EMI Overdue — Bikash KC',
      body: 'Loan LN-2079-00055: EMI of NPR 4,500 is 42 days overdue.',
      type: 'alert',
      time: '2h ago',
      isRead: false,
    ),
    _NotifItem(
      title: 'Loan Application Received',
      body: 'Anita Rai (KTM-2081-010) has submitted a loan application of NPR 1,00,000.',
      type: 'loan',
      time: '4h ago',
      isRead: false,
    ),
    _NotifItem(
      title: 'Monthly Interest Posted',
      body: 'Interest for Ashad 2081 has been posted to 1,245 savings accounts.',
      type: 'savings',
      time: '1d ago',
      isRead: true,
    ),
    _NotifItem(
      title: 'New Member Registration',
      body: 'Sita Magar has submitted a membership application. Pending KYC review.',
      type: 'member',
      time: '1d ago',
      isRead: true,
    ),
    _NotifItem(
      title: 'Large Withdrawal Alert',
      body: 'Ram Shrestha requested NPR 2,00,000 withdrawal. Manager approval required.',
      type: 'alert',
      time: '2d ago',
      isRead: true,
    ),
    _NotifItem(
      title: 'FD Maturity Alert',
      body: 'Fixed Deposit FD-2080-00123 (NPR 2,00,000) matures in 7 days.',
      type: 'savings',
      time: '2d ago',
      isRead: true,
    ),
    _NotifItem(
      title: 'Login from New Device',
      body: 'Your account was accessed from a new device in Lalitpur.',
      type: 'security',
      time: '3d ago',
      isRead: true,
    ),
    _NotifItem(
      title: 'System Backup Complete',
      body: 'Nightly backup completed successfully. All data secured.',
      type: 'system',
      time: '3d ago',
      isRead: true,
    ),
  ];

  List<_NotifItem> get _unread =>
      _notifications.where((n) => !n.isRead).toList();
  List<_NotifItem> get _alerts =>
      _notifications.where((n) => n.type == 'alert' || n.type == 'security').toList();

  void _markAllRead() => setState(() {
        for (final n in _notifications) {
          n.isRead = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text('Mark all read',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.primary)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelLarge,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All'),
                  if (_unread.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
                      ),
                      child: Text('${_unread.length}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Alerts'),
            const Tab(text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_notifications),
          _buildList(_alerts),
          _buildList(_notifications
              .where((n) => n.type == 'system')
              .toList()),
        ],
      ),
    );
  }

  Widget _buildList(List<_NotifItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppDimensions.md),
            const Text('No notifications', style: AppTextStyles.titleMedium),
            Text('You\'re all caught up!',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.xs),
      itemBuilder: (context, i) => _NotifCard(
        notif: items[i],
        onTap: () => setState(() => items[i].isRead = true),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final _NotifItem notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  Color get _typeColor {
    switch (notif.type) {
      case 'alert':
        return AppColors.error;
      case 'loan':
        return AppColors.accent;
      case 'savings':
        return AppColors.secondary;
      case 'member':
        return AppColors.primary;
      case 'security':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (notif.type) {
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'loan':
        return Icons.account_balance_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'member':
        return Icons.person_rounded;
      case 'security':
        return Icons.security_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: notif.isRead
              ? AppColors.surface
              : AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: notif.isRead
                ? const Color(0xFFE8EDF3)
                : AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.body,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusRound),
                        ),
                        child: Text(
                          notif.type.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                              color: _typeColor, fontSize: 9),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        notif.time,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifItem {
  final String title, body, type, time;
  bool isRead;
  _NotifItem({
    required this.title,
    required this.body,
    required this.type,
    required this.time,
    required this.isRead,
  });
}
