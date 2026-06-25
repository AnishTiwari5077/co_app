import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Shared PDF generator for all system reports.
class ReportsPdfGenerator {
  static const _org = 'SahakariMS Cooperative';
  static const _orgSub = 'Saving & Credit Cooperative Society';
  static final _fmt = NumberFormat('#,##0.00', 'en_US');

  static PdfColor get _primary => const PdfColor.fromInt(0xFF1565C0);
  static PdfColor get _secondary => const PdfColor.fromInt(0xFF00897B);
  static PdfColor get _accent => const PdfColor.fromInt(0xFFF57C00);
  static PdfColor get _error => const PdfColor.fromInt(0xFFD32F2F);
  static PdfColor get _purple => const PdfColor.fromInt(0xFF7C3AED);
  static PdfColor get _light => const PdfColor.fromInt(0xFFF5F7FA);
  static PdfColor get _border => const PdfColor.fromInt(0xFFE0E0E0);
  static PdfColor get _grey => const PdfColor.fromInt(0xFF757575);

  // ────────────────────────────────────────────────────────────────────────────
  // Public entry points
  // ────────────────────────────────────────────────────────────────────────────

  static Future<void> previewMemberList(
    BuildContext context,
    List<Map<String, dynamic>> members,
  ) async {
    final pdf = await _buildMemberListPdf(members);
    if (!context.mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => pdf, name: 'Member_List.pdf');
  }

  static Future<void> previewLoanPortfolio(
    BuildContext context,
    List<Map<String, dynamic>> loans, {
    String? statusFilter,
  }) async {
    final pdf = await _buildLoanPdf(loans, statusFilter: statusFilter);
    if (!context.mounted) return;
    await Printing.layoutPdf(
        onLayout: (_) async => pdf, name: 'Loan_Portfolio.pdf');
  }

  static Future<void> previewSavingsSummary(
    BuildContext context,
    List<Map<String, dynamic>> accounts,
  ) async {
    final pdf = await _buildSavingsSummaryPdf(accounts);
    if (!context.mounted) return;
    await Printing.layoutPdf(
        onLayout: (_) async => pdf, name: 'Savings_Summary.pdf');
  }

  static Future<void> previewTrialBalance(
    BuildContext context,
    Map<String, dynamic> trialBalance,
    String asOfDate,
  ) async {
    final pdf = await _buildTrialBalancePdf(trialBalance, asOfDate);
    if (!context.mounted) return;
    await Printing.layoutPdf(
        onLayout: (_) async => pdf, name: 'Trial_Balance.pdf');
  }

  static Future<void> previewNpaReport(
    BuildContext context,
    List<Map<String, dynamic>> loans,
  ) async {
    final npa = loans
        .where((l) =>
            ((l['overdueDays'] as num?)?.toInt() ?? 0) > 90 ||
            (l['npaClassification'] != null &&
                l['npaClassification'].toString().isNotEmpty &&
                l['npaClassification'] != 'Standard'))
        .toList();
    final pdf = await _buildLoanPdf(npa,
        title: 'NPA Report', subtitle: 'Non-Performing Assets (Overdue > 90 days)');
    if (!context.mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => pdf, name: 'NPA_Report.pdf');
  }

