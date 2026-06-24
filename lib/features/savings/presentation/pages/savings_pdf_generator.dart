import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates and previews/prints a professional Savings Account Statement PDF.
class SavingsPdfGenerator {
  static const _orgName = 'SahakariMS Cooperative';
  static const _orgSubtitle = 'Saving & Credit Cooperative Society';

  static PdfColor get _headerColor => const PdfColor.fromInt(0xFF00897B); // teal (secondary)
  static PdfColor get _primary => const PdfColor.fromInt(0xFF1565C0);
  static PdfColor get _credit => const PdfColor.fromInt(0xFF00897B);
  static PdfColor get _debit => const PdfColor.fromInt(0xFFD32F2F);
  static PdfColor get _lightGrey => const PdfColor.fromInt(0xFFF5F7FA);
  static PdfColor get _borderGrey => const PdfColor.fromInt(0xFFE0E0E0);
  static PdfColor get _textSecondary => const PdfColor.fromInt(0xFF757575);

  /// Show a print/save preview dialog for the account statement.
  static Future<void> previewAndPrint(
    BuildContext context, {
    required Map<String, dynamic> account,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdfData = await _buildPdf(account: account, transactions: transactions);
    if (!context.mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
      name: 'Statement_${account['accountNumber'] ?? 'Account'}.pdf',
    );
  }

  static Future<Uint8List> _buildPdf({
    required Map<String, dynamic> account,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final doc = pw.Document();
    final nprFmt = NumberFormat('#,##0.00', 'en_US');
    final printedAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // Account info
    final accountNumber = account['accountNumber'] as String? ?? '—';
    final memberName = account['memberName'] as String? ?? '—';
    final accountType = account['accountType'] as String? ?? '—';
    final schemeName = account['schemeName'] as String? ?? '—';
    final status = account['status'] as String? ?? '—';
    final branch = account['branch'] as String? ?? '—';
    final openDate = account['openDate'] as String? ?? '—';
    final balance = (account['balance'] as num?)?.toDouble() ?? 0;
    final interestRate = (account['interestRate'] as num?)?.toDouble() ?? 0;
    final totalDeposits = (account['totalDeposits'] as num?)?.toDouble() ?? 0;
    final totalWithdrawals = (account['totalWithdrawals'] as num?)?.toDouble() ?? 0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(
          accountNumber: accountNumber,
          memberName: memberName,
          accountType: accountType,
          status: status,
          printedAt: printedAt,
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SahakariMS v1.0 — Confidential',
                style: pw.TextStyle(fontSize: 7, color: _textSecondary)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7, color: _textSecondary)),
            pw.Text('Authorised Signatory: ________________',
                style: pw.TextStyle(fontSize: 8, color: _textSecondary)),
          ],
        ),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          // ── Account Summary Cards ─────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _lightGrey,
              border: pw.Border.all(color: _borderGrey),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _infoItem('Scheme', schemeName),
                _infoItem('Branch', branch),
                _infoItem('Open Date', openDate.length >= 10 ? openDate.substring(0, 10) : openDate),
                _infoItem('Interest Rate', '${interestRate.toStringAsFixed(2)}% p.a.'),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          // ── Balance Summary Row ───────────────────────────────────────
          pw.Row(
            children: [
              _summaryCard('Current Balance', 'NPR ${nprFmt.format(balance)}', _primary, flex: 2),
              pw.SizedBox(width: 8),
              _summaryCard('Total Deposits', 'NPR ${nprFmt.format(totalDeposits)}', _credit),
              pw.SizedBox(width: 8),
              _summaryCard('Total Withdrawals', 'NPR ${nprFmt.format(totalWithdrawals)}', _debit),
            ],
          ),
          pw.SizedBox(height: 12),
          // ── Transactions Table ────────────────────────────────────────
          pw.Text('Transaction History',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary)),
          pw.SizedBox(height: 6),
          if (transactions.isEmpty)
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Text('No transactions found.',
                    style: pw.TextStyle(color: _textSecondary, fontSize: 10)),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: _borderGrey, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),  // Date
                1: const pw.FlexColumnWidth(2),  // Receipt
                2: const pw.FlexColumnWidth(1.5), // Type
                3: const pw.FlexColumnWidth(1.5), // Mode
                4: const pw.FlexColumnWidth(2),  // Amount
                5: const pw.FlexColumnWidth(2),  // Balance
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _headerColor),
                  children: [
                    _th('Date'),
                    _th('Receipt No.'),
                    _th('Type'),
                    _th('Mode'),
                    _th('Amount (NPR)', right: true),
                    _th('Balance (NPR)', right: true),
                  ],
                ),
                // Data rows
                ...transactions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  final isDeposit = (t['transactionType'] as String? ?? '') != 'Withdrawal';
                  final bg = i.isEven ? PdfColors.white : _lightGrey;
                  final rawDate = t['transactionDate'] as String? ?? '';
                  final dateParsed = DateTime.tryParse(rawDate);
                  final dateStr = dateParsed != null
                      ? DateFormat('yyyy-MM-dd').format(dateParsed.toLocal())
                      : rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _td(dateStr),
                      _td(t['receiptNumber'] as String? ?? '—'),
                      _tdColored(
                        t['transactionType'] as String? ?? '—',
                        isDeposit ? _credit : _debit,
                      ),
                      _td(t['mode'] as String? ?? '—'),
                      _td(
                        '${isDeposit ? '+' : '-'} ${nprFmt.format((t['amount'] as num?)?.toDouble() ?? 0)}',
                        right: true,
                        color: isDeposit ? _credit : _debit,
                        bold: true,
                      ),
                      _td(
                        'NPR ${nprFmt.format((t['balanceAfter'] as num?)?.toDouble() ?? 0)}',
                        right: true,
                        bold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header widget (repeated on each page) ───────────────────────────────────
  static pw.Widget _buildHeader({
    required String accountNumber,
    required String memberName,
    required String accountType,
    required String status,
    required String printedAt,
  }) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _headerColor,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_orgName,
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 2),
                    pw.Text(_orgSubtitle,
                        style: const pw.TextStyle(
                            color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('SAVINGS ACCOUNT STATEMENT',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: status == 'Active'
                            ? const PdfColor(0, 0.6, 0.5, 1)
                            : const PdfColor(0.83, 0.18, 0.18, 1),
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: pw.Text(status.toUpperCase(),
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          // Account identity row
          pw.Row(
            children: [
              pw.Expanded(
                child: _metaItem('Account Number', accountNumber),
              ),
              pw.Expanded(
                child: _metaItem('Member Name', memberName),
              ),
              pw.Expanded(
                child: _metaItem('Account Type', accountType),
              ),
              pw.Expanded(
                child: _metaItem('Printed', printedAt),
              ),
            ],
          ),
        ],
      );

  // ── Helper widgets ───────────────────────────────────────────────────────────
  static pw.Widget _metaItem(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 7,
                  color: _textSecondary,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: const pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      );

  static pw.Widget _infoItem(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 7,
                  color: _textSecondary,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      );

  static pw.Widget _summaryCard(String label, String value, PdfColor color,
          {int flex = 1}) =>
      pw.Expanded(
        flex: flex,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor(color.red, color.green, color.blue, 0.08),
            border: pw.Border.all(
                color: PdfColor(color.red, color.green, color.blue, 0.3)),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(fontSize: 8, color: _textSecondary)),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11, color: color, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

  static pw.Widget _th(String text, {bool right = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _td(String text,
          {bool right = false, PdfColor? color, bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
                fontSize: 8,
                color: color ?? PdfColors.black,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _tdColored(String text, PdfColor color) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            color: PdfColor(color.red, color.green, color.blue, 0.12),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 8,
                  color: color,
                  fontWeight: pw.FontWeight.bold)),
        ),
      );
}
