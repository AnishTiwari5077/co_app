import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _biometrics = false;
  bool _pushNotifications = true;
  bool _emiReminders = true;
  bool _largeTransactionAlerts = true;
  bool _nightlyReports = false;
  bool _darkMode = false;
  String _language = 'English';
  String _fiscalYearDisplay = 'Nepali (BS)';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Profile header
          _buildProfileHeader(user?.fullName ?? 'Branch Manager'),

          // Account section
          const _SectionTitle('Account'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'My Profile',
            subtitle: user?.fullName ?? 'View and edit profile',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update your login password',
            onTap: () => _showChangePasswordSheet(),
          ),
          _SettingsTile(
            icon: Icons.fingerprint_rounded,
            title: 'Biometric Login',
            subtitle: 'Fingerprint / Face ID',
            trailing: Switch.adaptive(
              value: _biometrics,
              onChanged: (v) => setState(() => _biometrics = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.pin_rounded,
            title: 'Set PIN',
            subtitle: 'Quick access 4-digit PIN',
            onTap: () {},
          ),

          // Notifications
          const _SectionTitle('Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            trailing: Switch.adaptive(
              value: _pushNotifications,
              onChanged: (v) => setState(() => _pushNotifications = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.schedule_rounded,
            title: 'EMI Due Reminders',
            subtitle: '3 days before due date',
            trailing: Switch.adaptive(
              value: _emiReminders,
              onChanged: (v) => setState(() => _emiReminders = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.warning_amber_rounded,
            title: 'Large Transaction Alerts',
            subtitle: 'Transactions over NPR 1,00,000',
            trailing: Switch.adaptive(
              value: _largeTransactionAlerts,
              onChanged: (v) => setState(() => _largeTransactionAlerts = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.summarize_rounded,
            title: 'Nightly Reports',
            subtitle: 'Daily EOD summary via email',
            trailing: Switch.adaptive(
              value: _nightlyReports,
              onChanged: (v) => setState(() => _nightlyReports = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            onTap: null,
          ),

          // Appearance
          const _SectionTitle('Appearance & Language'),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            trailing: Switch.adaptive(
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: _language,
            onTap: () => _showLanguagePicker(),
          ),
          _SettingsTile(
            icon: Icons.calendar_today_outlined,
            title: 'Date Format',
            subtitle: _fiscalYearDisplay,
            onTap: () => _showDateFormatPicker(),
          ),

          // System
          const _SectionTitle('System'),
          _SettingsTile(
            icon: Icons.cloud_sync_rounded,
            title: 'Sync Data',
            subtitle: 'Last synced: 15 Ashad 2081, 3:45 PM',
            onTap: () => _triggerSync(),
          ),
          _SettingsTile(
            icon: Icons.history_rounded,
            title: 'Audit Log',
            subtitle: 'View your activity history',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.backup_rounded,
            title: 'Data Backup',
            subtitle: 'Backup & restore settings',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.manage_accounts_rounded,
            title: 'User Management',
            subtitle: 'Manage staff access and roles',
            onTap: () {},
          ),

          // About
          const _SectionTitle('About'),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: 'SahakariMS v1.0.0 (Build 1)',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'FAQs, documentation',
            onTap: () {},
          ),

          // Logout
          const SizedBox(height: AppDimensions.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: Text('Sign Out',
                  style: AppTextStyles.buttonText
                      .copyWith(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding:
                    const EdgeInsets.symmetric(vertical: AppDimensions.md),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.xxl),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: AppTextStyles.headlineMedium
                    .copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleLarge),
                const SizedBox(height: 2),
                Text('Branch Manager',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary)),
                const SizedBox(height: 2),
                Text('Kathmandu Head Office',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  void _showChangePasswordSheet() {
    final currentCtrl  = TextEditingController();
    final newCtrl      = TextEditingController();
    final confirmCtrl  = TextEditingController();
    final formKey      = GlobalKey<FormState>();
    bool loading       = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              AppDimensions.lg,
              AppDimensions.lg,
              AppDimensions.lg,
              MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.lg),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Change Password', style: AppTextStyles.titleLarge),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: currentCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: newCtrl,
                  decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_reset_rounded)),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: confirmCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.verified_outlined)),
                  obscureText: true,
                  validator: (v) => v != newCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: AppDimensions.lg),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => loading = true);
                      // Capture messenger before async gap
                      final messenger = ScaffoldMessenger.of(context);
                      final router = GoRouter.of(context);
                      try {
                        final dio = ref.read(dioProvider);
                        await dio.post(
                          ApiEndpoints.changePassword,
                          data: {
                            'currentPassword': currentCtrl.text,
                            'newPassword': newCtrl.text,
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Password changed successfully! Please login again.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Force logout — tokens revoked on server
                        await ref.read(authStateProvider.notifier).logout();
                        router.go(AppRoutes.login);
                      } catch (e) {
                        setModalState(() => loading = false);
                        String msg = 'Failed to change password.';
                        if (e is DioException) {
                          msg = e.response?.data?['error']?['message'] as String? ?? msg;
                        }
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(msg), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update Password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Language'),
        content: DropdownButton<String>(
          value: _language,
          isExpanded: true,
          items: ['English', 'नेपाली (Nepali)']
              .map((lang) => DropdownMenuItem(
                    value: lang,
                    child: Text(lang),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _language = v);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _showDateFormatPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Date Format'),
        content: DropdownButton<String>(
          value: _fiscalYearDisplay,
          isExpanded: true,
          items: ['Nepali (BS)', 'English (AD)', 'Both']
              .map((fmt) => DropdownMenuItem(
                    value: fmt,
                    child: Text(fmt),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _fiscalYearDisplay = v);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _triggerSync() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Syncing data...',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
            'Are you sure you want to sign out? All local data will be cleared.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
              context.go(AppRoutes.login);
            },
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.lg, AppDimensions.md, AppDimensions.xs),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            title: Text(title, style: AppTextStyles.bodyMedium),
            subtitle: subtitle != null
                ? Text(subtitle!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary))
                : null,
            trailing: trailing ??
                (onTap != null
                    ? const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary)
                    : null),
            onTap: onTap,
          ),
          const Divider(height: 1, indent: 56),
        ],
      ),
    );
  }
}