  static Future<void> previewOverdueLoans(
    BuildContext context,
    List<Map<String, dynamic>> loans,
  ) async {
    final overdue = loans
        .where((l) => ((l['overdueAmount'] as num?)?.toDouble() ?? 0) > 0)
        .toList();
    final pdf = await _buildLoanPdf(overdue,
        title: 'Overdue Loans Report',
        subtitle: 'Loans with outstanding overdue installments');
    if (!context.mounted) return;
    await Printing.layoutPdf(
        onLayout: (_) async => pdf, name: 'Overdue_Loans.pdf');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Member List PDF
  // ────────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildMemberListPdf(
      List<Map<String, dynamic>> members) async {
    final doc = pw.Document();
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final totalActive = members.where((m) => m['status'] == 'Active').length;
    final totalPending = members.where((m) => m['status'] == 'Pending').length;
    final totalSuspended =
        members.where((m) => m['status'] == 'Suspended').length;
    final totalInactive =
        members.where((m) => m['status'] == 'Inactive').length;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) =>
          _reportHeader('MEMBER LIST REPORT', 'All registered members', now, _purple),
      footer: _footer,
      build: (ctx) => [
        pw.SizedBox(height: 8),
        // Summary cards
        pw.Row(children: [
          _statCard('Total', '${members.length}', _purple),
          pw.SizedBox(width: 6),
          _statCard('Active', '$totalActive', _secondary),
          pw.SizedBox(width: 6),
          _statCard('Pending', '$totalPending', _accent),
          pw.SizedBox(width: 6),
          _statCard('Suspended', '$totalSuspended', _error),
          pw.SizedBox(width: 6),
          _statCard('Inactive', '$totalInactive', _grey),
        ]),
        pw.SizedBox(height: 12),
        pw.Text('Member Registry',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _purple)),
        pw.SizedBox(height: 6),
        if (members.isEmpty)
          _emptyMsg('No members found.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),   // #
              1: const pw.FlexColumnWidth(2.5), // Code
              2: const pw.FlexColumnWidth(4),   // Name
              3: const pw.FlexColumnWidth(2.5), // Phone
              4: const pw.FlexColumnWidth(2.5), // District
              5: const pw.FlexColumnWidth(2),   // Status
              6: const pw.FlexColumnWidth(2.5), // Joined
            },
            children: [
              _tableHeader(_purple, ['#', 'Member Code', 'Full Name', 'Phone', 'District', 'Status', 'Joined']),
              ...members.asMap().entries.map((e) {
                final i = e.key;
                final m = e.value;
                final name =
                    '${m['firstName'] ?? ''} ${m['middleName'] ?? ''} ${m['lastName'] ?? ''}'
                        .trim();
                final status = m['status'] as String? ?? 'N/A';
                final statusColor = status == 'Active'
                    ? _secondary
                    : status == 'Pending'
                        ? _accent
                        : status == 'Suspended'
                            ? _error
                            : _grey;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : _light),
                  children: [
                    _td('${i + 1}'),
                    _td(m['memberCode'] as String? ?? 'N/A'),
                    _td(name),
                    _td(m['phoneNumber'] as String? ?? 'N/A'),
                    _td(m['addressDistrict'] as String? ?? 'N/A'),
                    _tdBadge(status, statusColor),
                    _td(_shortDate(m['membershipDate'])),
                  ],
                );
              }),
            ],
          ),
      ],
    ));
    return doc.save();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Loan Portfolio / NPA / Overdue PDF
  // ────────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildLoanPdf(
    List<Map<String, dynamic>> loans, {
    String title = 'Loan Portfolio Report',
    String subtitle = 'All loans by status',
    String? statusFilter,
  }) async {
    final doc = pw.Document();
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final data = statusFilter != null
        ? loans.where((l) => l['status'] == statusFilter).toList()
        : loans;

    final totalDisbursed = data.fold<double>(
        0, (s, l) => s + ((l['approvedAmount'] as num?)?.toDouble() ?? 0));
    final totalOutstanding = data.fold<double>(
        0, (s, l) => s + ((l['outstandingBalance'] as num?)?.toDouble() ?? 0));
    final totalOverdue = data.fold<double>(
        0, (s, l) => s + ((l['overdueAmount'] as num?)?.toDouble() ?? 0));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => _reportHeader(title, subtitle, now, _accent),
      footer: _footer,
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _statCard('Total Loans', '${data.length}', _accent),
          pw.SizedBox(width: 6),
          _statCard('Disbursed', 'NPR ${_fmt.format(totalDisbursed)}', _secondary),
          pw.SizedBox(width: 6),
          _statCard('Outstanding', 'NPR ${_fmt.format(totalOutstanding)}', _primary),
          pw.SizedBox(width: 6),
          _statCard('Overdue', 'NPR ${_fmt.format(totalOverdue)}', _error),
        ]),
        pw.SizedBox(height: 12),
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _accent)),
        pw.SizedBox(height: 6),
        if (data.isEmpty)
          _emptyMsg('No loans found.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),   // Loan No
              1: const pw.FlexColumnWidth(3.5), // Member
              2: const pw.FlexColumnWidth(2),   // Status
              3: const pw.FlexColumnWidth(2),   // Approved
              4: const pw.FlexColumnWidth(2.5), // Outstanding
              5: const pw.FlexColumnWidth(2),   // Overdue Amt
              6: const pw.FlexColumnWidth(1.5), // Overdue Days
              7: const pw.FlexColumnWidth(2),   // NPA
            },
            children: [
              _tableHeader(_accent, [
                'Loan No.',
                'Member',
                'Status',
                'Approved (NPR)',
                'Outstanding (NPR)',
                'Overdue Amt',
                'Days',
                'NPA Class'
              ]),
              ...data.asMap().entries.map((e) {
                final i = e.key;
                final l = e.value;
                final status = l['status'] as String? ?? 'N/A';
                final statusColor = status == 'Disbursed' || status == 'Active'
                    ? _secondary
                    : status == 'Overdue'
                        ? _error
                        : status == 'Pending'
                            ? _accent
                            : _grey;
                final overdueDays = (l['overdueDays'] as num?)?.toInt() ?? 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : _light),
                  children: [
                    _td(l['loanNumber'] as String? ?? 'N/A'),
                    _td(l['memberName'] as String? ?? 'N/A'),
                    _tdBadge(status, statusColor),
                    _td(_fmt.format((l['approvedAmount'] as num?)?.toDouble() ?? 0), right: true),
                    _td(_fmt.format((l['outstandingBalance'] as num?)?.toDouble() ?? 0), right: true),
                    _td(
                        _fmt.format((l['overdueAmount'] as num?)?.toDouble() ?? 0),
                        right: true,
                        color: ((l['overdueAmount'] as num?)?.toDouble() ?? 0) > 0
                            ? _error
                            : null),
                    _td('$overdueDays',
                        right: true,
                        color: overdueDays > 30 ? _error : null),
                    _td(l['npaClassification'] as String? ?? 'Standard'),
                  ],
                );
              }),
            ],
          ),
      ],
    ));
    return doc.save();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Savings Summary PDF
  // ────────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildSavingsSummaryPdf(
      List<Map<String, dynamic>> accounts) async {
    final doc = pw.Document();
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final totalBalance = accounts.fold<double>(
        0, (s, a) => s + ((a['balance'] as num?)?.toDouble() ?? 0));
    final active = accounts.where((a) => a['status'] == 'Active').length;
    final closed = accounts.where((a) => a['status'] == 'Closed').length;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => _reportHeader(
          'SAVINGS SUMMARY REPORT', 'All savings accounts', now, _secondary),
      footer: _footer,
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _statCard('Total Accounts', '${accounts.length}', _secondary),
          pw.SizedBox(width: 6),
          _statCard('Active', '$active', _secondary),
          pw.SizedBox(width: 6),
          _statCard('Closed', '$closed', _grey),
          pw.SizedBox(width: 6),
          _statCard('Total Balance', 'NPR ${_fmt.format(totalBalance)}', _primary),
        ]),
        pw.SizedBox(height: 12),
        pw.Text('Savings Accounts',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _secondary)),
        pw.SizedBox(height: 6),
        if (accounts.isEmpty)
          _emptyMsg('No accounts found.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),  // #
              1: const pw.FlexColumnWidth(2.5),  // Account No
              2: const pw.FlexColumnWidth(3.5),  // Member
              3: const pw.FlexColumnWidth(2.5),  // Scheme
              4: const pw.FlexColumnWidth(2),    // Balance
              5: const pw.FlexColumnWidth(1.8),  // Status
              6: const pw.FlexColumnWidth(2),    // Open Date
            },
            children: [
              _tableHeader(_secondary,
                  ['#', 'Account No.', 'Member Name', 'Scheme', 'Balance (NPR)', 'Status', 'Opened']),
              ...accounts.asMap().entries.map((e) {
                final i = e.key;
                final a = e.value;
                final status = a['status'] as String? ?? 'Active';
                final statusColor =
                    status == 'Active' ? _secondary : status == 'Frozen' ? _accent : _grey;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : _light),
                  children: [
                    _td('${i + 1}'),
                    _td(a['accountNumber'] as String? ?? 'N/A'),
                    _td(a['memberName'] as String? ?? 'N/A'),
                    _td(a['schemeName'] as String? ?? 'N/A'),
                    _td(
                      _fmt.format((a['balance'] as num?)?.toDouble() ?? 0),
                      right: true,
                      bold: true,
                      color: _secondary,
                    ),
                    _tdBadge(status, statusColor),
                    _td(_shortDate(a['openDate'])),
                  ],
                );
              }),
            ],
          ),
      ],
    ));
    return doc.save();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Trial Balance PDF
  // ────────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildTrialBalancePdf(
      Map<String, dynamic> tb, String asOfDate) async {
    final doc = pw.Document();
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // API returns 'accounts' list; fall back to 'entries' for compatibility
    final entries = ((tb['accounts'] as List<dynamic>?) ??
            (tb['entries'] as List<dynamic>?) ??
            [])
        .cast<Map<String, dynamic>>();
    final totalDebit = (tb['totalDebit'] as num?)?.toDouble() ?? 0;
    final totalCredit = (tb['totalCredit'] as num?)?.toDouble() ?? 0;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => _reportHeader(
          'TRIAL BALANCE', 'As of $asOfDate', now, _primary),
      footer: _footer,
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _statCard('Total Debit', 'NPR ${_fmt.format(totalDebit)}', _error),
          pw.SizedBox(width: 8),
          _statCard('Total Credit', 'NPR ${_fmt.format(totalCredit)}', _secondary),
          pw.SizedBox(width: 8),
          _statCard(
              'Difference',
              'NPR ${_fmt.format((totalDebit - totalCredit).abs())}',
              (totalDebit - totalCredit).abs() < 0.01 ? _secondary : _error),
        ]),
        pw.SizedBox(height: 12),
        if (entries.isEmpty)
          _emptyMsg('No entries found for the selected period.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),  // Code
              1: const pw.FlexColumnWidth(5),  // Account Name
              2: const pw.FlexColumnWidth(2),  // Type
              3: const pw.FlexColumnWidth(2.5), // Debit
              4: const pw.FlexColumnWidth(2.5), // Credit
            },
            children: [
              _tableHeader(_primary,
                  ['Code', 'Account Name', 'Type', 'Debit (NPR)', 'Credit (NPR)']),
              ...entries.asMap().entries.map((e) {
                final i = e.key;
                final en = e.value;
                // API uses debitBalance/creditBalance; fall back to debit/credit
                final debit = (en['debitBalance'] as num?)?.toDouble() ??
                    (en['debit'] as num?)?.toDouble() ?? 0;
                final credit = (en['creditBalance'] as num?)?.toDouble() ??
                    (en['credit'] as num?)?.toDouble() ?? 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : _light),
                  children: [
                    _td(en['accountCode'] as String? ?? 'N/A'),
                    _td(en['accountName'] as String? ?? 'N/A'),
                    _td(en['accountType'] as String? ?? 'N/A'),
                    _td(debit > 0 ? _fmt.format(debit) : '-',
                        right: true, color: debit > 0 ? _error : _grey),
                    _td(credit > 0 ? _fmt.format(credit) : '-',
                        right: true, color: credit > 0 ? _secondary : _grey),
                  ],
                );
              }),
              // Totals row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFF3FB)),
                children: [
                  _td('', bold: true),
                  _tdColored('TOTAL', _primary),
                  _td(''),
                  _td('NPR ${_fmt.format(totalDebit)}',
                      right: true, bold: true, color: _error),
                  _td('NPR ${_fmt.format(totalCredit)}',
                      right: true, bold: true, color: _secondary),
                ],
              ),
            ],
          ),
      ],
    ));
    return doc.save();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Shared PDF building helpers
  // ────────────────────────────────────────────────────────────────────────────

  static pw.Widget _reportHeader(
          String title, String subtitle, String printed, PdfColor color) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
              color: color, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(_org,
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(_orgSub,
                          style: const pw.TextStyle(
                              color: PdfColor(1, 1, 1, 0.7), fontSize: 8)),
                    ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(title,
                      style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5)),
                  pw.SizedBox(height: 3),
                  pw.Text(subtitle,
                      style: const pw.TextStyle(
                          color: PdfColor(1, 1, 1, 0.8), fontSize: 8)),
                  pw.SizedBox(height: 3),
                  pw.Text('Printed: $printed',
                      style: const pw.TextStyle(
                          color: PdfColor(1, 1, 1, 0.7), fontSize: 7)),
                ]),
              ]),
        ),
        pw.SizedBox(height: 4),
      ]);

  static pw.Widget Function(pw.Context) get _footer => (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('SahakariMS v1.0 - Confidential',
              style: pw.TextStyle(fontSize: 7, color: _grey)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: _grey)),
          pw.Text('Authorised Signatory: _______________',
              style: pw.TextStyle(fontSize: 7, color: _grey)),
        ],
      );

  static pw.Widget _statCard(String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: pw.BoxDecoration(
            color: PdfColor(color.red, color.green, color.blue, 0.08),
            border: pw.Border.all(
                color: PdfColor(color.red, color.green, color.blue, 0.3)),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 7, color: _grey)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10, color: color, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      );

  static pw.TableRow _tableHeader(PdfColor color, List<String> cols) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(color: color),
        children: cols
            .map((c) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  child: pw.Text(c,
                      style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold)),
                ))
            .toList(),
      );

  static pw.Widget _td(String text,
          {bool right = false, PdfColor? color, bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
                fontSize: 7.5,
                color: color ?? PdfColors.black,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _tdBadge(String text, PdfColor color) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            color: PdfColor(color.red, color.green, color.blue, 0.12),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 7,
                  color: color,
                  fontWeight: pw.FontWeight.bold)),
        ),
      );

  static pw.Widget _tdColored(String text, PdfColor color) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 7.5, color: color, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _emptyMsg(String msg) => pw.Center(
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Text(msg,
              style: pw.TextStyle(fontSize: 10, color: _grey)),
        ),
      );

  static String _shortDate(dynamic raw) {
    if (raw == null) return 'N/A';
    final s = raw.toString();
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }
}
