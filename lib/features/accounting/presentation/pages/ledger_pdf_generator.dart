import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'ledger_page.dart'; // To access LedgerData

class LedgerPdfGenerator {
  static const _orgName = 'SahakariMS Cooperative';
  static const _orgSubtitle = 'Saving & Credit Cooperative Society';

  static PdfColor get _primary => const PdfColor.fromInt(0xFF1565C0);
  static PdfColor get _secondary => const PdfColor.fromInt(0xFF00897B);
  static PdfColor get _error => const PdfColor.fromInt(0xFFD32F2F);
  static PdfColor get _lightGrey => const PdfColor.fromInt(0xFFF5F7FA);
  static PdfColor get _borderGrey => const PdfColor.fromInt(0xFFE0E0E0);
  static PdfColor get _textSecondary => const PdfColor.fromInt(0xFF757575);

  static final _fmt = NumberFormat('#,##0.00', 'en_US');

  static Future<void> previewAndPrint(
    BuildContext context,
    LedgerData ledger,
  ) async {
    final pdfData = await _buildPdf(ledger);
    if (!context.mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
      name: 'Ledger_${ledger.accountCode}.pdf',
    );
  }

  static Future<Uint8List> _buildPdf(LedgerData ledger) async {
    final doc = pw.Document();
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => _reportHeader(
          'GENERAL LEDGER', '${ledger.accountCode} - ${ledger.accountName}', now),
      footer: _footer,
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _statCard('Total Debit', 'NPR ${_fmt.format(ledger.totalDebit)}', _error),
          pw.SizedBox(width: 8),
          _statCard('Total Credit', 'NPR ${_fmt.format(ledger.totalCredit)}', _secondary),
          pw.SizedBox(width: 8),
          _statCard('Current Balance', 'NPR ${_fmt.format(ledger.currentBalance.abs())}',
              ledger.currentBalance >= 0 ? _secondary : _error),
        ]),
        pw.SizedBox(height: 12),
        if (ledger.entries.isEmpty)
          _emptyMsg('No transactions found for this account.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: _borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // Date
              1: const pw.FlexColumnWidth(4), // Narration
              2: const pw.FlexColumnWidth(2.5), // Debit
              3: const pw.FlexColumnWidth(2.5), // Credit
              4: const pw.FlexColumnWidth(2.5), // Balance
            },
            children: [
              _tableHeader(['Date', 'Narration', 'Debit (NPR)', 'Credit (NPR)', 'Balance']),
              ...ledger.entries.asMap().entries.map((e) {
                final i = e.key;
                final en = e.value;
                final isDr = en.entryType == 'Debit';
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.white : _lightGrey),
                  children: [
                    _td(en.voucherDate),
                    _td(en.narration ?? en.voucherNumber),
                    _td(isDr ? _fmt.format(en.amount) : '-',
                        right: true, color: isDr ? _error : _textSecondary),
                    _td(!isDr ? _fmt.format(en.amount) : '-',
                        right: true, color: !isDr ? _secondary : _textSecondary),
                    _td(_fmt.format(en.runningBalance.abs()), right: true),
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
  // Components
  // ────────────────────────────────────────────────────────────────────────────

  static pw.Widget _reportHeader(String title, String subtitle, String printDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_orgName,
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary)),
                pw.SizedBox(height: 2),
                pw.Text(_orgSubtitle,
                    style: pw.TextStyle(fontSize: 10, color: _textSecondary)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title,
                    style: const pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
                pw.SizedBox(height: 2),
                pw.Text(subtitle,
                    style: pw.TextStyle(fontSize: 10, color: _textSecondary)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Printed: $printDate',
                style: pw.TextStyle(fontSize: 8, color: _textSecondary)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _primary, thickness: 1.5),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Column(children: [
      pw.Divider(color: _borderGrey, thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by SahakariMS',
              style: pw.TextStyle(fontSize: 8, color: _textSecondary)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _textSecondary)),
        ],
      ),
    ]);
  }

  static pw.Widget _statCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(fontSize: 9, color: _textSecondary)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  static pw.TableRow _tableHeader(List<String> cells) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: _primary),
      children: cells
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: pw.Text(
                  c,
                  style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold),
                  textAlign: c.contains('NPR') || c == 'Balance'
                      ? pw.TextAlign.right
                      : pw.TextAlign.left,
                ),
              ))
          .toList(),
    );
  }

  static pw.Widget _td(String text, {bool right = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 9, color: color ?? PdfColors.black),
      ),
    );
  }

  static pw.Widget _emptyMsg(String msg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(msg,
          style: pw.TextStyle(color: _textSecondary, fontSize: 10)),
    );
  }
}
