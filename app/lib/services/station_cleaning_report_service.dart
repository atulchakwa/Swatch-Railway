import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:crm_train/model/station_cleaning_models.dart';

class StationCleaningReportService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xff1f4e78);
  static const PdfColor successColor = PdfColor.fromInt(0xff28a745);
  static const PdfColor warningColor = PdfColor.fromInt(0xffffc107);
  static const PdfColor accentColor = PdfColor.fromInt(0xff9966cc);
  static const PdfColor lightBg = PdfColor.fromInt(0xfff8f9fa);
  static const PdfColor borderColor = PdfColor.fromInt(0xffdee2e6);
  static const String systemTitle = 'Indian Railways - Station Cleaning Enterprise Monitoring System';
  static const String signatureTitle = 'Station Cleaning Monitoring System';
  static Uint8List? _railwayLogoBytes;
  static Uint8List? _mirthaLogoBytes;

  static Future<ui.Image> _loadUiImage(String assetPath) async {
    final ByteData bytes = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(), targetWidth: 120, targetHeight: 120);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<ByteData?> _resizeImage(ui.Image image, int size) async {
    final double w = image.width.toDouble();
    final double h = image.height.toDouble();
    final double sizeD = size.toDouble();
    final double scale = (w > h) ? sizeD / w : sizeD / h;
    final ui.Size outSize = ui.Size(w * scale, h * scale);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Rect.fromLTWH(0, 0, outSize.width, outSize.height),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final img = await picture.toImage(outSize.width.round(), outSize.height.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data;
  }

  static Future<pw.ImageProvider> _getRailwayLogo() async {
    if (_railwayLogoBytes != null) return pw.MemoryImage(_railwayLogoBytes!);
    final ui.Image image = await _loadUiImage('assets/images/image.png');
    final ByteData? out = await _resizeImage(image, 120);
    image.dispose();
    _railwayLogoBytes = out!.buffer.asUint8List();
    return pw.MemoryImage(out.buffer.asUint8List());
  }

  static Future<pw.ImageProvider> _getMirthaLogo() async {
    if (_mirthaLogoBytes != null) return pw.MemoryImage(_mirthaLogoBytes!);
    final ui.Image image = await _loadUiImage('assets/images/mirtha.jpg');
    final ByteData? out = await _resizeImage(image, 120);
    image.dispose();
    _mirthaLogoBytes = out!.buffer.asUint8List();
    return pw.MemoryImage(out.buffer.asUint8List());
  }

  static pw.Widget _buildHeader(pw.ImageProvider logo1, pw.ImageProvider logo2, String title, String status) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: primaryColor, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Image(logo1, width: 50, height: 50),
              pw.SizedBox(width: 15),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.Text(systemTitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: status == 'COMPLIANT' || status == 'RESOLVED' ? successColor : warningColor,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(status, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Generated: ${DateFormat('dd-MMM-yyyy | hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(width: 15),
              pw.Image(logo2, width: 50, height: 50),
            ],
          )
        ],
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title, {PdfColor color = primaryColor}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const pw.EdgeInsets.only(top: 15, bottom: 8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
    );
  }

  static pw.Widget _buildInfoRow(String label1, String value1, String label2, String value2) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor))),
          pw.Text(':', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 5),
          pw.Expanded(child: pw.Text(value1, style: const pw.TextStyle(fontSize: 10))),
          pw.SizedBox(width: 20),
          pw.Expanded(child: pw.Text(label2, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor))),
          pw.Text(':', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 5),
          pw.Expanded(child: pw.Text(value2, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  static pw.Widget _buildDigitalFooter(String timestamp) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 15),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primaryColor),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Icon(const pw.IconData(0xe897), color: primaryColor, size: 24), // Lock icon
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('This is a system-generated report and digitally validated.', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Generated On: $timestamp', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('Unauthorized modification is strictly prohibited.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.red)),
              ]
            )
          )
        ]
      )
    );
  }

  static pw.Widget _buildSignatures({String? supervisorSignatureBase64, String? officialSignatureBase64}) {
    pw.ImageProvider? supervisorImg;
    pw.ImageProvider? officialImg;
    try {
      if (supervisorSignatureBase64 != null && supervisorSignatureBase64.isNotEmpty) {
        supervisorImg = pw.MemoryImage(base64Decode(supervisorSignatureBase64));
      }
      if (officialSignatureBase64 != null && officialSignatureBase64.isNotEmpty) {
        officialImg = pw.MemoryImage(base64Decode(officialSignatureBase64));
      }
    } catch (_) {}

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 30),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primaryColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(6),
            color: primaryColor,
            child: pw.Text('APPROVAL & AUTHENTICATION', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(children: [
                if (supervisorImg != null)
                  pw.Image(supervisorImg, height: 40)
                else
                  pw.SizedBox(height: 40),
                pw.Container(width: 100, height: 1, color: PdfColors.grey),
                pw.SizedBox(height: 5),
                pw.Text('Supervisor', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('System Validated', style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.Column(children: [
                pw.SizedBox(height: 40),
                pw.Container(width: 100, height: 1, color: PdfColors.grey),
                pw.SizedBox(height: 5),
                pw.Text('Audit Verified By', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text(signatureTitle, style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.Column(children: [
                if (officialImg != null)
                  pw.Image(officialImg, height: 40)
                else
                  pw.SizedBox(height: 40),
                pw.Container(width: 100, height: 1, color: PdfColors.grey),
                pw.SizedBox(height: 5),
                pw.Text('Report Approved By', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Divisional Operations Manager', style: const pw.TextStyle(fontSize: 8)),
              ]),
            ]
          )
        ]
      )
    );
  }

  static String _formatLabel(String key) {
    return key
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
        .replaceAll('_', ' ')
        .trim()
        .toUpperCase();
  }

  static String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is double) return value.toStringAsFixed(1);
    return value.toString();
  }

  static Future<Uint8List> generateStationReportPdf(StationReport report) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final mirtha = await _getMirthaLogo();
    final timestamp = DateFormat('dd-MMM-yyyy | hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          final summary = report.summary;
          final kpiEntries = <MapEntry<String, dynamic>>[];
          final arrayEntries = <MapEntry<String, List<dynamic>>>[];

          summary.forEach((key, value) {
            if (value is List) {
              arrayEntries.add(MapEntry(key, value));
            } else {
              kpiEntries.add(MapEntry(key, value));
            }
          });

          final widgets = <pw.Widget>[
            _buildHeader(railway, mirtha, 'Station Cleaning Report', report.reportType.replaceAll('_', ' ').toUpperCase()),
            pw.Divider(thickness: 1, color: borderColor),
            _buildInfoRow('Station', report.stationName, 'Report Type', report.reportType.replaceAll('_', ' ')),
            _buildInfoRow('Date', report.date, 'Month/Year', '${report.month}/${report.year}'),
            _buildInfoRow('Generated By', report.generatedByName, 'Generated At', timestamp),
            pw.SizedBox(height: 10),
          ];

          if (kpiEntries.isNotEmpty) {
            widgets.add(_buildSectionHeader('Key Metrics'));
            final headerCells = <String>[];
            final valueRows = <List<String>>[];
            for (var i = 0; i < kpiEntries.length; i += 2) {
              final left = kpiEntries[i];
              final right = i + 1 < kpiEntries.length ? kpiEntries[i + 1] : null;
              headerCells.add(_formatLabel(left.key));
              if (right != null) headerCells.add(_formatLabel(right.key));
              valueRows.add([
                _formatValue(left.value),
                right != null ? _formatValue(right.value) : '',
              ]);
            }
            final uniqueHeaders = headerCells.toSet().toList();
            if (uniqueHeaders.length <= 4) {
              widgets.add(
                pw.Table(
                  border: pw.TableBorder.all(color: borderColor, width: 0.5),
                  columnWidths: uniqueHeaders.length <= 2
                      ? <int, pw.TableColumnWidth>{0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)}
                      : <int, pw.TableColumnWidth>{0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)},
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: primaryColor),
                      children: uniqueHeaders.map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center),
                      )).toList(),
                    ),
                    ...valueRows.map((row) => pw.TableRow(
                      children: row.map((v) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(v, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                      )).toList(),
                    )),
                  ],
                ),
              );
            } else {
              widgets.add(
                pw.TableHelper.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
                  headerDecoration: pw.BoxDecoration(color: primaryColor),
                  cellStyle: pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.center,
                  data: [
                    kpiEntries.map((e) => _formatLabel(e.key)).toList(),
                    kpiEntries.map((e) => _formatValue(e.value)).toList(),
                  ],
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 10));
          }

          for (final entry in arrayEntries) {
            if (entry.value.isEmpty) continue;
            widgets.add(_buildSectionHeader(_formatLabel(entry.key)));
            final records = entry.value;
            final allKeys = <String>{};
            for (final record in records) {
              if (record is Map) allKeys.addAll(record.keys.cast<String>());
            }
            final keys = allKeys.take(6).toList();
            if (keys.isEmpty) continue;
            final dataRows = records.map((record) {
              if (record is Map) {
                return keys.map((k) => _formatValue(record[k])).toList();
              }
              return [_formatValue(record)];
            }).toList();
            widgets.add(
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
                headerDecoration: pw.BoxDecoration(color: PdfColors.teal),
                cellStyle: pw.TextStyle(fontSize: 7),
                cellAlignment: pw.Alignment.center,
                data: [
                  keys.map((k) => _formatLabel(k)).toList(),
                  ...dataRows,
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 8));
          }

          widgets.add(pw.SizedBox(height: 20));
          widgets.add(_buildSignatures());
          widgets.add(_buildDigitalFooter(timestamp));
          return widgets;
        },
      ),
    );
    return pdf.save();
  }
}
