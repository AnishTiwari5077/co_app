import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';

/// Status badge chip for Members, Loans, Savings accounts.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool compact;
  /// When shown on a colored (dark) background — uses lighter colors
  final bool isLight;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.isLight = false,
  });

  static const Map<String, _BadgeStyle> _styles = {
    'Active':      _BadgeStyle(AppColors.statusActive, Color(0xFFDCFCE7)),
    'Pending':     _BadgeStyle(AppColors.statusPending, Color(0xFFFFF7ED)),
    'Approved':    _BadgeStyle(AppColors.statusActive, Color(0xFFDCFCE7)),
    'Disbursed':   _BadgeStyle(Color(0xFF0369A1), Color(0xFFE0F2FE)),
    'Suspended':   _BadgeStyle(AppColors.statusSuspended, Color(0xFFFFE4E6)),
    'Inactive':    _BadgeStyle(AppColors.statusClosed, Color(0xFFF1F5F9)),
    'Closed':      _BadgeStyle(AppColors.statusClosed, Color(0xFFF1F5F9)),
    'Overdue':     _BadgeStyle(AppColors.loanOverdue, Color(0xFFFFF0E5)),
    'Rejected':    _BadgeStyle(AppColors.statusRejected, Color(0xFFFCE7F3)),
    'Frozen':      _BadgeStyle(Color(0xFF0EA5E9), Color(0xFFE0F2FE)),
    'Dormant':     _BadgeStyle(Color(0xFF7C3AED), Color(0xFFF3F0FF)),
    'UnderReview': _BadgeStyle(AppColors.statusPending, Color(0xFFFFF7ED)),
    'Draft':       _BadgeStyle(AppColors.textSecondary, Color(0xFFF1F5F9)),
    'Posted':      _BadgeStyle(AppColors.statusActive, Color(0xFFDCFCE7)),
    'Watchlist':   _BadgeStyle(AppColors.warning, Color(0xFFFFFBEB)),
    'NPA':         _BadgeStyle(AppColors.npaRed, Color(0xFFFFE4E6)),
    'Standard':    _BadgeStyle(AppColors.statusActive, Color(0xFFDCFCE7)),
  };

  @override
  Widget build(BuildContext context) {
    if (isLight) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
          border: Border.all(color: Colors.white30),
        ),
        child: Text(
          _formatStatus(status),
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final style = _styles[status] ??
        const _BadgeStyle(AppColors.textSecondary, Color(0xFFF1F5F9));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Text(
        _formatStatus(status),
        style: AppTextStyles.labelSmall.copyWith(
          color: style.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatStatus(String s) => switch (s) {
        'UnderReview' => 'Under Review',
        _ => s,
      };
}

class _BadgeStyle {
  final Color fg;
  final Color bg;
  const _BadgeStyle(this.fg, this.bg);
}

/// NPA classification badge (coloured severity)
class NpaBadge extends StatelessWidget {
  final String classification;
  const NpaBadge({super.key, required this.classification});

  @override
  Widget build(BuildContext context) => StatusBadge(status: classification);
}

/// Amount display widget with credit/debit colouring.
class AmountDisplay extends StatelessWidget {
  final double amount;
  final bool isCredit;
  final bool showSign;
  final bool compact;
  final TextStyle? style;

  const AmountDisplay({
    super.key,
    required this.amount,
    required this.isCredit,
    this.showSign = true,
    this.compact = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCredit ? AppColors.creditAmount : AppColors.debitAmount;
    final sign = showSign ? (isCredit ? '+' : '-') : '';
    final text = compact
        ? '$sign NPR ${_compact(amount)}'
        : '$sign NPR ${_format(amount)}';

    return Text(
      text,
      style: (style ?? AppTextStyles.bodyMedium).copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _format(double v) {
    final parts = v.abs().toStringAsFixed(2).split('.');
    final integer = parts[0];
    final decimal = parts[1];
    final buf = StringBuffer();
    final chars = integer.split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0) {
        if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) buf.write(',');
      }
      buf.write(chars[i]);
    }
    return '${buf.toString().split('').reversed.join()}.$decimal';
  }

  String _compact(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
