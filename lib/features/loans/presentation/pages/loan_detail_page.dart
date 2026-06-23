import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class LoanGuarantorItem {
  final String memberName, memberCode;
  final double shareAmount;
  const LoanGuarantorItem({required this.memberName, required this.memberCode, required this.shareAmount});
  factory LoanGuarantorItem.fromJson(Map<String, dynamic> j) => LoanGuarantorItem(
    memberName: j['memberName'] as String? ?? '',
    memberCode: j['memberCode'] as String? ?? '',
    shareAmount: (j['shareAmount'] as num?)?.toDouble() ?? 0,
  );
}

class LoanCollateralItem {
  final String type, description;
  final double estimatedValue;
  const LoanCollateralItem({required this.type, required this.description, required this.estimatedValue});
  factory LoanCollateralItem.fromJson(Map<String, dynamic> j) => LoanCollateralItem(
    type: j['type'] as String? ?? '',
    description: j['description'] as String? ?? '',
    estimatedValue: (j['estimatedValue'] as num?)?.toDouble() ?? 0,
  );
}

class LoanDetail {
  final String id, loanNumber, memberName, memberCode, memberId;
  final String productName, loanType, interestType, status, branch;
  final double interestRate, processingFeePercent;
  final double appliedAmount, outstandingBalance, emiAmount;
  final double? approvedAmount, disbursedAmount;
  final double overdueAmount;
  final int tenureMonths, overdueDays, installmentsPaid, installmentsTotal;
  final String? loanPurpose, approvalRemarks;
  final String? appliedDate, approvedDate, disbursedDate, closedDate, nextEmiDate;
  final List<LoanGuarantorItem> guarantors;
  final List<LoanCollateralItem> collaterals;

  const LoanDetail({
    required this.id, required this.loanNumber, required this.memberName,
    required this.memberCode, required this.memberId, required this.productName,
    required this.loanType, required this.interestType, required this.status,
    required this.branch, required this.interestRate, required this.processingFeePercent,
    required this.appliedAmount, required this.outstandingBalance, required this.emiAmount,
    this.approvedAmount, this.disbursedAmount, required this.overdueAmount,
    required this.tenureMonths, required this.overdueDays,
    required this.installmentsPaid, required this.installmentsTotal,
    this.loanPurpose, this.approvalRemarks,
    this.appliedDate, this.approvedDate, this.disbursedDate,
    this.closedDate, this.nextEmiDate,
    required this.guarantors, required this.collaterals,
  });

