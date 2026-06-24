import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/api/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _EmiRow {
  final int no;
  final DateTime dueDate;
  final double emi, principal, interest, balance;
  final String status; // Pending | Paid | PartPaid | Overdue

  const _EmiRow({
    required this.no,
    required this.dueDate,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.balance,
    required this.status,
  });

  bool get isPaid => status == 'Paid';
  bool get isOverdue => status == 'Overdue';
  bool get isPartPaid => status == 'PartPaid';

  factory _EmiRow.fromJson(Map<String, dynamic> j) => _EmiRow(
        no: (j['installmentNo'] as num).toInt(),
        dueDate: DateTime.tryParse(j['dueDate'] as String? ?? '') ??
            DateTime.now(),
        emi: (j['emiAmount'] as num).toDouble(),
        principal: (j['principalAmount'] as num).toDouble(),
        interest: (j['interestAmount'] as num).toDouble(),
        balance: (j['outstandingBalance'] as num).toDouble(),
        status: j['status'] as String? ?? 'Pending',
      );
}

class _LoanMeta {
  final String loanNumber, memberName, memberCode, productName, status, branch;
  final double appliedAmount, emiAmount, outstandingBalance, overdueAmount;
  final int tenureMonths, overdueDays, installmentsPaid;

  const _LoanMeta({
    required this.loanNumber,
    required this.memberName,
    required this.memberCode,
    required this.productName,
    required this.status,
    required this.branch,
    required this.appliedAmount,
    required this.emiAmount,
    required this.outstandingBalance,
    required this.overdueAmount,
    required this.tenureMonths,
    required this.overdueDays,
    required this.installmentsPaid,
  });

  factory _LoanMeta.fromJson(Map<String, dynamic> j) => _LoanMeta(
        loanNumber: j['loanNumber'] as String? ?? '',
        memberName: j['memberName'] as String? ?? '',
        memberCode: j['memberCode'] as String? ?? '',
        productName: j['productName'] as String? ?? '',
        status: j['status'] as String? ?? '',
        branch: j['branch'] as String? ?? '',
        appliedAmount: (j['appliedAmount'] as num? ?? 0).toDouble(),
        emiAmount: (j['emiAmount'] as num? ?? 0).toDouble(),
        outstandingBalance: (j['outstandingBalance'] as num? ?? 0).toDouble(),
        overdueAmount: (j['overdueAmount'] as num? ?? 0).toDouble(),
        tenureMonths: (j['tenureMonths'] as num? ?? 0).toInt(),
        overdueDays: (j['overdueDays'] as num? ?? 0).toInt(),
        installmentsPaid: (j['installmentsPaid'] as num? ?? 0).toInt(),
      );
}

