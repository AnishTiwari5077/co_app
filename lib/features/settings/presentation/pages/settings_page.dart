import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

const _kPhoneKey = 'user_phone';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _pushNotifications = true;
  bool _emiReminders = true;
  bool _largeTransactionAlerts = true;
  bool _nightlyReports = false;

  // ── helpers ──────────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  // ── build ─────────────────────────────────────────────────────────────────────

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
          // ── Profile header ──────────────────────────────────────────────────
          _buildProfileHeader(user),

          // ── Account ─────────────────────────────────────────────────────────
          const _SectionTitle('Account'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'My Profile',
            subtitle: user?.fullName ?? 'View and edit profile',
            onTap: () => _showEditProfileSheet(user),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update your login password',
            onTap: () => _showChangePasswordSheet(),
          ),

          // ── Notifications ───────────────────────────────────────────────────
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

          // ── About ───────────────────────────────────────────────────────────
          const _SectionTitle('About'),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: 'SahakariMS v1.0.0 (Build 1)',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Email or call us',
            onTap: () => _showHelpSupportDialog(),
          ),

          // ── Sign Out ────────────────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.xxl),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileHeader(user) {
    final name = user?.fullName ?? 'Branch Manager';
    final role = (user?.roles?.isNotEmpty ?? false)
        ? user!.roles.first
        : 'Branch Manager';
    final branch = user?.branchName ?? 'Head Office';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: AppTextStyles.headlineMedium
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _showEditProfileSheet(user),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleLarge),
                const SizedBox(height: 2),
                Text(role,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(branch,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            onPressed: () => _showEditProfileSheet(user),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDIT MY PROFILE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showEditProfileSheet(dynamic user) async {
    // Load phone synchronously BEFORE showing the sheet — avoids the
    // TextEditingController-disposed race of a .then() callback.
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString(_kPhoneKey) ?? '';

    if (!mounted) return;

    final fullNameCtrl =
        TextEditingController(text: user?.fullName as String? ?? '');
    final emailCtrl = TextEditingController(text: user?.email as String? ?? '');
    final phoneCtrl = TextEditingController(text: storedPhone);
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusXl)),
          ),
          padding: EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.lg,
            MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.lg,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  const Row(
                    children: [
                      Icon(Icons.person_rounded, color: AppColors.primary),
                      SizedBox(width: AppDimensions.sm),
                      Text('Edit Profile', style: AppTextStyles.titleLarge),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.lg),

                  // Avatar preview (live initials)
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.only(bottom: AppDimensions.lg),
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: fullNameCtrl,
                          builder: (_, val, __) {
                            final t = val.text.trim();
                            return Text(
                              t.isNotEmpty ? _initials(t) : 'U',
                              style: AppTextStyles.headlineMedium
                                  .copyWith(color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Full name
                  TextFormField(
                    controller: fullNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 3) return 'Minimum 3 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.sm),

                  // Email
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w+$')
                          .hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.sm),

                  // Phone (local only)
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      prefixText: '+977 ',
                      helperText: 'Stored locally on this device',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length != 10) {
                        return 'Enter 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.md),

                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: Text(
                            'Username and branch are managed by your administrator.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton.icon(
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: Text(loading ? 'Saving…' : 'Save Changes'),
                      onPressed: loading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModal(() => loading = true);

                              // Snapshot text values before any await gap
                              final newName = fullNameCtrl.text.trim();
                              final newEmail = emailCtrl.text.trim();
                              final newPhone = phoneCtrl.text.trim();

                              try {
                                // Write all fields to SharedPreferences
                                final p = await SharedPreferences.getInstance();
                                await p.setString('user_full_name', newName);
                                await p.setString('user_email', newEmail);
                                await p.setString(_kPhoneKey, newPhone);

                                // Refresh the in-memory Riverpod auth state
                                await ref
                                    .read(authStateProvider.notifier)
                                    .reloadFromPrefs();

                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Profile updated successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModal(() => loading = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: AppColors.error));
                                }
                              }
                            },
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

  // ═══════════════════════════════════════════════════════════════════════════
  // CHANGE PASSWORD
  // ═══════════════════════════════════════════════════════════════════════════

  void _showChangePasswordSheet() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusXl)),
          ),
          padding: EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.lg,
            MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppDimensions.md),
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: AppColors.primary),
                    SizedBox(width: AppDimensions.sm),
                    Text('Change Password', style: AppTextStyles.titleLarge),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: currentCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
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
                  validator: (v) =>
                      v != newCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: AppDimensions.lg),
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => loading = true);
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
                                  content: Text(
                                      'Password changed successfully! Please login again.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              await ref
                                  .read(authStateProvider.notifier)
                                  .logout();
                              router.go(AppRoutes.login);
                            } catch (e) {
                              setModalState(() => loading = false);
                              String msg = 'Failed to change password.';
                              if (e is DioException) {
                                msg = e.response?.data?['error']?['message']
                                        as String? ??
                                    msg;
                              }
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                    content: Text(msg),
                                    backgroundColor: Colors.red));
                              }
                            }
                          },
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
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

  void _triggerSync() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Syncing data…',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHelpSupportDialog() {
    const email = 'anishtiwari5077@gmail.com';
    const phone = '9861982615';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: AppColors.primary),
            SizedBox(width: AppDimensions.sm),
            Text('Help & Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For assistance, reach us via email or phone:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Email row
            InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: email));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email copied to clipboard'),
                    backgroundColor: AppColors.primary,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.email_outlined,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          Text(email,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                    Icon(Icons.copy_rounded,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.sm),

            // Phone row
            InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: phone));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Phone number copied to clipboard'),
                    backgroundColor: AppColors.primary,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone_outlined,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Phone',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          Text(phone,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                    Icon(Icons.copy_rounded,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

// ══════════════════════════════════════════════════════════════════════════════
// Supporting widgets
// ══════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimensions.md, AppDimensions.lg,
          AppDimensions.md, AppDimensions.xs),
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
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
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
