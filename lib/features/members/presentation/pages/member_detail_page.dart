import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/api/api_client.dart';
import 'package:dio/dio.dart';
import '../providers/member_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class MemberDetail {
  final String id, memberCode, firstName, lastName, fullName;
  final String? middleName, gender, dateOfBirthAd, citizenshipNumber;
  final String? panNumber, occupation, addressDistrict, addressMunicipality;
  final String? addressWard, addressTole, membershipDate;
  final String phoneNumber;
  final String? email;
  final String status;
  final bool kycVerified;
  final String? photoUrl;
  final String? citizenshipDocUrl;
  final String? signatureUrl;
  final List<SavingAccountSummary> savingAccounts;
  final List<LoanSummary> loans;
  final List<MemberNomineeSummary> nominees;

  MemberDetail({
    required this.id, required this.memberCode,
    required this.firstName, required this.lastName,
    this.middleName, this.gender, this.dateOfBirthAd,
    this.citizenshipNumber, this.panNumber,
    this.occupation, this.addressDistrict, this.addressMunicipality,
    this.addressWard, this.addressTole, this.membershipDate,
    required this.phoneNumber,
    this.email,
    required this.status, required this.kycVerified, this.photoUrl,
    this.citizenshipDocUrl, this.signatureUrl,
    required this.savingAccounts, required this.loans, required this.nominees,
  }) : fullName = [firstName, if (middleName != null && middleName.isNotEmpty) middleName, lastName].join(' ');

  factory MemberDetail.fromJson(Map<String, dynamic> j) => MemberDetail(
    id: j['id'] as String? ?? '',
    memberCode: j['memberCode'] as String? ?? '',
    firstName: j['firstName'] as String? ?? '',
    middleName: j['middleName'] as String?,
    lastName: j['lastName'] as String? ?? '',
    gender: j['gender'] as String?,
    dateOfBirthAd: j['dateOfBirthAd'] as String?,
    citizenshipNumber: j['citizenshipNumber'] as String?,
    panNumber: j['panNumber'] as String?,
    occupation: j['occupation'] as String?,
    addressDistrict: j['addressDistrict'] as String?,
    addressMunicipality: j['addressMunicipality'] as String?,
    addressWard: j['addressWard'] as String?,
    addressTole: j['addressTole'] as String?,
    membershipDate: j['membershipDate'] as String?,
    phoneNumber: j['phoneNumber'] as String? ?? '',
    email: j['email'] as String?,
    status: j['status'] as String? ?? 'Pending',
    kycVerified: j['kycVerified'] as bool? ?? false,
    photoUrl: j['photoUrl'] as String?,
    citizenshipDocUrl: j['citizenshipDocUrl'] as String?,
    signatureUrl: j['signatureUrl'] as String?,
    savingAccounts: (j['savingAccounts'] as List<dynamic>? ?? [])
        .map((e) => SavingAccountSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    loans: (j['loans'] as List<dynamic>? ?? [])
        .map((e) => LoanSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    nominees: (j['nominees'] as List<dynamic>? ?? [])
        .map((e) => MemberNomineeSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class SavingAccountSummary {
  final String id, accountNumber, status;
  final double balance;
  SavingAccountSummary({required this.id, required this.accountNumber, required this.balance, required this.status});
  factory SavingAccountSummary.fromJson(Map<String, dynamic> j) => SavingAccountSummary(
    id: j['id'] as String? ?? '',
    accountNumber: j['accountNumber'] as String? ?? '',
    balance: (j['balance'] as num?)?.toDouble() ?? 0,
    status: j['status'] as String? ?? 'Active',
  );
}

class LoanSummary {
  final String id, loanNumber, status;
  final double outstanding;
  LoanSummary({required this.id, required this.loanNumber, required this.outstanding, required this.status});
  factory LoanSummary.fromJson(Map<String, dynamic> j) => LoanSummary(
    id: j['id'] as String? ?? '',
    loanNumber: j['loanNumber'] as String? ?? '',
    outstanding: (j['outstanding'] as num?)?.toDouble() ?? 0,
    status: j['status'] as String? ?? 'Active',
  );
}

class MemberNomineeSummary {
  final String? fullName, relationship, phoneNumber;
  MemberNomineeSummary({this.fullName, this.relationship, this.phoneNumber});
  factory MemberNomineeSummary.fromJson(Map<String, dynamic> j) => MemberNomineeSummary(
    fullName: j['fullName'] as String?,
    relationship: j['relationship'] as String?,
    phoneNumber: j['phoneNumber'] as String?,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final memberDetailProvider = FutureProvider.autoDispose
    .family<MemberDetail, String>((ref, memberId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/v1/members/$memberId');
  final envelope = response.data as Map<String, dynamic>;
  final data = envelope['data'] as Map<String, dynamic>? ?? envelope;
  return MemberDetail.fromJson(data);
});

// ── Page ──────────────────────────────────────────────────────────────────────

class MemberDetailPage extends ConsumerStatefulWidget {
  final String memberId;
  const MemberDetailPage({super.key, required this.memberId});

  @override
  ConsumerState<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends ConsumerState<MemberDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isActivating = false;
  bool _isUpdatingStatus = false;

  Future<void> _activateMember(String memberId) async {
    setState(() => _isActivating = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/v1/members/$memberId/approve');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Member activated successfully!'),
              ],
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(memberDetailProvider(memberId));
        ref.invalidate(memberListProvider);        // ← list reflects new status instantly
        ref.invalidate(dashboardSummaryProvider);  // ← dashboard KPIs update
        ref.invalidate(dashboardActivityProvider); // ← pending approvals update
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = (e.response?.data as Map<String, dynamic>?)?['message']
                as String? ??
            'Failed to activate member';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  Future<void> _updateMemberStatus(
      String memberId, String action, String? reason) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/v1/members/$memberId/status',
          data: {'action': action, 'reason': reason});
      if (mounted) {
        final label = action == 'suspend'
            ? 'Suspended'
            : action == 'reactivate'
                ? 'Reactivated'
                : 'Deactivated';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('Member $label successfully!'),
            ]),
            backgroundColor: action == 'reactivate'
                ? AppColors.secondary
                : AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(memberDetailProvider(memberId));
        ref.invalidate(memberListProvider);
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(dashboardActivityProvider);
      }
    } on DioException catch (e) {
      if (mounted) {
        final errBody = e.response?.data;
        final msg = errBody is Map
            ? (errBody['error']?['message'] ?? errBody['message'] ?? 'Failed to update status')
            : 'Failed to update status';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _showStatusConfirm(MemberDetail member, String action) async {
    final needsReason = action == 'suspend' || action == 'deactivate';
    final reasonCtrl = TextEditingController();

    final (title, body, icon, color) = switch (action) {
      'suspend' => (
          'Suspend Member',
          'This member will no longer be able to perform transactions until reactivated.',
          Icons.pause_circle_outline_rounded,
          AppColors.accent,
        ),
      'reactivate' => (
          'Reactivate Member',
          'This member will be restored to Active status and can perform transactions again.',
          Icons.play_circle_outline_rounded,
          AppColors.secondary,
        ),
      _ => (
          'Deactivate Member',
          'This will permanently set the member as Inactive. This action cannot easily be undone. The member must have no active savings or loans.',
          Icons.block_rounded,
          AppColors.error,
        ),
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.titleMedium),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: AppTextStyles.bodySmall),
            if (needsReason) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Enter reason...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(title),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _updateMemberStatus(
          member.id, action, needsReason ? reasonCtrl.text.trim() : null);
    }
    reasonCtrl.dispose();
  }

  Future<void> _deleteMember(MemberDetail member) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/api/v1/members/${member.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Member deleted successfully.'),
            ]),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(memberListProvider);
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(dashboardActivityProvider);
        if (mounted) context.pop(); // Navigate back to member list
      }
    } on DioException catch (e) {
      if (mounted) {
        final errBody = e.response?.data;
        final msg = errBody is Map
            ? (errBody['error']?['message'] ??
                errBody['message'] ??
                'Failed to delete member')
            : 'Failed to delete member';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _showDeleteConfirm(MemberDetail member) async {
    final confirmCtrl = TextEditingController();
    bool canConfirm = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.delete_forever_rounded,
                color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            const Text('Delete Member',
                style: TextStyle(color: AppColors.error)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is irreversible. The member record will be permanently removed from the system.',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Text(
                  'Only members with status Pending or Inactive and no financial history can be deleted.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              const Text('Type DELETE to confirm:',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: confirmCtrl,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  errorText: confirmCtrl.text.isNotEmpty &&
                          confirmCtrl.text != 'DELETE'
                      ? 'Type exactly: DELETE'
                      : null,
                ),
                onChanged: (v) => setLocal(() => canConfirm = v == 'DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: canConfirm
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      ),
    );

    confirmCtrl.dispose();
    if (confirmed == true && mounted) {
      await _deleteMember(member);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(memberDetailProvider(widget.memberId));

    return memberAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: AppDimensions.md),
              const Text('Failed to load member', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimensions.xs),
              Text('$e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppDimensions.md),
              TextButton.icon(
                onPressed: () => ref.invalidate(memberDetailProvider(widget.memberId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (member) => Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerScrolled) => [
            _buildSliverHeader(member),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: AppTextStyles.labelLarge,
                  tabs: const [
                    Tab(text: 'Profile'),
                    Tab(text: 'Savings'),
                    Tab(text: 'Loans'),
                    Tab(text: 'Shares'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _ProfileTab(member: member),
              _SavingsTab(accounts: member.savingAccounts),
              _LoansTab(loans: member.loans, memberId: member.id),
              const _SharesTab(),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverHeader(MemberDetail member) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        // Show Activate button only for Pending members
        if (member.status == 'Pending')
          _isActivating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : TextButton.icon(
                  onPressed: () => _showActivateConfirm(member),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white, size: 18),
                  label: const Text('Activate',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          tooltip: 'Edit Member',
          onPressed: () async {
            await context.push('/members/${member.id}/edit');
            // Refresh detail page after edit
            ref.invalidate(memberDetailProvider(member.id));
          },
        ),
        PopupMenuButton<String>(
          icon: (_isUpdatingStatus)
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'activate') _showActivateConfirm(member);
            if (value == 'suspend') _showStatusConfirm(member, 'suspend');
            if (value == 'reactivate') _showStatusConfirm(member, 'reactivate');
            if (value == 'deactivate') _showStatusConfirm(member, 'deactivate');
            if (value == 'delete') _showDeleteConfirm(member);
          },
          itemBuilder: (ctx) => [
            if (member.status == 'Pending')
              const PopupMenuItem(
                  value: 'activate',
                  child: ListTile(
                    leading: Icon(Icons.check_circle_rounded,
                        color: AppColors.secondary),
                    title: Text('Activate Member'),
                    contentPadding: EdgeInsets.zero,
                  )),
            if (member.status == 'Active')
              const PopupMenuItem(
                  value: 'suspend',
                  child: ListTile(
                    leading: Icon(Icons.pause_circle_outline_rounded,
                        color: AppColors.accent),
                    title: Text('Suspend Member'),
                    contentPadding: EdgeInsets.zero,
                  )),
            if (member.status == 'Suspended' || member.status == 'Inactive')
              const PopupMenuItem(
                  value: 'reactivate',
                  child: ListTile(
                    leading: Icon(Icons.play_circle_outline_rounded,
                        color: AppColors.secondary),
                    title: Text('Reactivate Member'),
                    contentPadding: EdgeInsets.zero,
                  )),
            if (member.status != 'Inactive')
              const PopupMenuItem(
                  value: 'deactivate',
                  child: ListTile(
                    leading:
                        Icon(Icons.block_rounded, color: AppColors.error),
                    title: Text('Deactivate Member',
                        style: TextStyle(color: AppColors.error)),
                    contentPadding: EdgeInsets.zero,
                  )),
            // Delete — only for Pending or Inactive with no financial history
            if (member.status == 'Pending' || member.status == 'Inactive') ...[
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_forever_rounded,
                        color: AppColors.error),
                    title: Text('Delete Member',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700)),
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md, 56, AppDimensions.md, AppDimensions.md),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      child: member.photoUrl != null
                          ? Image.network(
                              '${AppConfig.baseUrl}${member.photoUrl}',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 36),
                            )
                          : const Icon(Icons.person_rounded,
                              color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.fullName,
                            style: AppTextStyles.headlineSmall.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(member.memberCode,
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
                              ),
                              child: Text(member.status,
                                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                            ),
                            if (member.kycVerified) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
                                ),
                                child: Text('KYC ✓',
                                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                      ],
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

  void _showActivateConfirm(MemberDetail member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.secondary),
            SizedBox(width: 8),
            Text('Activate Member'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to activate:',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            Text(member.fullName,
                style: AppTextStyles.titleSmall
                    .copyWith(color: AppColors.primary)),
            Text(member.memberCode,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This will set their status to Active and allow them to use all cooperative services.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.secondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _activateMember(member.id);
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Activate'),
          ),
        ],
      ),
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final MemberDetail member;
  const _ProfileTab({required this.member});

  @override
  Widget build(BuildContext context) {
    // Build full address string
    final addressParts = [
      if (member.addressTole != null) member.addressTole!,
      if (member.addressWard != null) 'Ward ${member.addressWard}',
      if (member.addressMunicipality != null) member.addressMunicipality!,
      if (member.addressDistrict != null) member.addressDistrict!,
    ];

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        // ── Personal Information ───────────────────────────────────────────
        _InfoSection(title: 'Personal Information', rows: [
          InfoRow(label: 'Full Name', value: member.fullName),
          if (member.gender != null) InfoRow(label: 'Gender', value: member.gender!),
          if (member.dateOfBirthAd != null) InfoRow(label: 'Date of Birth (AD)', value: member.dateOfBirthAd!),
          if (member.occupation != null) InfoRow(label: 'Occupation', value: member.occupation!),
        ]),
        const SizedBox(height: AppDimensions.md),

        // ── Contact Information ────────────────────────────────────────────
        _InfoSection(title: 'Contact Information', rows: [
          InfoRow(label: 'Phone', value: member.phoneNumber),
          if (member.email != null && member.email!.isNotEmpty)
            InfoRow(label: 'Email', value: member.email!),
        ]),

        // ── Address ───────────────────────────────────────────────────────
        if (addressParts.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.md),
          _InfoSection(title: 'Permanent Address', rows: [
            if (member.addressDistrict != null)
              InfoRow(label: 'District', value: member.addressDistrict!),
            if (member.addressMunicipality != null)
              InfoRow(label: 'Municipality / VDC', value: member.addressMunicipality!),
            if (member.addressWard != null)
              InfoRow(label: 'Ward No.', value: member.addressWard!),
            if (member.addressTole != null)
              InfoRow(label: 'Tole', value: member.addressTole!),
          ]),
        ],

        // ── Identity Documents ────────────────────────────────────────────
        if (member.citizenshipNumber != null || member.panNumber != null) ...[
          const SizedBox(height: AppDimensions.md),
          _InfoSection(title: 'Identity Documents', rows: [
            if (member.citizenshipNumber != null && member.citizenshipNumber!.isNotEmpty)
              InfoRow(label: 'Citizenship No.', value: member.citizenshipNumber!),
            if (member.panNumber != null && member.panNumber!.isNotEmpty)
              InfoRow(label: 'PAN Number', value: member.panNumber!),
          ]),
        ],

        // ── Uploaded Documents ────────────────────────────────────────────
        const SizedBox(height: AppDimensions.md),
        _MemberDocumentsSection(member: member),

        // ── Membership Details ────────────────────────────────────────────
        const SizedBox(height: AppDimensions.md),
        _InfoSection(title: 'Membership Details', rows: [
          InfoRow(label: 'Member Code', value: member.memberCode),
          InfoRow(label: 'Status', value: member.status),
          InfoRow(label: 'KYC Status', value: member.kycVerified ? 'Verified ✓' : 'Pending'),
          if (member.membershipDate != null && member.membershipDate!.isNotEmpty)
            InfoRow(label: 'Membership Date', value: member.membershipDate!.split('T').first),
        ]),

        // ── Nominee Information ───────────────────────────────────────────
        if (member.nominees.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.md),
          _InfoSection(title: 'Nominee Information', rows: [
            if (member.nominees.first.fullName != null)
              InfoRow(label: 'Nominee Name', value: member.nominees.first.fullName!),
            if (member.nominees.first.relationship != null)
              InfoRow(label: 'Relationship', value: member.nominees.first.relationship!),
            if (member.nominees.first.phoneNumber != null)
              InfoRow(label: 'Nominee Phone', value: member.nominees.first.phoneNumber!),
          ]),
        ],

        const SizedBox(height: AppDimensions.xxl),
      ],
    );
  }
}

