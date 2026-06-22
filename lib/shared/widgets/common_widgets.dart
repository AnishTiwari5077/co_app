import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';

/// KPI stat card shown on dashboard.
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? subtitlePositive;
  final IconData icon;
  final Color iconColor;
  final Color? iconBg;
  final VoidCallback? onTap;
  final String? trend;
  final bool isTrendUp;
  final bool subtitlePositiveFlag;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.subtitlePositive,
    this.iconBg,
    this.onTap,
    this.trend,
    this.isTrendUp = true,
    this.subtitlePositiveFlag = true,
  });

  // Factory constructor matching old color= API
  const KpiCard.legacy({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required Color color,
    this.subtitle,
    this.subtitlePositive,
    this.iconBg,
    this.onTap,
    this.trend,
    this.isTrendUp = true,
    this.subtitlePositiveFlag = true,
  }) : iconColor = color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg ?? iconColor.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(icon,
                      color: iconColor, size: AppDimensions.iconLg),
                ),
                if (trend != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isTrendUp
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.error.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusRound),
                    ),
                    child: Text(
                      trend!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isTrendUp ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
                value,
                style: AppTextStyles.titleLarge
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(title,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: subtitlePositiveFlag
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w500,
                  )),
            ],
            if (subtitlePositive != null) ...[
              const SizedBox(height: 2),
              Text(subtitlePositive!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textDisabled)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header used on dashboard and list pages.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style:
                AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.primary)),
          ),
      ],
    );
  }
}

/// Loading state indicator used in async pages.
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Error state with retry button.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: AppColors.error.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state placeholder.
/// Supports both [title]+[subtitle] API and legacy [message] API.
class EmptyView extends StatelessWidget {
  final String? message;
  final String? title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyView({
    super.key,
    this.message,
    this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  }) : assert(message != null || title != null,
            'Either message or title must be provided');

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? message ?? '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text(
              displayTitle,
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textDisabled),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Info row used inside [InfoSection] detail cards.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDivider;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(label,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        if (isDivider)
          const Divider(height: 1, color: AppColors.outline),
      ],
    );
  }
}

/// Collapsible labelled info section containing [InfoRow]s.
class InfoSection extends StatelessWidget {
  final String title;
  final List<InfoRow> rows;

  const InfoSection({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.md, AppDimensions.md, AppDimensions.md, 0),
            child: Text(title, style: AppTextStyles.titleSmall),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }
}