class _PageData {
  final _LoanMeta meta;
  final List<_EmiRow> schedule;
  const _PageData(this.meta, this.schedule);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _emiProvider =
    FutureProvider.family.autoDispose<_PageData, String>((ref, loanId) async {
  final dio = ref.watch(dioProvider);
  final futures = await Future.wait([
    dio.get('/api/v1/loans/$loanId'),
    dio.get('/api/v1/loans/$loanId/schedule'),
  ]);

  final loanEnv = futures[0].data as Map<String, dynamic>;
  final loanData = (loanEnv['data'] as Map<String, dynamic>?) ?? {};
  final meta = _LoanMeta.fromJson(loanData);

  final schEnv = futures[1].data as Map<String, dynamic>;
  final schData = (schEnv['data'] as List<dynamic>?) ?? [];
  final schedule =
      schData.map((e) => _EmiRow.fromJson(e as Map<String, dynamic>)).toList();

  return _PageData(meta, schedule);
});

// ── Page ──────────────────────────────────────────────────────────────────────

class EmiSchedulePage extends ConsumerWidget {
  final String loanId;
  const EmiSchedulePage({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_emiProvider(loanId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('EMI Schedule', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          async.maybeWhen(
            data: (data) => TextButton.icon(
              onPressed: () => _printPdf(context, data),
              icon: const Icon(Icons.download_rounded, size: 18,
                  color: AppColors.primary),
              label: Text('PDF',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.primary)),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: AppDimensions.md),
              const Text('Failed to load EMI schedule',
                  style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimensions.sm),
              Text(e.toString(),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppDimensions.md),
              TextButton.icon(
                onPressed: () => ref.invalidate(_emiProvider(loanId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _buildBody(data),
      ),
    );
  }

  Widget _buildBody(_PageData data) {
    final meta = data.meta;
    final schedule = data.schedule;
    final paidAmt = schedule
        .where((r) => r.isPaid)
        .fold(0.0, (sum, r) => sum + r.emi);
    final paidCount = meta.installmentsPaid;
    final totalCount = meta.tenureMonths;
    final progress = totalCount > 0 ? paidCount / totalCount : 0.0;

    return Column(
      children: [
        // ── Summary ─────────────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Loan number + member
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(meta.loanNumber,
                      style: AppTextStyles.titleSmall
                          .copyWith(color: AppColors.primary)),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      '${meta.memberName} (${meta.memberCode})',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              // Stats row
              Row(
                children: [
                  _SummaryStat(
                    label: 'Amount Paid',
                    value: _fmtAmt(paidAmt),
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  _SummaryStat(
                    label: 'Outstanding',
                    value: _fmtAmt(meta.outstandingBalance),
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  _SummaryStat(
                    label: 'Monthly EMI',
                    value: _fmtAmt(meta.emiAmount),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Progress bar ─────────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$paidCount / $totalCount installments paid',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.toDouble(),
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.secondary),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        // ── Column headers ───────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceVariant,
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md, vertical: AppDimensions.sm),
          child: const Row(
            children: [
              SizedBox(width: 32),
              Expanded(child: _Th('Due Date')),
              Expanded(child: _Th('Principal')),
              Expanded(child: _Th('Interest')),
              Expanded(child: _Th('EMI')),
              Expanded(child: _Th('Balance')),
            ],
          ),
        ),
        // ── Rows ─────────────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: schedule.length,
            itemBuilder: (context, i) => _EmiRowWidget(row: schedule[i]),
          ),
        ),
      ],
    );
  }

  Future<void> _printPdf(BuildContext context, _PageData data) async {
    final pdf = await _buildPdf(data);
    if (!context.mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'EMI_Schedule_${data.meta.loanNumber}.pdf',
    );
  }

  static Future<Uint8List> _buildPdf(_PageData data) async {
    final meta = data.meta;
    final schedule = data.schedule;
    final doc = pw.Document();
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final dateFmt = DateFormat('dd MMM yyyy');

    // ── Colors ─────────────────────────────────────────────────────────────
    const primaryColor = PdfColor.fromInt(0xFF1565C0);
    const secondaryColor = PdfColor.fromInt(0xFF00897B);
    const errorColor = PdfColor.fromInt(0xFFD32F2F);
    const headerBg = PdfColor.fromInt(0xFFF5F7FA);
    const borderColor = PdfColor.fromInt(0xFFE0E0E0);
    const greyText = PdfColor.fromInt(0xFF757575);

    // ── Totals ─────────────────────────────────────────────────────────────
    final totalPrincipal = schedule.fold(0.0, (s, r) => s + r.principal);
    final totalInterest = schedule.fold(0.0, (s, r) => s + r.interest);
    final totalEmi = schedule.fold(0.0, (s, r) => s + r.emi);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Title bar
            pw.Container(
              decoration: const pw.BoxDecoration(color: primaryColor),
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SahakariMS Cooperative',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text('Saving & Credit Cooperative Society',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('EMI Repayment Schedule',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          'Generated: ${dateFmt.format(DateTime.now())}',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            // Loan info row
            pw.Container(
              decoration: pw.BoxDecoration(
                color: headerBg,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: borderColor),
              ),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: pw.Row(
                children: [
                  _pdfInfoBlock('Loan No.', meta.loanNumber, primaryColor),
                  _pdfInfoBlock(
                      'Member', '${meta.memberName} (${meta.memberCode})',
                      primaryColor),
                  _pdfInfoBlock('Product', meta.productName, primaryColor),
                  _pdfInfoBlock('Amount',
                      'NPR ${fmt.format(meta.appliedAmount)}', primaryColor),
                  _pdfInfoBlock('EMI', 'NPR ${fmt.format(meta.emiAmount)}',
                      primaryColor),
                  _pdfInfoBlock('Tenure', '${meta.tenureMonths} months',
                      primaryColor),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            // Outstanding row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      const pw.TextSpan(
                          text: 'Outstanding Balance: ',
                          style: pw.TextStyle(
                              color: PdfColors.grey, fontSize: 8)),
                      pw.TextSpan(
                          text:
                              'NPR ${fmt.format(meta.outstandingBalance)}',
                          style: const pw.TextStyle(
                              color: errorColor,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      const pw.TextSpan(
                          text: 'Paid: ',
                          style: pw.TextStyle(
                              color: PdfColors.grey, fontSize: 8)),
                      pw.TextSpan(
                          text:
                              '${meta.installmentsPaid} / ${meta.tenureMonths} installments',
                          style: const pw.TextStyle(
                              color: secondaryColor,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          // ── Table ──────────────────────────────────────────────────────
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            headerDecoration:
                const pw.BoxDecoration(color: primaryColor),
            headerStyle: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold),
            cellStyle:
                const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.center,
            },
            headers: [
              '#',
              'Due Date',
              'Principal',
              'Interest',
              'EMI',
              'Balance',
              'Status',
            ],
            data: schedule.map((r) => [
                r.no.toString(),
                dateFmt.format(r.dueDate),
                'NPR ${fmt.format(r.principal)}',
                'NPR ${fmt.format(r.interest)}',
                'NPR ${fmt.format(r.emi)}',
                r.balance > 0 ? 'NPR ${fmt.format(r.balance)}' : '—',
                r.status,
              ]).toList(),
          ),
          pw.SizedBox(height: 8),
          // ── Totals row ─────────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              color: headerBg,
              border: pw.Border.all(color: borderColor),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTALS',
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8)),
                pw.Text(
                    'Principal: NPR ${fmt.format(totalPrincipal)}',
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                        color: primaryColor)),
                pw.Text(
                    'Interest: NPR ${fmt.format(totalInterest)}',
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                        color: greyText)),
                pw.Text('Total EMI: NPR ${fmt.format(totalEmi)}',
                    style: const pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                        color: secondaryColor)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            '* This schedule is generated for informational purposes. Contact the branch for official records.',
            style: const pw.TextStyle(
                fontSize: 7, color: PdfColors.grey),
          ),
        ],
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${meta.branch} • ${meta.loanNumber}',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfInfoBlock(
      String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(right: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
            pw.Text(value,
                style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black),
                maxLines: 1),
          ],
        ),
      ),
    );
  }

  String _fmtAmt(double v) {
    final f = NumberFormat('#,##0', 'en_US');
    return 'NPR ${f.format(v)}';
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Th extends StatelessWidget {
  final String text;
  const _Th(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.labelSmall
            .copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center);
  }
}

