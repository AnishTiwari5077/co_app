import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/api/api_client.dart';
import 'member_detail_page.dart';

/// Edit page for updating a member's profile information.
class MemberEditPage extends ConsumerStatefulWidget {
  final String memberId;
  const MemberEditPage({super.key, required this.memberId});

  @override
  ConsumerState<MemberEditPage> createState() => _MemberEditPageState();
}

class _MemberEditPageState extends ConsumerState<MemberEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _saving = false;

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _toleCtrl = TextEditingController();
  final _citizenshipCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  String? _gender;

  static const _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _occupationCtrl.dispose();
    _districtCtrl.dispose();
    _municipalityCtrl.dispose();
    _wardCtrl.dispose();
    _toleCtrl.dispose();
    _citizenshipCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMember() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/v1/members/${widget.memberId}');
      final env = res.data as Map<String, dynamic>;
      final j = (env['data'] as Map<String, dynamic>?) ?? {};
      _firstNameCtrl.text = j['firstName'] as String? ?? '';
      _middleNameCtrl.text = j['middleName'] as String? ?? '';
      _lastNameCtrl.text = j['lastName'] as String? ?? '';
      _phoneCtrl.text = j['phoneNumber'] as String? ?? '';
      _emailCtrl.text = j['email'] as String? ?? '';
      _dobCtrl.text = j['dateOfBirthAd'] as String? ?? '';
      _occupationCtrl.text = j['occupation'] as String? ?? '';
      _districtCtrl.text = j['addressDistrict'] as String? ?? '';
      _municipalityCtrl.text = j['addressMunicipality'] as String? ?? '';
      _wardCtrl.text = j['addressWard'] as String? ?? '';
      _toleCtrl.text = j['addressTole'] as String? ?? '';
      _citizenshipCtrl.text = j['citizenshipNumber'] as String? ?? '';
      _panCtrl.text = j['panNumber'] as String? ?? '';
      final g = j['gender'] as String?;
      if (g != null && _genders.contains(g)) _gender = g;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load member: $e'),
          backgroundColor: AppColors.error,
        ));
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/v1/members/${widget.memberId}', data: {
        'firstName': _firstNameCtrl.text.trim(),
        'middleName': _middleNameCtrl.text.trim().isEmpty
            ? null
            : _middleNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'gender': _gender,
        'dateOfBirthAd':
            _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
        'occupation': _occupationCtrl.text.trim().isEmpty
            ? null
            : _occupationCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'addressDistrict': _districtCtrl.text.trim().isEmpty
            ? null
            : _districtCtrl.text.trim(),
        'addressMunicipality': _municipalityCtrl.text.trim().isEmpty
            ? null
            : _municipalityCtrl.text.trim(),
        'addressWard':
            _wardCtrl.text.trim().isEmpty ? null : _wardCtrl.text.trim(),
        'addressTole':
            _toleCtrl.text.trim().isEmpty ? null : _toleCtrl.text.trim(),
        'citizenshipNumber': _citizenshipCtrl.text.trim().isEmpty
            ? null
            : _citizenshipCtrl.text.trim(),
        'panNumber': _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
      });
      // Invalidate provider so detail page refreshes
      ref.invalidate(memberDetailProvider(widget.memberId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Member updated successfully!'),
          ]),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ));
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        String msg = 'Failed to update member';
        if (data is Map<String, dynamic>) {
          msg = data['error']?['message'] as String? ??
              data['message'] as String? ??
              msg;
        } else if (data is String && data.trim().isNotEmpty) {
          msg = data.trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Member', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save'),
              style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.md),
                children: [
                  _Section(title: 'Personal Information', children: [
                    _row([
                      _field('First Name *', _firstNameCtrl, required: true),
                      _field('Middle Name', _middleNameCtrl),
                    ]),
                    const SizedBox(height: AppDimensions.sm),
                    _field('Last Name *', _lastNameCtrl, required: true),
                    const SizedBox(height: AppDimensions.sm),
                    _genderDropdown(),
                    const SizedBox(height: AppDimensions.sm),
                    _field('Date of Birth (YYYY-MM-DD)', _dobCtrl,
                        hint: 'e.g. 1990-05-15',
                        keyboard: TextInputType.datetime),
                    const SizedBox(height: AppDimensions.sm),
                    _field('Occupation', _occupationCtrl),
                  ]),
                  const SizedBox(height: AppDimensions.md),
                  _Section(title: 'Contact Information', children: [
                    _field('Phone Number *', _phoneCtrl,
                        required: true, keyboard: TextInputType.phone),
                    const SizedBox(height: AppDimensions.sm),
                    _field('Email', _emailCtrl,
                        keyboard: TextInputType.emailAddress),
                  ]),
                  const SizedBox(height: AppDimensions.md),
                  _Section(title: 'Permanent Address', children: [
                    _field('District', _districtCtrl),
                    const SizedBox(height: AppDimensions.sm),
                    _field('Municipality / VDC', _municipalityCtrl),
                    const SizedBox(height: AppDimensions.sm),
                    _row([
                      _field('Ward No.', _wardCtrl,
                          keyboard: TextInputType.number),
                      _field('Tole', _toleCtrl),
                    ]),
                  ]),
                  const SizedBox(height: AppDimensions.md),
                  _Section(title: 'Identity Documents', children: [
                    _field('Citizenship Number', _citizenshipCtrl),
                    const SizedBox(height: AppDimensions.sm),
                    _field('PAN Number', _panCtrl),
                  ]),
                  const SizedBox(height: AppDimensions.xxl),
                ],
              ),
            ),
    );
  }

  Widget _row(List<Widget> children) => Row(
        children: children
            .map((w) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: children.last == w ? 0 : AppDimensions.sm),
                    child: w,
                  ),
                ))
            .toList(),
      );

  Widget _genderDropdown() => DropdownButtonFormField<String>(
        initialValue: _gender,
        decoration: _inputDec('Gender'),
        items: [
          const DropdownMenuItem(value: null, child: Text('— Select —')),
          ..._genders.map((g) => DropdownMenuItem(value: g, child: Text(g))),
        ],
        onChanged: (v) => setState(() => _gender = v),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    String? hint,
    TextInputType keyboard = TextInputType.text,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: _inputDec(label, hint: hint),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      );

  InputDecoration _inputDec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: 14),
        isDense: true,
      );
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
          const Divider(height: AppDimensions.lg),
          ...children,
        ],
      ),
    );
  }
}