// ── Savings Tab ───────────────────────────────────────────────────────────────

class _SavingsTab extends StatelessWidget {
  final List<SavingAccountSummary> accounts;
  const _SavingsTab({required this.accounts});

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: AppDimensions.sm),
            Text('No savings accounts', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: accounts.map((a) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Material(
            color: AppColors.surface,
            child: InkWell(
              onTap: () => context.push('/savings/${a.id}'),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8EDF3)),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: const Icon(Icons.savings_rounded, color: AppColors.secondary, size: 20),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Savings Account', style: AppTextStyles.titleSmall),
                              Text(a.accountNumber,
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        StatusBadge(status: a.status),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text('NPR ${_fmt(a.balance)}',
                              style: AppTextStyles.amountMedium
                                  .copyWith(color: AppColors.secondary)),
                        ),
                        if (a.status == 'Active')
                          Text('Tap to open & close account',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )).toList(),
    );
  }

  String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)} L';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final dec = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i != 0 && (intPart.length - i) % 2 == 0 && intPart.length > 3) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${buf.toString()}.$dec';
  }
}

// ── Loans Tab ─────────────────────────────────────────────────────────────────

class _LoansTab extends StatelessWidget {
  final List<LoanSummary> loans;
  final String memberId;
  const _LoansTab({required this.loans, required this.memberId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        // Apply Loan button
        OutlinedButton.icon(
          onPressed: () => context.push('/loans/apply?memberId=$memberId'),
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('Apply Loan for this Member'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        if (loans.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: AppDimensions.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_outlined,
                      size: 48,
                      color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: AppDimensions.sm),
                  Text('No loans yet',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          )
        else
          ...loans.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: GestureDetector(
              onTap: () => context.push('/loans/${l.id}'),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  border: Border.all(color: const Color(0xFFE8EDF3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: const Icon(Icons.account_balance_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Loan', style: AppTextStyles.titleSmall),
                              Text(l.loanNumber,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        StatusBadge(status: l.status),
                        const SizedBox(width: AppDimensions.xs),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Outstanding',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary)),
                            Text('NPR ${l.outstanding.toStringAsFixed(2)}',
                                style: AppTextStyles.amountSmall),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )),
      ],
    );
  }
}

// ── Shares Tab (static for now — no backend endpoint yet) ────────────────────

class _SharesTab extends StatelessWidget {
  const _SharesTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: AppDimensions.sm),
          Text('Share data not available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String title;
  final List<InfoRow> rows;
  const _InfoSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Text(title, style: AppTextStyles.titleSmall),
          ),
          const Divider(height: 1),
          ...rows.map((r) => r),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

// ── Member Documents Section ─────────────────────────────────────────────────

class _MemberDocumentsSection extends ConsumerStatefulWidget {
  final MemberDetail member;
  const _MemberDocumentsSection({required this.member});

  @override
  ConsumerState<_MemberDocumentsSection> createState() =>
      _MemberDocumentsSectionState();
}

class _MemberDocumentsSectionState
    extends ConsumerState<_MemberDocumentsSection> {
  // Track uploading state per docType
  final _uploading = <String, bool>{};
  // Local override URLs after upload
  String? _localPhotoUrl;
  String? _localCitizenshipUrl;
  String? _localSignatureUrl;

  String? _effectiveUrl(String docType) {
    switch (docType) {
      case 'photo':       return _localPhotoUrl       ?? widget.member.photoUrl;
      case 'citizenship': return _localCitizenshipUrl  ?? widget.member.citizenshipDocUrl;
      case 'signature':   return _localSignatureUrl    ?? widget.member.signatureUrl;
    }
    return null;
  }

  Future<void> _upload(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final file = result.files.first;

    setState(() => _uploading[docType] = true);
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'docType': docType,
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
      });
      final res = await dio.post(
          '/api/v1/members/${widget.member.id}/upload-document',
          data: formData);
      final url = (res.data as Map<String, dynamic>?)?['data']?['url'] as String?;
      if (url != null && mounted) {
        setState(() {
          switch (docType) {
            case 'photo':       _localPhotoUrl       = url; break;
            case 'citizenship': _localCitizenshipUrl  = url; break;
            case 'signature':   _localSignatureUrl    = url; break;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Document uploaded successfully!'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(docType));
    }
  }

  Future<void> _view(String docType) async {
    final baseUrl = AppConfig.baseUrl;
    final url = _effectiveUrl(docType);
    if (url == null) return;
    final fullUrl = '$baseUrl$url';
    final isPdf = url.toLowerCase().endsWith('.pdf');

    if (!mounted) return;
    if (isPdf) {
      // For PDFs, try to open externally
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot open PDF. Try a different viewer.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // For images, show in-app dialog
    final docs = [
      _DocEntry('Citizenship Certificate', 'citizenship', Icons.badge_outlined, AppColors.primary),
      _DocEntry('Passport-size Photo', 'photo', Icons.photo_camera_outlined, AppColors.secondary),
      _DocEntry('Digital Signature', 'signature', Icons.draw_outlined, const Color(0xFF7C3AED)),
    ];
    final label = docs.firstWhere((d) => d.type == docType,
        orElse: () => _DocEntry(docType, docType, Icons.image_outlined, AppColors.primary)).label;

    showDialog(
      context: context,
      builder: (ctx) {
        final screenH = MediaQuery.of(ctx).size.height;
        final screenW = MediaQuery.of(ctx).size.width;
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            // Fixed concrete size — required so Expanded works
            height: screenH * 0.82,
            width: screenW * 0.88,
            child: Column(
              // max fills the SizedBox, so Expanded can divide the space
              mainAxisSize: MainAxisSize.max,
              children: [
                // ── Header bar ───────────────────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xCC000000),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.image_outlined,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                // ── Image — Expanded fills exact remaining height ────────
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      fullUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                      errorBuilder: (_, __, ___) => const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded,
                                color: Colors.white38, size: 56),
                            SizedBox(height: 12),
                            Text('Could not load image',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = [
      _DocEntry('Citizenship Certificate', 'citizenship', Icons.badge_outlined, AppColors.primary),
      _DocEntry('Passport-size Photo', 'photo', Icons.photo_camera_outlined, AppColors.secondary),
      _DocEntry('Digital Signature', 'signature', Icons.draw_outlined, const Color(0xFF7C3AED)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.folder_open_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('Uploaded Documents',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
        ]),
        const SizedBox(height: AppDimensions.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: const Color(0xFFE8EDF3)),
          ),
          child: Column(
            children: List.generate(docs.length, (i) {
              final doc = docs[i];
              final url = _effectiveUrl(doc.type);
              final hasFile = url != null;
              final isUploading = _uploading[doc.type] == true;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hasFile
                              ? doc.color.withValues(alpha: 0.12)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: Icon(
                          hasFile ? Icons.check_circle_rounded : doc.icon,
                          color: hasFile ? doc.color : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.label, style: AppTextStyles.bodyMedium),
                            Text(
                              hasFile ? 'Uploaded' : 'Not uploaded',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: hasFile
                                      ? AppColors.secondary
                                      : AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isUploading)
                        const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                      else ...
                        [
                          if (hasFile)
                            IconButton(
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 20, color: AppColors.primary),
                              tooltip: 'View',
                              onPressed: () => _view(doc.type),
                              visualDensity: VisualDensity.compact,
                            ),
                          IconButton(
                            icon: Icon(
                              hasFile
                                  ? Icons.upload_rounded
                                  : Icons.cloud_upload_outlined,
                              size: 20,
                              color:
                                  hasFile ? AppColors.accent : AppColors.primary,
                            ),
                            tooltip: hasFile ? 'Replace' : 'Upload',
                            onPressed: () => _upload(doc.type),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                    ]),
                  ),
                  if (i < docs.length - 1)
                    const Divider(height: 1, indent: AppDimensions.md),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _DocEntry {
  final String label, type;
  final IconData icon;
  final Color color;
  const _DocEntry(this.label, this.type, this.icon, this.color);
}
