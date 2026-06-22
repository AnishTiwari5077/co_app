import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';

/// Variant enum exposed as [ButtonVariant] for the full app.
enum ButtonVariant { primary, outlined, secondary, danger, text }

// Backward-compat alias
typedef AppButtonVariant = ButtonVariant;

/// Primary action button for SahakariMS.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonVariant variant;
  final double? width;
  final double? height;
  final Color? color;
  final bool isSmall;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.width,
    this.height,
    this.color,
    this.isSmall = false,
  });

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.color,
    this.isSmall = false,
  }) : variant = ButtonVariant.outlined;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.color,
    this.isSmall = false,
  }) : variant = ButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.isSmall = false,
  })  : variant = ButtonVariant.danger,
        color = null;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.color,
    this.isSmall = false,
  }) : variant = ButtonVariant.text;

  double get _resolvedHeight {
    if (height != null) return height!;
    return isSmall ? 36 : AppDimensions.buttonHeight;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? _defaultColor;

    return SizedBox(
      width: width,
      height: _resolvedHeight,
      child: switch (variant) {
        ButtonVariant.primary   => _buildElevated(effectiveColor),
        ButtonVariant.secondary => _buildElevated(AppColors.secondary),
        ButtonVariant.outlined  => _buildOutlined(effectiveColor),
        ButtonVariant.danger    => _buildElevated(AppColors.error),
        ButtonVariant.text      => _buildText(effectiveColor),
      },
    );
  }

  Color get _defaultColor => switch (variant) {
    ButtonVariant.primary   => AppColors.primary,
    ButtonVariant.secondary => AppColors.secondary,
    ButtonVariant.outlined  => AppColors.primary,
    ButtonVariant.danger    => AppColors.error,
    ButtonVariant.text      => AppColors.primary,
  };

  Widget _buildElevated(Color bgColor) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: bgColor,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: isSmall
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 0)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
    ),
    onPressed: isLoading ? null : onPressed,
    child: _buildChild(Colors.white),
  );

  Widget _buildOutlined(Color borderColor) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: borderColor,
      padding: isSmall
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 0)
          : null,
      side: BorderSide(color: borderColor, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
    ),
    onPressed: isLoading ? null : onPressed,
    child: _buildChild(borderColor),
  );

  Widget _buildText(Color textColor) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: textColor,
      padding: isSmall
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 0)
          : null,
    ),
    onPressed: isLoading ? null : onPressed,
    child: _buildChild(textColor),
  );

  Widget _buildChild(Color contentColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: contentColor),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmall ? 14 : 18, color: contentColor),
          SizedBox(width: isSmall ? 4 : 8),
          Text(label,
              style: (isSmall
                      ? AppTextStyles.labelLarge
                      : AppTextStyles.buttonText)
                  .copyWith(color: contentColor)),
        ],
      );
    }
    return Text(label,
        style: (isSmall ? AppTextStyles.labelLarge : AppTextStyles.buttonText)
            .copyWith(color: contentColor));
  }
}