  factory LoanDetail.fromJson(Map<String, dynamic> j) => LoanDetail(
    id: j['id'] as String? ?? '',
    loanNumber: j['loanNumber'] as String? ?? '',
    memberName: j['memberName'] as String? ?? '',
    memberCode: j['memberCode'] as String? ?? '',
    memberId: j['memberId'] as String? ?? '',
    productName: j['productName'] as String? ?? '',
    loanType: j['loanType'] as String? ?? 'Personal',
    interestType: j['interestType'] as String? ?? 'Diminishing',
    status: j['status'] as String? ?? '',
    branch: j['branch'] as String? ?? '',
    interestRate: (j['interestRate'] as num?)?.toDouble() ?? 0,
    processingFeePercent: (j['processingFeePercent'] as num?)?.toDouble() ?? 1,
    appliedAmount: (j['appliedAmount'] as num?)?.toDouble() ?? 0,
    outstandingBalance: (j['outstandingBalance'] as num?)?.toDouble() ?? 0,
    emiAmount: (j['emiAmount'] as num?)?.toDouble() ?? 0,
    approvedAmount: (j['approvedAmount'] as num?)?.toDouble(),
    disbursedAmount: (j['disbursedAmount'] as num?)?.toDouble(),
    overdueAmount: (j['overdueAmount'] as num?)?.toDouble() ?? 0,
    tenureMonths: j['tenureMonths'] as int? ?? 0,
    overdueDays: j['overdueDays'] as int? ?? 0,
    installmentsPaid: j['installmentsPaid'] as int? ?? 0,
    installmentsTotal: j['installmentsTotal'] as int? ?? 0,
    loanPurpose: j['loanPurpose'] as String?,
    approvalRemarks: j['approvalRemarks'] as String?,
    appliedDate: j['appliedDate'] as String?,
    approvedDate: j['approvedDate'] as String?,
    disbursedDate: j['disbursedDate'] as String?,
    closedDate: j['closedDate'] as String?,
    nextEmiDate: j['nextEmiDate'] as String?,
    guarantors: (j['guarantors'] as List<dynamic>? ?? [])
        .map((e) => LoanGuarantorItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    collaterals: (j['collaterals'] as List<dynamic>? ?? [])
        .map((e) => LoanCollateralItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  double get paidPercent {
    if (status != 'Active' && status != 'Closed') return 0;
    if (appliedAmount == 0) return 0;
    final principal = disbursedAmount ?? appliedAmount;
    if (principal == 0) return 0;
    return (1 - (outstandingBalance / principal)).clamp(0.0, 1.0);
  }
}

class EmiRow {
  final int no;
  final String dueDate;
  final double emi, principal, interest, balance;
  final String status;
  const EmiRow({required this.no, required this.dueDate, required this.emi,
    required this.principal, required this.interest, required this.balance,
    required this.status});
}

class PaymentItem {
  final String receipt, mode;
  final double total, principal, interest, penalty, balanceAfter;
  final DateTime date;
  final String? narration;
  const PaymentItem({required this.receipt, required this.mode, required this.total,
    required this.principal, required this.interest, required this.penalty,
    required this.balanceAfter, required this.date, this.narration});
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _loanDetailProvider = FutureProvider.autoDispose.family<LoanDetail, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/loans/$id');
  final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  return LoanDetail.fromJson(data);
});

final _loanScheduleProvider = FutureProvider.autoDispose.family<List<EmiRow>, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/loans/$id/schedule');
  final raw = (res.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
  return raw.map((e) {
    final m = e as Map<String, dynamic>;
    return EmiRow(
      no: m['installmentNo'] as int? ?? 0,
      dueDate: m['dueDate'] as String? ?? '',
      emi: (m['emiAmount'] as num?)?.toDouble() ?? 0,
      principal: (m['principalAmount'] as num?)?.toDouble() ?? 0,
      interest: (m['interestAmount'] as num?)?.toDouble() ?? 0,
      balance: (m['outstandingBalance'] as num?)?.toDouble() ?? 0,
      status: m['status'] as String? ?? 'Pending',
    );
  }).toList();
});

final _loanPaymentsProvider = FutureProvider.autoDispose.family<List<PaymentItem>, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/loans/$id/payments');
  final raw = (res.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
  return raw.map((e) {
    final m = e as Map<String, dynamic>;
    return PaymentItem(
      receipt: m['receiptNumber'] as String? ?? '',
      mode: m['paymentMode'] as String? ?? 'Cash',
      total: (m['totalPaid'] as num?)?.toDouble() ?? 0,
      principal: (m['principalPaid'] as num?)?.toDouble() ?? 0,
      interest: (m['interestPaid'] as num?)?.toDouble() ?? 0,
      penalty: (m['penaltyPaid'] as num?)?.toDouble() ?? 0,
      balanceAfter: (m['balanceAfter'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(m['paymentDate'] as String? ?? '') ?? DateTime.now(),
      narration: m['narration'] as String?,
    );
  }).toList();
});

// ── Page ──────────────────────────────────────────────────────────────────────

class LoanDetailPage extends ConsumerStatefulWidget {
  final String loanId;
  const LoanDetailPage({super.key, required this.loanId});

  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Approve ──────────────────────────────────────────────────────────────
  Future<void> _showApproveDialog(LoanDetail loan) async {
    final amtCtrl = TextEditingController(text: loan.appliedAmount.toStringAsFixed(0));
    final remarksCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: AppDimensions.md),
              const Text('Approve Loan', style: AppTextStyles.titleMedium),
              Text(loan.loanNumber, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Approved Amount (NPR)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.sm),
              TextFormField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Approval Remarks (optional)',
                  prefixIcon: Icon(Icons.comment_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Approve Loan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/v1/loans/${widget.loanId}/approve', data: {
        'approvedAmount': double.parse(amtCtrl.text.trim()),
        'remarks': remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
      });
      ref.invalidate(_loanDetailProvider(widget.loanId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Loan approved successfully!'),
          backgroundColor: AppColors.secondary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Disburse ─────────────────────────────────────────────────────────────
  Future<void> _showDisburseDialog(LoanDetail loan) async {
    final amtCtrl = TextEditingController(
        text: (loan.approvedAmount ?? loan.appliedAmount).toStringAsFixed(0));
    String mode = 'Cash';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: AppDimensions.md),
                const Text('Disburse Loan', style: AppTextStyles.titleMedium),
                Text(loan.loanNumber,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Disbursed Amount (NPR)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.sm),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                    labelText: 'Disbursement Mode',
                    prefixIcon: Icon(Icons.payment_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: ['Cash', 'Bank Transfer', 'Cheque']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setModalState(() => mode = v ?? 'Cash'),
                ),
                const SizedBox(height: AppDimensions.md),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text('This will generate the full EMI repayment schedule.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning))),
                  ]),
                ),
                const SizedBox(height: AppDimensions.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Disburse Loan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/v1/loans/${widget.loanId}/disburse', data: {
        'disbursedAmount': double.parse(amtCtrl.text.trim()),
        'mode': mode,
        'date': DateTime.now().toIso8601String().substring(0, 10),
      });
      ref.invalidate(_loanDetailProvider(widget.loanId));
      ref.invalidate(_loanScheduleProvider(widget.loanId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Loan disbursed! EMI schedule generated.'),
          backgroundColor: AppColors.secondary,
        ));
        _tabController.animateTo(1); // Jump to EMI Schedule tab
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Make Payment ─────────────────────────────────────────────────────────────
  Future<void> _showPaymentDialog(LoanDetail loan) async {
    // Find next pending EMI from the already-loaded schedule
    final scheduleAsync = ref.read(_loanScheduleProvider(widget.loanId));
    final schedule = scheduleAsync.valueOrNull ?? [];
    final nextEmi = schedule
        .where((e) => e.status == 'Pending' || e.status == 'Overdue')
        .toList()
      ..sort((a, b) => a.no.compareTo(b.no));
    final pendingEmi = nextEmi.isNotEmpty ? nextEmi.first : null;

    final amtCtrl = TextEditingController(
      text: (pendingEmi?.emi ?? loan.emiAmount).toStringAsFixed(0),
    );
    final narrationCtrl = TextEditingController();
    String mode = 'Cash';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: AppDimensions.md),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Collect EMI Payment', style: AppTextStyles.titleMedium),
                    Text(loan.loanNumber,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ]),
                ]),
                const SizedBox(height: AppDimensions.md),

                // ── Which EMI is being collected ──────────────────────────────
                if (pendingEmi != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Installment #', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        Text('EMI ${pendingEmi.no}',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: pendingEmi.status == 'Overdue' ? AppColors.error : AppColors.primary,
                              fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Due Date', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        Text(pendingEmi.dueDate,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: pendingEmi.status == 'Overdue' ? AppColors.error : AppColors.textPrimary)),
                      ]),
                      const Divider(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Principal', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        Text('NPR ${pendingEmi.principal.toStringAsFixed(0)}', style: AppTextStyles.bodySmall),
                      ]),
                      const SizedBox(height: 2),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Interest', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        Text('NPR ${pendingEmi.interest.toStringAsFixed(0)}', style: AppTextStyles.bodySmall),
                      ]),
                      const SizedBox(height: 2),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('EMI Amount', style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        Text('NPR ${pendingEmi.emi.toStringAsFixed(0)}',
                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
                      ]),
                    ]),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                      SizedBox(width: 8),
                      Text('No pending EMI — extra payment', style: AppTextStyles.bodySmall),
                    ]),
                  ),
                ],
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount (NPR)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null || double.parse(v) <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.sm),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode',
                    prefixIcon: Icon(Icons.payment_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: ['Cash', 'Bank Transfer', 'Cheque', 'Mobile Banking']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setModalState(() => mode = v ?? 'Cash'),
                ),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: narrationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Narration (optional)',
                    prefixIcon: Icon(Icons.comment_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(pendingEmi != null
                        ? 'Collect EMI #${pendingEmi.no}'
                        : 'Collect Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/api/v1/loans/${widget.loanId}/payment', data: {
        'amount': double.parse(amtCtrl.text.trim()),
        'paymentMode': mode,
        'paymentDate': DateTime.now().toUtc().toIso8601String(),
        'narration': narrationCtrl.text.trim().isEmpty ? null : narrationCtrl.text.trim(),
      });
      final respData = (res.data as Map<String, dynamic>?)?['data'] as Map<String, dynamic>?;
      final receipt = respData?['receiptNumber'] as String? ?? '';
      final balance = (respData?['outstandingBalance'] as num?)?.toDouble() ?? 0;
      final paidInstallment = respData?['installmentNo'] as int?;
      ref.invalidate(_loanDetailProvider(widget.loanId));
      ref.invalidate(_loanPaymentsProvider(widget.loanId));
      ref.invalidate(_loanScheduleProvider(widget.loanId));
      if (mounted) {
        _tabController.animateTo(2);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(paidInstallment != null
              ? '✓ EMI #$paidInstallment collected! Receipt: $receipt  •  Balance: NPR ${balance.toStringAsFixed(0)}'
              : 'Payment collected! Receipt: $receipt  •  Balance: NPR ${balance.toStringAsFixed(0)}'),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_loanDetailProvider(widget.loanId));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: AppDimensions.md),
            const Text('Could not load loan', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimensions.xs),
            Text(e.toString(), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimensions.md),
            TextButton.icon(
              onPressed: () => ref.invalidate(_loanDetailProvider(widget.loanId)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
        data: (loan) => Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (ctx, inner) => [
                _buildHeader(loan),
                _buildTabBar(),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(loan: loan),
                  _ScheduleTab(loanId: widget.loanId),
                  _PaymentsTab(loanId: widget.loanId),
                ],
              ),
            ),
            // ── Action bar (status-driven) ────────────────────────────────
            if (loan.status == 'Pending' || loan.status == 'Approved' || loan.status == 'Active')
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                      AppDimensions.md, AppDimensions.sm, AppDimensions.md, AppDimensions.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16, offset: const Offset(0, -4))],
                  ),
                  child: _actionLoading
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                      : loan.status == 'Pending'
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showApproveDialog(loan),
                                icon: const Icon(Icons.check_circle_rounded),
                                label: const Text('Approve Loan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            )
                          : loan.status == 'Approved'
                              ? Row(children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showApproveDialog(loan),
                                      icon: const Icon(Icons.edit_rounded, size: 16),
                                      label: const Text('Re-approve'),
                                    ),
                                  ),
                                  const SizedBox(width: AppDimensions.sm),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showDisburseDialog(loan),
                                      icon: const Icon(Icons.send_rounded),
                                      label: const Text('Disburse'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ])
                              : // Active
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showPaymentDialog(loan),
                                    icon: const Icon(Icons.payments_rounded),
                                    label: const Text('Collect EMI Payment'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildHeader(LoanDetail loan) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.schedule_rounded, color: Colors.white),
          onPressed: () => context.push('/loans/${widget.loanId}/schedule'),
          tooltip: 'EMI Schedule',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, Color(0xFF1E4D8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md, 56, AppDimensions.md, AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(loan.loanNumber,
                            style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                        Text(loan.memberName,
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                        Text(loan.productName,
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.white54)),
                      ]),
                    ),
                    StatusBadge(status: loan.status, isLight: true),
                  ]),
                  const SizedBox(height: AppDimensions.md),
                  Text(_fmtAmt(loan.disbursedAmount ?? loan.appliedAmount),
                      style: AppTextStyles.headlineLarge.copyWith(color: Colors.white)),
                  Text('Principal Amount',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white60)),
                  const SizedBox(height: AppDimensions.sm),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Outstanding: ${_fmtAmt(loan.outstandingBalance)}',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                      Text('${(loan.paidPercent * 100).toStringAsFixed(1)}% paid',
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white70)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: loan.paidPercent,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                        minHeight: 6,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'EMI Schedule'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
    );
  }

  String _fmtAmt(double v) {
    final s = v.toStringAsFixed(0);
    return 'NPR ${s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final LoanDetail loan;
  const _OverviewTab({required this.loan});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        // EMI info card
        if (loan.status == 'Active') ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: loan.overdueDays > 0
                  ? AppColors.error.withValues(alpha: 0.08)
                  : AppColors.secondary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                  color: loan.overdueDays > 0
                      ? AppColors.error.withValues(alpha: 0.25)
                      : AppColors.secondary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(
                loan.overdueDays > 0
                    ? Icons.warning_amber_rounded
                    : Icons.schedule_rounded,
                color: loan.overdueDays > 0 ? AppColors.error : AppColors.secondary,
                size: 32,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    loan.overdueDays > 0 ? 'EMI Overdue!' : 'Next EMI Due',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: loan.overdueDays > 0 ? AppColors.error : AppColors.secondary),
                  ),
                  Text(
                    _fmtAmt(loan.emiAmount),
                    style: AppTextStyles.headlineSmall.copyWith(
                        color: loan.overdueDays > 0 ? AppColors.error : AppColors.secondary),
                  ),
                  if (loan.nextEmiDate != null)
                    Text(loan.nextEmiDate!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  if (loan.overdueDays > 0)
                    Text('${loan.overdueDays} days overdue',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error,
                            fontWeight: FontWeight.w600)),
                ]),
              ),
              Text(
                '${loan.installmentsPaid}/${loan.installmentsTotal}\nEMI',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ]),
          ),
          const SizedBox(height: AppDimensions.md),
        ],

        // Loan details
        _InfoSection(title: 'Loan Details', rows: [
          InfoRow(label: 'Loan Number', value: loan.loanNumber),
          InfoRow(label: 'Loan Type', value: loan.loanType),
          InfoRow(label: 'Product', value: loan.productName),
          InfoRow(label: 'Applied Amount', value: _fmtAmt(loan.appliedAmount)),
          if (loan.approvedAmount != null)
            InfoRow(label: 'Approved Amount', value: _fmtAmt(loan.approvedAmount!)),
          if (loan.disbursedAmount != null)
            InfoRow(label: 'Disbursed Amount', value: _fmtAmt(loan.disbursedAmount!)),
          InfoRow(label: 'Processing Fee', value: '${loan.processingFeePercent}%'),
          InfoRow(label: 'Interest Rate', value: '${loan.interestRate}% p.a. (${loan.interestType})'),
          InfoRow(label: 'Tenure', value: '${loan.tenureMonths} months'),
          InfoRow(label: 'EMI Amount', value: _fmtAmt(loan.emiAmount)),
          if (loan.loanPurpose != null && loan.loanPurpose!.isNotEmpty)
            InfoRow(label: 'Purpose', value: loan.loanPurpose!),
          if (loan.appliedDate != null) InfoRow(label: 'Applied Date', value: loan.appliedDate!),
          if (loan.approvedDate != null) InfoRow(label: 'Approved Date', value: loan.approvedDate!),
          if (loan.disbursedDate != null) InfoRow(label: 'Disbursed Date', value: loan.disbursedDate!),
          if (loan.closedDate != null) InfoRow(label: 'Closed Date', value: loan.closedDate!),
          InfoRow(label: 'Branch', value: loan.branch),
        ]),
        const SizedBox(height: AppDimensions.md),

        // Outstanding
        _InfoSection(title: 'Outstanding Summary', rows: [
          InfoRow(label: 'Outstanding Balance', value: _fmtAmt(loan.outstandingBalance)),
          InfoRow(label: 'EMI Amount', value: _fmtAmt(loan.emiAmount)),
          InfoRow(label: 'Overdue Amount', value: loan.overdueAmount > 0 ? _fmtAmt(loan.overdueAmount) : '—'),
          InfoRow(label: 'Overdue Days', value: loan.overdueDays > 0 ? '${loan.overdueDays} days' : '—'),
          InfoRow(label: 'Installments Paid', value: '${loan.installmentsPaid} of ${loan.installmentsTotal}'),
          InfoRow(label: 'Installments Remaining', value: '${loan.installmentsTotal - loan.installmentsPaid}'),
        ]),

        // Guarantors
        if (loan.guarantors.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.md),
          _InfoSection(title: 'Guarantors', rows: [
            for (int i = 0; i < loan.guarantors.length; i++) ...[
              InfoRow(label: 'Guarantor ${i + 1}', value: loan.guarantors[i].memberName),
              InfoRow(label: 'Code', value: loan.guarantors[i].memberCode),
              InfoRow(label: 'Shares Pledged', value: _fmtAmt(loan.guarantors[i].shareAmount)),
            ]
          ]),
        ],

        // Collaterals
        if (loan.collaterals.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.md),
          _InfoSection(title: 'Collateral', rows: [
            for (int i = 0; i < loan.collaterals.length; i++) ...[
              InfoRow(label: 'Type', value: loan.collaterals[i].type),
              InfoRow(label: 'Description', value: loan.collaterals[i].description),
              InfoRow(label: 'Estimated Value', value: _fmtAmt(loan.collaterals[i].estimatedValue)),
            ]
          ]),
        ],

        if (loan.approvalRemarks != null && loan.approvalRemarks!.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.md),
          _InfoSection(title: 'Remarks', rows: [
            InfoRow(label: 'Approval Remarks', value: loan.approvalRemarks!),
          ]),
        ],
        const SizedBox(height: AppDimensions.xxl),
      ],
    );
  }

  String _fmtAmt(double v) {
    final s = v.toStringAsFixed(0);
    return 'NPR ${s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }
}

