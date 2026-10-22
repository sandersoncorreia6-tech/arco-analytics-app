import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:arco_analytics/domain/analysis/reports.dart';

/// PDF e compartilhamento (WhatsApp, e-mail...) dos relatórios.
class ReportExport {
  /// A fonte padrão do PDF cobre o Latin-1 (acentos ok); troca os símbolos fora dele.
  static String _safe(String s) =>
      s.replaceAll('•', '-').replaceAll('–', '-').replaceAll('—', '-').replaceAll('…', '...').replaceAll('’', "'").replaceAll(RegExp(r'[^\x00-\xFF]'), '');

  static Future<Uint8List> pdf(ArcoReport r) async {
    final doc = pw.Document(title: r.title, author: 'ARCO Analytics');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.deepPurple300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ARCO Analytics',
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700),
              ),
              pw.Text('Dado > Contexto > Insight > Decisao', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ),
        footer: (c) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Pagina ${c.pageNumber}/${c.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
        build: (_) => [
          pw.SizedBox(height: 10),
          pw.Text(_safe(r.title), style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(_safe(r.subtitle), style: const pw.TextStyle(color: PdfColors.grey700)),
          for (final s in r.sections.where((s) => s.lines.isNotEmpty)) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              _safe(s.heading),
              style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple700),
            ),
            pw.SizedBox(height: 4),
            for (final l in s.lines) pw.Bullet(text: _safe(l), style: const pw.TextStyle(fontSize: 10.5), bulletColor: PdfColors.deepPurple300),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static String fileName(ArcoReport r) => '${r.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}.pdf';

  static Future<void> sharePdf(ArcoReport r) async => Printing.sharePdf(bytes: await pdf(r), filename: fileName(r));

  static Future<void> printPdf(ArcoReport r) async => Printing.layoutPdf(onLayout: (_) => pdf(r), name: fileName(r));

  /// Texto formatado para WhatsApp/e-mail.
  static Future<void> shareText(ArcoReport r) async => SharePlus.instance.share(ShareParams(text: r.toPlainText(), subject: r.title));
}
