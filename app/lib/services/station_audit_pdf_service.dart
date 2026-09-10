import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Compact PDF builder for station-cleaning audit reports.
class StationAuditPdfService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xff1f4e78);
  static const PdfColor lightBg = PdfColor.fromInt(0xfff0f4fa);
  static const PdfColor borderColor = PdfColor.fromInt(0xffd9e2ef);

  static Future<Uint8List> generateAuditPdf({
    required String reportType,
    required String stationName,
    required Map<String, dynamic> result,
  }) async {
    final pdf = pw.Document();
    final summary = Map<String, dynamic>.from(result['summary'] ?? {});
    final countLabels = {
      'user-activity': 'Activity Records',
      'image-archive': 'Image Evidence',
      'rejected-forms': 'Rejected Forms',
      'inspection-history': 'Inspections',
      'data-modification': 'Modifications',
    };
    final label = countLabels[reportType] ?? 'Records';

    final recordKeys = [
      'records',
      'inspections',
      'images',
      'forms',
      'modifications',
    ];

    pw.MemoryImage logo;
    try {
      final bytes = await rootBundle.load('assets/images/image.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      logo = pw.MemoryImage(Uint8List(0));
    }

    final headerCounts = summary.entries
        .where(
          (e) =>
              e.key.startsWith('total') || e.value is num || e.value is String,
        )
        .map((e) => '${_label(e.key)}: ${e.value}')
        .take(6)
        .join('   |   ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: borderColor)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Swachh Railway | Station Cleaning',
                style: pw.TextStyle(color: primaryColor, fontSize: 10),
              ),
              pw.Text(
                'Generated: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: pw.TextStyle(color: PdfColors.grey, fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Row(
            children: [
              if (logo.bytes.isNotEmpty)
                pw.Container(
                  width: 44,
                  height: 44,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'STATION CLEANING - AUDIT REPORT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      _reportTitle(reportType),
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Station: $stationName',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (headerCounts.isNotEmpty) pw.SizedBox(height: 3),
                if (headerCounts.isNotEmpty)
                  pw.Text(
                    headerCounts,
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                if (result['query'] != null) pw.SizedBox(height: 3),
                if (result['query'] != null)
                  pw.Text(
                    'Query: ${result['query']}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          for (final key in recordKeys)
            ..._buildSection(context, summary[key], _label(key), label),
        ],
      ),
    );

    return pdf.save();
  }

  static List<pw.Widget> _buildSection(
    pw.Context context,
    dynamic list,
    String title,
    String fallbackLabel,
  ) {
    if (list is! List || list.isEmpty) return const [];
    final records = list.cast<Map>();
    final unionKeys = <String>{};
    for (final r in records) {
      r.keys.take(12).forEach((k) => unionKeys.add('$k'));
    }
    final keys = unionKeys.take(10).toList();
    if (keys.isEmpty) return const [];

    return [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Table.fromTextArray(
        headers: keys.map(_label).toList(),
        data: records
            .map((r) => keys.map((k) => _cellText(r[k])).toList())
            .toList(),
        headerStyle: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(color: primaryColor),
        cellStyle: pw.TextStyle(fontSize: 7),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: pw.BoxDecoration(color: lightBg),
        columnWidths: {
          for (var i = 0; i < keys.length; i++)
            i: pw.FlexColumnWidth(i == keys.length - 1 ? 2 : 1),
        },
      ),
      pw.SizedBox(height: 10),
      pw.Paragraph(
        text: 'Total $title: ${records.length}',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 12),
    ];
  }

  static String _cellText(dynamic v) {
    if (v == null) return '';
    final s = '$v';
    if (v is Map || v is List) {
      return s.length > 120 ? '${s.substring(0, 120)}…' : s;
    }
    return s;
  }

  static String _label(String key) {
    final spaced = key.replaceAll(RegExp('([a-z])([A-Z])'), r'$1 $2');
    final words = spaced.replaceAll('_', ' ');
    if (words.isEmpty) return key;
    return words[0].toUpperCase() + words.substring(1);
  }

  static String _reportTitle(String reportType) {
    switch (reportType) {
      case 'user-activity':
        return 'User Activity Audit';
      case 'image-archive':
        return 'Image Evidence Archive';
      case 'rejected-forms':
        return 'Rejected/Resubmitted Forms';
      case 'inspection-history':
        return 'Inspection History';
      case 'data-modification':
        return 'Data Modification Audit';
      default:
        return reportType;
    }
  }
}