// ── EMI Schedule Tab ──────────────────────────────────────────────────────────

class _ScheduleTab extends ConsumerWidget {
  final String loanId;
  const _ScheduleTab({required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(_loanScheduleProvider(loanId));
    return scheduleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary, size: 48),
          const SizedBox(height: AppDimensions.sm),
          Text('No schedule yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Text('Loan may not be disbursed yet', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ]),
      ),
      data: (rows) => rows.isEmpty
          ? const EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'No schedule',
              subtitle: 'Loan may not be disbursed yet')
          : Column(children: [
              Container(
                color: AppColors.surfaceVariant,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                child: Row(
                  children: ['#', 'Due Date', 'Principal', 'Interest', 'Total', 'Balance']
                      .map((h) => Expanded(
                          child: Text(h,
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center)))
                      .toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final isPaid = r.status == 'Paid';
                    final isCurrent = r.status == 'Overdue' || (!isPaid && i == rows.indexWhere((x) => x.status != 'Paid'));
                    return Container(
                      color: isCurrent
                          ? AppColors.primary.withValues(alpha: 0.05)
                          : isPaid ? AppColors.secondary.withValues(alpha: 0.03) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
                      child: Row(children: [
                        Expanded(
                          child: Row(children: [
                            Icon(
                              isPaid ? Icons.check_circle_rounded
                                  : isCurrent ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isPaid ? AppColors.secondary
                                  : isCurrent ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text('${r.no}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                                  fontWeight: isCurrent ? FontWeight.w700 : null,
                                )),
                          ]),
                        ),
                        Expanded(child: Text(r.dueDate.length > 7 ? r.dueDate.substring(0, 10) : r.dueDate,
                            style: AppTextStyles.bodySmall, textAlign: TextAlign.center)),
                        Expanded(child: Text(_fmtK(r.principal),
                            style: AppTextStyles.bodySmall, textAlign: TextAlign.center)),
                        Expanded(child: Text(_fmtK(r.interest),
                            style: AppTextStyles.bodySmall, textAlign: TextAlign.center)),
                        Expanded(child: Text(_fmtK(r.emi),
                            style: AppTextStyles.labelSmall, textAlign: TextAlign.center)),
                        Expanded(child: Text(isPaid ? '—' : _fmtK(r.balance),
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center)),
                      ]),
                    );
                  },
                ),
              ),
            ]),
    );
  }

  String _fmtK(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Payments Tab ──────────────────────────────────────────────────────────────

class _PaymentsTab extends ConsumerWidget {
  final String loanId;
  const _PaymentsTab({required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(_loanPaymentsProvider(loanId));
    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Could not load payments',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
      data: (payments) => payments.isEmpty
          ? const EmptyView(
              icon: Icons.payments_outlined,
              title: 'No payments yet',
              subtitle: 'Payments will appear here once EMIs are collected')
          : ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.md),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
              itemBuilder: (context, i) {
                final p = payments[i];
                return Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(color: const Color(0xFFE8EDF3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_fmtDate(p.date), style: AppTextStyles.titleSmall),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
                        ),
                        child: Text('PAID',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary)),
                      ),
                    ]),
                    const SizedBox(height: AppDimensions.sm),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      _MiniPair(label: 'Principal', value: _fmtAmt(p.principal)),
                      _MiniPair(label: 'Interest', value: _fmtAmt(p.interest)),
                      _MiniPair(label: 'Penalty', value: p.penalty > 0 ? _fmtAmt(p.penalty) : '—'),
                      _MiniPair(label: 'Total', value: _fmtAmt(p.total)),
                    ]),
                    const SizedBox(height: AppDimensions.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppDimensions.sm),
                    Row(children: [
                      const Icon(Icons.receipt_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${p.receipt}  •  ${p.mode}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                      const Spacer(),
                      Text('Bal: ${_fmtAmt(p.balanceAfter)}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ]),
                    if (p.narration != null && p.narration!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(p.narration!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                  ]),
                );
              },
            ),
    );
  }

  String _fmtAmt(double v) {
    final s = v.toStringAsFixed(0);
    return 'NPR ${s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Text(title, style: AppTextStyles.titleSmall),
        ),
        const Divider(height: 1),
        ...rows,
      ]),
    );
  }
}

class _MiniPair extends StatelessWidget {
  final String label, value;
  const _MiniPair({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10)),
      Text(value, style: AppTextStyles.labelSmall),
    ]);
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
