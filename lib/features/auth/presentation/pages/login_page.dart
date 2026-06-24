import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final AnimationController _anim;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _anim.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = ref.read(authStateProvider.notifier);
    final success = await auth.login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ── Left Panel ─────────────────────────────────────────────────────
          if (size.width > AppDimensions.breakpointMd)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary, AppColors.secondary],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLogo(light: true),
                        const Spacer(),
                        Text('Cooperative\nManagement\nSystem',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Trusted by 100+ cooperatives in Nepal.\nBuilt for SACCOS. Built for growth.',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        _buildFeatureList(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Right Panel ─────────────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SingleChildScrollView(
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (size.width <= AppDimensions.breakpointMd) ...[
                              _buildLogo(light: false),
                              const SizedBox(height: 40),
                            ] else
                              const SizedBox(height: 60),

                            const Text('Welcome back', style: AppTextStyles.headlineLarge),
                            const SizedBox(height: 8),
                            Text('Sign in to your SahakariMS account',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 36),

                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppTextField(
                                    label: 'Username or Email',
                                    controller: _usernameCtrl,
                                    prefixIcon: Icons.person_outline,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofocus: true,
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Username is required'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  AppPasswordField(
                                    controller: _passwordCtrl,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Password is required'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _showForgotPasswordDialog(),
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  if (auth.error != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              auth.error!,
                                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  AppButton(
                                    label: 'Sign In',
                                    onPressed: _submit,
                                    isLoading: auth.isLoading,
                                    width: double.infinity,
                                    icon: Icons.login,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),
                            _buildVersion(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: AppDimensions.md),
              const Text('Forgot Password?',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'Password reset is managed by your system administrator.\n\nPlease contact your branch admin or head office to reset your password.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimensions.lg),
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'Admin can reset passwords from:\nSettings → User Management',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK, Got It'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo({required bool light}) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: light ? Colors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.account_balance,
            color: light ? Colors.white : AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SahakariMS',
          style: AppTextStyles.titleLarge.copyWith(
            color: light ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureList() {
    const features = [
      'Member management & KYC',
      'Loan lifecycle & NPA tracking',
      'Savings & Fixed deposits',
      'Double-entry accounting',
      'COPOMIS & PEARLS compliance',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Text(f, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildVersion() {
    return Text(
      'SahakariMS v1.0.0\nNepal Cooperative Management System',
      textAlign: TextAlign.center,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDisabled),
    );
  }
}
