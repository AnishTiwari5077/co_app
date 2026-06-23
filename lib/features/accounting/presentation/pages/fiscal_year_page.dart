import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/api/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class FiscalYear {
  final String id, yearCode;
  final String startDate, endDate;
  final bool isCurrent, isClosed;
  final String? closedAt;

  FiscalYear({
    required this.id,
    required this.yearCode,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.isClosed,
    this.closedAt,
  });

  factory FiscalYear.fromJson(Map<String, dynamic> j) => FiscalYear(
        id: j['id'] as String? ?? '',
        yearCode: j['yearCode'] as String? ?? '',
        startDate: j['startDate'] as String? ?? '',
        endDate: j['endDate'] as String? ?? '',
        isCurrent: j['isCurrent'] as bool? ?? false,
        isClosed: j['isClosed'] as bool? ?? false,
        closedAt: j['closedAt'] as String?,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _fiscalYearsProvider =
    FutureProvider.autoDispose<List<FiscalYear>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/accounting/fiscal-years');
  final data =
      (res.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
  return data
      .map((e) => FiscalYear.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Page ──────────────────────────────────────────────────────────────────────

class FiscalYearPage extends ConsumerStatefulWidget {
  const FiscalYearPage({super.key});

  @override
  ConsumerState<FiscalYearPage> createState() => _FiscalYearPageState();
}

class _FiscalYearPageState extends ConsumerState<FiscalYearPage> {
  bool _isSubmitting = false;

  Future<void> _openAddDialog() async {
    final yearCodeCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Fiscal Year', style: AppTextStyles.titleMedium),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yearCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Year Code',
                  hintText: 'e.g. 2083-84',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Start Date (YYYY-MM-DD)',
                  hintText: 'e.g. 2026-07-16',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2050),
                  );
                  if (picked != null) {
                    startCtrl.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  }
                },
                readOnly: true,
              ),
              const SizedBox(height: AppDimensions.sm),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: 'End Date (YYYY-MM-DD)',
                  hintText: 'e.g. 2027-07-15',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2050),
                  );
                  if (picked != null) {
                    endCtrl.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  }
                },
                readOnly: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (yearCodeCtrl.text.trim().isEmpty ||
                  startCtrl.text.isEmpty ||
                  endCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _createFiscalYear(
                yearCodeCtrl.text.trim(),
                startCtrl.text,
                endCtrl.text,
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFiscalYear(
      String yearCode, String start, String end) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/v1/accounting/fiscal-years', data: {
        'yearCode': yearCode,
        'startDate': start,
        'endDate': end,
      });
      ref.invalidate(_fiscalYearsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fiscal Year $yearCode created'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _setCurrent(FiscalYear fy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set as Current Year'),
        content: Text(
          'Set "${fy.yearCode}" as the active fiscal year?\n\nAll new journal entries will be posted to this year.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/v1/accounting/fiscal-years/${fy.id}/set-current');
      ref.invalidate(_fiscalYearsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${fy.yearCode} is now the active fiscal year'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _close(FiscalYear fy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Fiscal Year',
            style: TextStyle(color: AppColors.error)),
        content: Text(
          '⚠️ Close "${fy.yearCode}"?\n\nThis will LOCK the year — no new entries can be posted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Year'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/v1/accounting/fiscal-years/${fy.id}/close');
      ref.invalidate(_fiscalYearsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${fy.yearCode} has been closed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_fiscalYearsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fiscal Years', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Fiscal Year',
              onPressed: _openAddDialog,
            ),
        ],
      ),
      body: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Failed to load fiscal years',
                  style: AppTextStyles.titleSmall),
              const SizedBox(height: 4),
              Text(e.toString(), style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.invalidate(_fiscalYearsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (years) {
          if (years.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text('No fiscal years added yet',
                      style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),
                  Text('Tap + to create the first fiscal year',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Add Fiscal Year',
                    onPressed: _openAddDialog,
                    icon: Icons.add_rounded,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.md),
            itemCount: years.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppDimensions.sm),
            itemBuilder: (_, i) {
              final fy = years[i];
              return _FiscalYearCard(
                fy: fy,
                onSetCurrent:
                    fy.isClosed || fy.isCurrent ? null : () => _setCurrent(fy),
                onClose: fy.isClosed ? null : () => _close(fy),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Fiscal Year'),
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _FiscalYearCard extends StatelessWidget {
  final FiscalYear fy;
  final VoidCallback? onSetCurrent;
  final VoidCallback? onClose;

  const _FiscalYearCard({required this.fy, this.onSetCurrent, this.onClose});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (fy.isClosed) {
      statusColor = AppColors.error;
      statusText = 'Closed';
      statusIcon = Icons.lock_rounded;
    } else if (fy.isCurrent) {
      statusColor = AppColors.secondary;
      statusText = 'Active';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = AppColors.textSecondary;
      statusText = 'Inactive';
      statusIcon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: fy.isCurrent
              ? AppColors.secondary.withValues(alpha: 0.4)
              : fy.isClosed
                  ? AppColors.error.withValues(alpha: 0.2)
                  : const Color(0xFFE8EDF3),
          width: fy.isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(Icons.calendar_month_rounded,
                    color: statusColor, size: 22),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fy.yearCode, style: AppTextStyles.titleMedium),
                    Text(
                      '${fy.startDate}  →  ${fy.endDate}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusText,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          if (fy.isClosed && fy.closedAt != null) ...[
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Closed on ${fy.closedAt!.split('T').first}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          if (onSetCurrent != null || onClose != null) ...[
            const SizedBox(height: AppDimensions.sm),
            const Divider(height: 1),
            const SizedBox(height: AppDimensions.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onSetCurrent != null)
                  OutlinedButton.icon(
                    onPressed: onSetCurrent,
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16),
                    label: const Text('Set as Current'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                    ),
                  ),
                if (onSetCurrent != null && onClose != null)
                  const SizedBox(width: AppDimensions.sm),
                if (onClose != null)
                  OutlinedButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.lock_outline_rounded, size: 16),
                    label: const Text('Close Year'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
