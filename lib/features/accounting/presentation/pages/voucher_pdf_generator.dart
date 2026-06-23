import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates and previews/prints a professional voucher PDF.
class VoucherPdfGenerator {
  static const _orgName = 'SahakariMS Cooperative';
  static const _orgSubtitle = 'Saving & Credit Cooperative Society';

  static PdfColor get _primary => const PdfColor.fromInt(0xFF1565C0);
  static PdfColor get _accent => const PdfColor.fromInt(0xFF00897B);
  static PdfColor get _error => const PdfColor.fromInt(0xFFD32F2F);
  static PdfColor get _lightGrey => const PdfColor.fromInt(0xFFF5F7FA);
  static PdfColor get _borderGrey => const PdfColor.fromInt(0xFFE0E0E0);
  static PdfColor get _textSecondary => const PdfColor.fromInt(0xFF757575);

  /// Show a print/save preview dialog.
  static Future<void> previewAndPrint(
    BuildContext context,
    Map<String, dynamic> voucher,
  ) async {
    final pdfData = await _buildPdf(voucher);
    if (!context.mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
      name: '${voucher['voucherNumber'] ?? 'Voucher'}.pdf',
    );
  }

  static Future<Uint8List> _buildPdf(Map<String, dynamic> v) async {
    final doc = pw.Document();

    final entries =
        (v['entries'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    final drEntries = entries.where((e) => e['entryType'] == 'Debit').toList();
    final crEntries = entries.where((e) => e['entryType'] == 'Credit').toList();
    final totalDebit = drEntries.fold<double>(
        0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    final totalCredit = crEntries.fold<double>(
        0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

    final voucherNo = v['voucherNumber'] as String? ?? '—';
    final voucherType = v['voucherType'] as String? ?? 'Journal';
    final voucherDate = v['voucherDate'] as String? ?? '—';
    final narration = v['narration'] as String? ?? '';
    final status = v['status'] as String? ?? 'Draft';
    final isPosted = status == 'Posted';
    final printedAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final nprFmt = NumberFormat('#,##0.00', 'en_US');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: _primary,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(_orgName,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          )),
                      pw.SizedBox(height: 2),
                      pw.Text(_orgSubtitle,
                          style: pw.TextStyle(
                              color: const PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(voucherType.toUpperCase() + ' VOUCHER',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          )),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: isPosted
                              ? const PdfColor.fromInt(0xFF00897B)
                              : const PdfColor.fromInt(0xFFFF8F00),
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(status.toUpperCase(),
                            style: pw.TextStyle(
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
            pw.SizedBox(height: 12),
            // ── Meta row ─────────────────────────────────────────────────
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: pw.BoxDecoration(
                color: _lightGrey,
                border: pw.Border.all(color: _borderGrey),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _metaItem('Voucher No.', voucherNo),
                  _metaItem('Date (BS)', voucherDate),
                  _metaItem('Type', voucherType),
                  _metaItem('Status', status),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            // ── Narration ─────────────────────────────────────────────────
            if (narration.isNotEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderGrey),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Narration: ',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _textSecondary)),
                    pw.Expanded(
                      child: pw.Text(narration,
                          style: const pw.TextStyle(fontSize: 9)),
                    ),
                  ],
                ),
              ),
            pw.SizedBox(height: 10),
            // ── Entries Table ─────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(color: _borderGrey, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _primary),
                  children: [
                    _tableHeader('Code'),
                    _tableHeader('Account Name'),
                    _tableHeader('Type'),
                    _tableHeader('Amount (NPR)', right: true),
                  ],
                ),
                // Entry rows
                ...entries.asMap().entries.map((mapEntry) {
                  final i = mapEntry.key;
                  final e = mapEntry.value;
                  final isDr = e['entryType'] == 'Debit';
                  final bg = i.isEven ? PdfColors.white : _lightGrey;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _tableCell(e['accountCode'] as String? ?? '—'),
                      _tableCell(e['accountName'] as String? ?? '—'),
                      _tableCellColored(
                        isDr ? 'Dr' : 'Cr',
                        isDr ? _error : _accent,
                        bold: true,
                      ),
                      _tableCell(
                        'NPR ${nprFmt.format((e['amount'] as num?)?.toDouble() ?? 0)}',
                        right: true,
                        bold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 8),
            // ── Totals ───────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 260,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _borderGrey),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      _totalRow('Total Debit',
                          'NPR ${nprFmt.format(totalDebit)}', _error),
                      pw.Divider(height: 0.5, color: _borderGrey),
                      _totalRow('Total Credit',
                          'NPR ${nprFmt.format(totalCredit)}', _accent),
                      if (totalDebit == totalCredit)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          color: const PdfColor.fromInt(0xFFE8F5E9),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('✓ Balanced',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color:
                                        const PdfColor.fromInt(0xFF2E7D32),
                                    fontWeight: pw.FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            // ── Footer ───────────────────────────────────────────────────
            pw.Divider(color: _borderGrey),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Printed: $printedAt',
                    style: pw.TextStyle(fontSize: 7, color: _textSecondary)),
                pw.Text('SahakariMS v1.0 — Confidential',
                    style: pw.TextStyle(fontSize: 7, color: _textSecondary)),
                pw.Text('Authorised Signatory: ________________',
                    style: pw.TextStyle(fontSize: 8, color: _textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _metaItem(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 7,
                  color: const PdfColor.fromInt(0xFF9E9E9E),
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      );

  static pw.Widget _tableHeader(String text, {bool right = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            )),
      );

  static pw.Widget _tableCell(String text,
          {bool right = false, bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _tableCellColored(String text, PdfColor color,
          {bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Center(
          child: pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColor(color.red, color.green, color.blue, 0.15),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(text,
                style: pw.TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: bold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal)),
          ),
        ),
      );

  static pw.Widget _totalRow(String label, String value, PdfColor color) =>
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    color: const PdfColor.fromInt(0xFF757575))),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
}
