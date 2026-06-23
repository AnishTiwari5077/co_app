import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/api/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _NotifItem {
  final String id, title, body, type, category;
  final DateTime createdAt;
  bool isRead;

  _NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.category,
    required this.createdAt,
    required this.isRead,
  });

  factory _NotifItem.fromJson(Map<String, dynamic> j) => _NotifItem(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        type: (j['type'] as String? ?? 'system').toLowerCase(),
        category: j['category'] as String? ?? 'SYSTEM',
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        isRead: j['isRead'] as bool? ?? true,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

class _NotifState {
  final List<_NotifItem> items;
  final bool isLoading;
  final String? error;
  const _NotifState({this.items = const [], this.isLoading = false, this.error});
  _NotifState copyWith({List<_NotifItem>? items, bool? isLoading, String? error}) =>
      _NotifState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class _NotifNotifier extends StateNotifier<_NotifState> {
  final dynamic _dio;
  _NotifNotifier(this._dio) : super(const _NotifState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get('/api/v1/notifications');
      final envelope = res.data as Map<String, dynamic>;
      final raw = (envelope['data'] as List<dynamic>? ?? []);
      state = state.copyWith(
        isLoading: false,
        items: raw
            .map((e) => _NotifItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void markRead(String id) {
    state = state.copyWith(
      items: state.items
          .map((n) => n.id == id
              ? (_NotifItem(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  type: n.type,
                  category: n.category,
                  createdAt: n.createdAt,
                  isRead: true))
              : n)
          .toList(),
    );
  }

  void markAllRead() {
    state = state.copyWith(
      items: state.items
          .map((n) => _NotifItem(
                id: n.id,
                title: n.title,
                body: n.body,
                type: n.type,
                category: n.category,
                createdAt: n.createdAt,
                isRead: true,
              ))
          .toList(),
    );
  }
}

final _notifProvider =
    StateNotifierProvider.autoDispose<_NotifNotifier, _NotifState>(
        (ref) => _NotifNotifier(ref.watch(dioProvider)));

// ── Page ──────────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_notifProvider);
    final notifier = ref.read(_notifProvider.notifier);
    final all = state.items;
    final unread = all.where((n) => !n.isRead).toList();
    final alerts = all
        .where((n) => n.type == 'alert' || n.type == 'security')
        .toList();
    final system = all.where((n) => n.type == 'system').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: notifier.markAllRead,
              child: Text('Mark all read',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: notifier.load,
            tooltip: 'Refresh',
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
                  if (unread.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusRound),
                      ),
                      child: Text('${unread.length}',
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
      body: state.isLoading && all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && all.isEmpty
              ? _buildError(state.error!, notifier.load)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(all, notifier),
                    _buildList(alerts, notifier),
                    _buildList(system, notifier),
                  ],
                ),
    );
  }

  Widget _buildError(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.error, size: 48),
          const SizedBox(height: AppDimensions.md),
          const Text('Could not load notifications',
              style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.xs),
          Text(error,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.md),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<_NotifItem> items, _NotifNotifier notifier) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppDimensions.md),
            const Text('No notifications', style: AppTextStyles.titleMedium),
            Text("You're all caught up!",
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimensions.md),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.xs),
        itemBuilder: (context, i) => _NotifCard(
          notif: items[i],
          onTap: () => notifier.markRead(items[i].id),
        ),
      ),
    );
  }
}

// ── Notification Card ─────────────────────────────────────────────────────────

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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
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
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusRound),
                        ),
                        child: Text(
                          notif.category,
                          style: AppTextStyles.labelSmall.copyWith(
                              color: _typeColor, fontSize: 9),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo(notif.createdAt),
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
