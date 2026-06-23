import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/member_provider.dart';
import '../../../../core/api/repositories/member_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../core/api/api_client.dart';

class MemberRegistrationPage extends ConsumerStatefulWidget {
  const MemberRegistrationPage({super.key});

  @override
  ConsumerState<MemberRegistrationPage> createState() =>
      _MemberRegistrationPageState();
}

class _MemberRegistrationPageState
    extends ConsumerState<MemberRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _firstNameNpCtrl = TextEditingController();
  final _lastNameNpCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _citizenshipCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _toleCtrl = TextEditingController();
  final _nomineeNameCtrl = TextEditingController();
  final _nomineeRelationCtrl = TextEditingController();
  final _nomineePhoneCtrl = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedOccupation = 'Business';
  String _selectedEducation = 'Bachelor\'s Degree';

  // Document file selections (picked locally before upload)
  PlatformFile? _citizenshipFile;
  PlatformFile? _photoFile;
  PlatformFile? _signatureFile;

  final _genders = ['Male', 'Female', 'Other'];
  final _occupations = ['Business', 'Agriculture', 'Service', 'Teacher', 'Doctor', 'Other'];
  final _educations = ['Below SLC', 'SLC', 'Intermediate', 'Bachelor\'s Degree', 'Master\'s Degree', 'PhD'];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _firstNameNpCtrl.dispose();
    _lastNameNpCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _citizenshipCtrl.dispose();
    _panCtrl.dispose();
    _districtCtrl.dispose();
    _municipalityCtrl.dispose();
    _wardCtrl.dispose();
    _toleCtrl.dispose();
    _nomineeNameCtrl.dispose();
    _nomineeRelationCtrl.dispose();
    _nomineePhoneCtrl.dispose();
    super.dispose();
  }


  String? _parseDateSafe(String raw) {
    if (raw.isEmpty) return null;
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) ? raw : null;
  }

  Future<void> _submitForm() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in First Name and Last Name'),
          backgroundColor: Colors.red));
      return;
    }
    if (phone.isEmpty || phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
          backgroundColor: Colors.red));
      return;
    }
    final branchId = ref.read(authStateProvider).user?.branchId ?? '';
    if (branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Branch not found. Please re-login.'),
          backgroundColor: Colors.red));
      return;
    }
    final request = RegisterMemberRequest(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phone,
      gender: _selectedGender,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      dateOfBirthAd: _parseDateSafe(_dobCtrl.text.trim()),
      occupation: _selectedOccupation.isEmpty ? null : _selectedOccupation,
      citizenshipNumber: _citizenshipCtrl.text.trim().isEmpty ? null : _citizenshipCtrl.text.trim(),
      addressDistrict: _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
      addressMunicipality: _municipalityCtrl.text.trim().isEmpty ? null : _municipalityCtrl.text.trim(),
      addressWard: _wardCtrl.text.trim().isEmpty ? null : _wardCtrl.text.trim(),
      addressTole: _toleCtrl.text.trim().isEmpty ? null : _toleCtrl.text.trim(),
      branchId: branchId,
    );
    final success = await ref.read(registerMemberProvider.notifier).submit(request);
    if (mounted) {
      setState(() {});
      if (success) {
        final memberId = ref.read(registerMemberProvider).newMemberId ?? '';
        // Upload any selected documents in background
        if (memberId.isNotEmpty) {
          _uploadDocuments(memberId);
        }
        _showSuccessDialog(memberId);
        ref.invalidate(memberListProvider);
        ref.invalidate(dashboardSummaryProvider);
      } else {
        final error = ref.read(registerMemberProvider).error ?? 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _uploadDocuments(String memberId) async {
    final dio = ref.read(dioProvider);
    final docs = [
      if (_citizenshipFile != null) ('citizenship', _citizenshipFile!),
      if (_photoFile != null) ('photo', _photoFile!),
      if (_signatureFile != null) ('signature', _signatureFile!),
    ];
    for (final (docType, file) in docs) {
      try {
        final formData = FormData.fromMap({
          'docType': docType,
          'file': await MultipartFile.fromFile(
            file.path!,
            filename: file.name,
          ),
        });
        await dio.post('/api/v1/members/$memberId/upload-document', data: formData);
      } catch (_) {
        // silent — documents can be uploaded later from member detail
      }
    }
  }
  void _showSuccessDialog(String memberId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.md),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.secondary, size: 40),
            ),
            const SizedBox(height: AppDimensions.md),
            const Text('Registration Successful!', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
              Text(
                memberId.isNotEmpty
                    ? 'Member registered. ID: ${memberId.substring(0, 8).toUpperCase()}\nPending manager approval.'
                    : 'Member has been registered.\nPending manager approval.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: AppDimensions.lg),
            AppButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Member Registration', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: _buildCurrentStep(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Personal', 'Contact', 'Identity', 'Nominee'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _currentStep = i),
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.secondary
                              : isActive
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16)
                              : Text('${i + 1}',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  )),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[i],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: isDone ? AppColors.secondary : AppColors.surfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: [
          _buildPersonalStep(),
          _buildContactStep(),
          _buildIdentityStep(),
          _buildNomineeStep(),
        ][_currentStep],
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Column(
      key: const ValueKey('personal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Personal Information', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _firstNameCtrl,
                label: 'First Name *',
                hint: 'Ram',
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: AppTextField(
                controller: _lastNameCtrl,
                label: 'Last Name *',
                hint: 'Shrestha',
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _firstNameNpCtrl,
                label: 'First Name (Nepali)',
                hint: 'à¤°à¤¾à¤®',
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: AppTextField(
                controller: _lastNameNpCtrl,
                label: 'Last Name (Nepali)',
                hint: 'à¤¶à¥à¤°à¥‡à¤·à¥à¤ ',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _dobCtrl,
          label: 'Date of Birth (AD)',
          hint: '1990-06-15  (yyyy-MM-dd)',
          prefixIcon: Icons.calendar_today_rounded,
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: AppDimensions.sm),
        // Gender
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gender *', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimensions.xs),
            Row(
              children: _genders.map((g) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: g != _genders.last ? AppDimensions.xs : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.sm),
                        decoration: BoxDecoration(
                          color: _selectedGender == g
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd),
                          border: Border.all(
                            color: _selectedGender == g
                                ? AppColors.primary
                                : const Color(0xFFE0E7EF),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            g,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: _selectedGender == g
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        // Occupation
        _DropdownField(
          label: 'Occupation',
          value: _selectedOccupation,
          items: _occupations,
          onChanged: (v) => setState(() => _selectedOccupation = v!),
        ),
        const SizedBox(height: AppDimensions.sm),
        _DropdownField(
          label: 'Education',
          value: _selectedEducation,
          items: _educations,
          onChanged: (v) => setState(() => _selectedEducation = v!),
        ),
      ],
    );
  }

  Widget _buildContactStep() {
    return Column(
      key: const ValueKey('contact'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contact Information', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        AppTextField(
          controller: _phoneCtrl,
          label: 'Primary Phone *',
          hint: '9841000001',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v?.isEmpty == true) return 'Required';
            if (v!.length != 10) return 'Must be 10 digits';
            return null;
          },
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _emailCtrl,
          label: 'Email Address',
          hint: 'ram@email.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppDimensions.lg),
        const Text('Permanent Address', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        AppTextField(
          controller: _districtCtrl,
          label: 'District *',
          hint: 'Kathmandu',
          validator: (v) => v?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _municipalityCtrl,
          label: 'Municipality / VDC *',
          hint: 'Kathmandu Metropolitan City',
          validator: (v) => v?.isEmpty == true ? 'Required' : null,
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: AppTextField(
                controller: _wardCtrl,
                label: 'Ward No.',
                hint: '5',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: _toleCtrl,
                label: 'Tole',
                hint: 'Maharajgunj',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdentityStep() {
    return Column(
      key: const ValueKey('identity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Identity Documents', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        AppTextField(
          controller: _citizenshipCtrl,
          label: 'Citizenship Number',
          hint: 'XX-XX-XX-XXXXX',
          validator: null,
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _panCtrl,
          label: 'PAN Number',
          hint: 'XXXXXXXXX',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppDimensions.lg),
        const Text('Upload Documents', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.md),
        _DocumentUploadCard(
          label: 'Citizenship Certificate',
          icon: Icons.badge_outlined,
          selectedFile: _citizenshipFile,
          onPicked: (f) => setState(() => _citizenshipFile = f),
        ),
        const SizedBox(height: AppDimensions.sm),
        _DocumentUploadCard(
          label: 'Passport-size Photo',
          icon: Icons.photo_camera_outlined,
          selectedFile: _photoFile,
          onPicked: (f) => setState(() => _photoFile = f),
        ),
        const SizedBox(height: AppDimensions.sm),
        _DocumentUploadCard(
          label: 'Digital Signature',
          icon: Icons.draw_outlined,
          selectedFile: _signatureFile,
          onPicked: (f) => setState(() => _signatureFile = f),
        ),
      ],
    );
  }

  Widget _buildNomineeStep() {
    return Column(
      key: const ValueKey('nominee'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nominee Information', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.xs),
        Text(
          'Nominee will receive benefits in case of member\'s absence.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppDimensions.md),
        AppTextField(
          controller: _nomineeNameCtrl,
          label: 'Nominee Full Name',
          hint: 'Sita Shrestha',
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _nomineeRelationCtrl,
          label: 'Relationship',
          hint: 'Wife',
          prefixIcon: Icons.family_restroom_rounded,
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          controller: _nomineePhoneCtrl,
          label: 'Nominee Phone',
          hint: '9841000002',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: AppDimensions.md),
        // Review summary
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Registration Summary',
                      style: AppTextStyles.titleSmall
                          .copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'After submission, the application will be sent to the Branch Manager for KYC verification and approval. '
                'The member code will be generated automatically upon approval.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: AppButton(
                label: 'Back',
                onPressed: () => setState(() => _currentStep--),
                variant: ButtonVariant.outlined,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
          ],
          Expanded(
            flex: 2,
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(registerMemberProvider);
              return AppButton(
                label: _currentStep == 3 ? 'Submit Registration' : 'Next',
                onPressed: () {
                  if (_currentStep < 3) {
                    setState(() => _currentStep++);
                  } else {
                    _submitForm();
                  }
                },
                isLoading: state.isLoading,
                icon: _currentStep == 3 ? Icons.check_rounded : Icons.arrow_forward_rounded,
              );
            },
          ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Supporting widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DropdownField extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownField(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppDimensions.xs),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: 14),
          ),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}

class _DocumentUploadCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final PlatformFile? selectedFile;
  final ValueChanged<PlatformFile?> onPicked;

  const _DocumentUploadCard({
    required this.label,
    required this.icon,
    required this.selectedFile,
    required this.onPicked,
  });

  Future<void> _pick(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
        withData: false,
        withReadStream: false,
      );
      if (result != null && result.files.isNotEmpty) {
        onPicked(result.files.first);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = selectedFile != null;
    return GestureDetector(
      onTap: () => _pick(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: picked
              ? AppColors.secondary.withValues(alpha: 0.05)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: picked
                ? AppColors.secondary.withValues(alpha: 0.4)
                : const Color(0xFFE0E7EF),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: picked
                    ? AppColors.secondary.withValues(alpha: 0.1)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Icon(
                picked ? Icons.check_circle_rounded : icon,
                color: picked ? AppColors.secondary : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyMedium),
                  Text(
                    picked
                        ? selectedFile!.name
                        : 'Tap to select file (JPG, PNG, PDF)',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: picked ? AppColors.secondary : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (picked)
              GestureDetector(
                onTap: () => onPicked(null),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.error, size: 18),
                ),
              )
            else
              const Icon(Icons.upload_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