class _SummaryStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: color, fontSize: 10)),
            Text(value,
                style: AppTextStyles.labelSmall
                    .copyWith(color: color, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _EmiRowWidget extends StatelessWidget {
  final _EmiRow row;
  const _EmiRowWidget({required this.row});

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _numFmt = NumberFormat('#,##0', 'en_US');

  String _fmt(double n) => _numFmt.format(n);

  Color get _rowBg {
    if (row.isPaid) return AppColors.secondary.withValues(alpha: 0.04);
    if (row.isOverdue) return AppColors.error.withValues(alpha: 0.04);
    return Colors.transparent;
  }


  @override
  Widget build(BuildContext context) {
    final isCurrentDue = !row.isPaid && row.dueDate.isBefore(DateTime.now());

    return Container(
      color: _rowBg,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: row.isPaid
                ? const Icon(Icons.check_circle_rounded,
                    color: AppColors.secondary, size: 16)
                : row.isOverdue
                    ? const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 16)
                    : Text('${row.no}',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
              _dateFmt.format(row.dueDate),
              style: AppTextStyles.bodySmall.copyWith(
                color: isCurrentDue
                    ? AppColors.error
                    : AppColors.textPrimary,
                fontWeight:
                    isCurrentDue ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(_fmt(row.principal),
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(_fmt(row.interest),
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(_fmt(row.emi),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textPrimary),
                textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text(
                row.balance > 0 ? _fmt(row.balance) : '—',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
