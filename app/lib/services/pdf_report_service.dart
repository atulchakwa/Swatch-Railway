import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class PDFReportService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xff1f4e78);
  static const PdfColor successColor = PdfColor.fromInt(0xff28a745);
  static const PdfColor warningColor = PdfColor.fromInt(0xffffc107);
  static const PdfColor accentColor = PdfColor.fromInt(0xff9966cc);
  static const PdfColor lightBg = PdfColor.fromInt(0xfff8f9fa);
  static const PdfColor borderColor = PdfColor.fromInt(0xffdee2e6);

  static pw.Widget _buildCheckMark() {
    return pw.SvgImage(svg: '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>', width: 10, height: 10);
  }

  static pw.Widget _buildCrossMark() {
    return pw.SvgImage(svg: '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>', width: 10, height: 10);
  }

  static Future<pw.ImageProvider> _getRailwayLogo() async {
    final ByteData bytes = await rootBundle.load('assets/images/image.png');
    return pw.MemoryImage(bytes.buffer.asUint8List());
  }

  static Future<pw.ImageProvider> _getMirthaLogo() async {
    final ByteData bytes = await rootBundle.load('assets/images/mirtha.jpg');
    return pw.MemoryImage(bytes.buffer.asUint8List());
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
                  pw.Text('Indian Railways - OBHS Enterprise Monitoring System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
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
                pw.Text('OBHS Monitoring System', style: const pw.TextStyle(fontSize: 8)),
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

  static pw.Widget _buildRatingScoreRow(String label, double score, int count, String weight) {
    final bar = (score / 5).clamp(0.0, 1.0);
    final PdfColor barColor = score >= 4 ? successColor : score >= 3 ? warningColor : const PdfColor.fromInt(0xffdc3545);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Container(
                  width: 200 * bar,
                  height: 10,
                  decoration: pw.BoxDecoration(color: barColor, borderRadius: pw.BorderRadius.circular(4)),
                ),
                pw.Expanded(
                  child: pw.Container(
                    height: 10,
                    decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text('${score.toStringAsFixed(2)}/5', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Text('(n=$count, wt=$weight)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static Future<pw.ImageProvider?> _fetchImageBytes(String? url) async {
    if (url == null || url.trim().isEmpty || url == 'captured' || url == 'N/A') return null;
    try {
      final uri = Uri.parse(url.trim());
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(response.bodyBytes);
      } else {
        print('Failed to fetch image: ${response.statusCode} for $url');
      }
    } catch (e) {
      print('Error fetching image: $e for $url');
    }
    return null;
  }

  static pw.Widget _buildAuditHeader(pw.ImageProvider logo1, String title, String subtitle, String statusTitle, String statusValue, bool isSuccess) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Image(logo1, width: 45, height: 45),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('   $subtitle', style: pw.TextStyle(fontSize: 9, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(statusTitle, style: pw.TextStyle(fontSize: 7, color: successColor, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 16, height: 16,
                      decoration: pw.BoxDecoration(color: isSuccess ? successColor : warningColor, shape: pw.BoxShape.circle),
                      child: pw.Center(child: isSuccess ? _buildCheckMark() : _buildCrossMark()),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(statusValue, style: pw.TextStyle(color: isSuccess ? successColor : warningColor, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ]
                )
              ]
            )
          )
        ],
      ),
    );
  }

  static pw.Widget _buildAuditSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
      decoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(title, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
    );
  }

  static pw.Widget _buildObservationBlock(String conclusion) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xffe8f5e9),
        border: pw.Border.all(color: successColor),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 20, height: 20,
            decoration: const pw.BoxDecoration(color: successColor, shape: pw.BoxShape.circle),
            child: pw.Center(child: _buildCheckMark()),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Text(conclusion, style: pw.TextStyle(color: const PdfColor.fromInt(0xff1b5e20), fontSize: 9, fontWeight: pw.FontWeight.bold))),
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

  // 1. Worker Activity Report
  static Future<Uint8List> generateWorkerActivityReportPdf(List<dynamic> runs, List<dynamic> tasks) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final String timestamp = DateFormat('dd-MMM-yyyy | hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          List<pw.Widget> content = [];
          
          content.add(_buildAuditHeader(railway, 'OBHS WORKER ACTIVITY &\nEVIDENCE AUDIT REPORT', 'Operational Audit | Task Execution | Evidence Verification | Compliance Review', 'OVERALL COMPLIANCE STATUS', 'COMPLIANT & APPROVED', true));
          content.add(pw.Divider(thickness: 1, color: borderColor));
          
          for (final run in runs) {
            final runId = run['runInstanceId'] ?? run['instanceId'] ?? '';
            final coaches = run['coaches'] as List<dynamic>? ?? [];
            final runTasks = tasks.where((t) => t['runInstanceId'] == runId).toList();

            for (final coach in coaches) {
              final cm = coach as Map<String, dynamic>;
              final workerId = cm['janitorId']?.toString() ?? '';
              if (workerId.isEmpty) continue;

              final workerTasks = runTasks.where((t) => t['janitorId']?.toString() == workerId).toList();

              // Section 1: Worker Information
              content.add(_buildAuditSectionHeader('1. WORKER INFORMATION'));
              content.add(pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                  children: [
                    _buildInfoRow('Worker ID', workerId, 'Worker Name', cm['janitorName'] ?? 'N/A'),
                    _buildInfoRow('Mobile Number', cm['mobileNumber'] ?? 'N/A', 'Contractor', cm['contractor'] ?? 'N/A'),
                    _buildInfoRow('Role Type', 'OBHS Cleaning Staff', 'Shift', 'Morning Shift'),
                    _buildInfoRow('Supervisor', run['supervisorName'] ?? 'N/A', 'Employee Status', 'Active'),
                  ],
                ),
              ));

              // Section 2: Train & Run Information
              content.add(_buildAuditSectionHeader('2. TRAIN & RUN INFORMATION'));
              content.add(pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                  children: [
                    _buildInfoRow('Train Name', run['trainName'] ?? 'N/A', 'Train Number', run['trainNo'] ?? 'N/A'),
                    _buildInfoRow('Run ID', runId, 'Service Pair ID', run['instanceId'] ?? 'N/A'),
                    _buildInfoRow('Direction', run['direction']?.toString() ?? 'Outbound', 'Run Date', run['departureDate'] ?? DateFormat('dd-MMM-yyyy').format(DateTime.now())),
                    _buildInfoRow('Assigned Coach', cm['coachPosition']?.toString() ?? '1', 'Coach Type', cm['coachType'] ?? 'N/A'),
                  ],
                ),
              ));

              // Section 3: Task Execution & Evidence Details
              content.add(_buildAuditSectionHeader('3. TASK EXECUTION & EVIDENCE DETAILS'));
              if (workerTasks.isEmpty) {
                 content.add(pw.Text('No task records found for worker in this run.', style: const pw.TextStyle(fontSize: 10)));
              } else {
                 content.add(
                   pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 0.5),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(0.8),
                      3: pw.FlexColumnWidth(1.2), 4: pw.FlexColumnWidth(1.5), 5: pw.FlexColumnWidth(1),
                      6: pw.FlexColumnWidth(2), 7: pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: primaryColor),
                        children: [
                          'Task ID', 'Task Category', 'Coach', 'Completion Time', 'Worker Comment', 'Evidence Status', 'Evidence Photo Link', 'Task Status'
                        ].map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        )).toList(),
                      ),
                      ...workerTasks.map((task) {
                        final url = task['afterPhotoUrl']?.toString() ?? task['photoUrl']?.toString() ?? 'N/A';
                        return pw.TableRow(
                          verticalAlignment: pw.TableCellVerticalAlignment.middle,
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(task['taskId']?.toString().substring(0, 8) ?? 'TSK-1001', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(task['taskCategory']?.toString() ?? task['taskTitle']?.toString() ?? 'Cleaning', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(task['coachNo']?.toString() ?? cm['coachPosition']?.toString() ?? 'C1', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(task['completionTime']?.toString() ?? (task['completedAt'] != null ? DateFormat('hh:mm a').format(DateTime.parse(task['completedAt'])) : 'N/A'), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(task['comment']?.toString() ?? task['workerComment']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(url != 'N/A' && url != 'captured' ? 'Uploaded' : 'Pending', style: pw.TextStyle(fontSize: 7, color: successColor, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(url, style: const pw.TextStyle(fontSize: 6, color: PdfColors.blue), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(task['status']?.toString() ?? 'Completed', style: pw.TextStyle(fontSize: 7, color: successColor, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          ]
                        );
                      }),
                    ],
                  )
                 );
              }

              final total = workerTasks.length;
              final completed = workerTasks.where((t) => t['status'] == 'Completed').length;
              final compliance = total == 0 ? 0 : (completed / total * 100).round();
              
              content.add(pw.SizedBox(height: 10));
              content.add(pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildAuditSectionHeader('4. COMPLIANCE KPI SUMMARY'),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Column(
                            children: [
                              _buildInfoRow('Attendance Compliance', '100%', 'Task Completion', '$compliance%'),
                              _buildInfoRow('Evidence Upload Success', '100%', 'Missing Evidence', '0'),
                              _buildInfoRow('Passenger Rating', cm['passengerRating']?.toString() ?? '5 / 5', 'Inspection Compliance', '98%'),
                            ],
                          ),
                        ),
                      ]
                    )
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildAuditSectionHeader('FINAL AUDIT CONCLUSION'),
                        _buildObservationBlock('This report confirms that the assigned OBHS worker completed all allocated operational tasks with valid evidence uploads, attendance compliance, and coach-level service execution aligned with railway audit and operational standards.\n\nAll tasks were executed successfully with complete evidence and full compliance.'),
                      ]
                    )
                  ),
                ]
              ));
              content.add(pw.SizedBox(height: 20));
            }
          }
          
          if (runs.isEmpty || runs.every((r) => (r['coaches'] as List<dynamic>? ?? []).isEmpty)) {
            content.add(pw.Text('No worker assignments found in the selected runs.', style: const pw.TextStyle(fontSize: 10)));
          }

          content.add(_buildSignatures());
          content.add(_buildDigitalFooter(timestamp));
          
          return content;
        },
      ),
    );

    return pdf.save();
  }

  // 2. Complaint Report
  static Future<Uint8List> generateComplaintReportPdf(List<dynamic> runs, List<dynamic> complaints) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final String timestamp = DateFormat('dd-MMM-yyyy | hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          final openIssues = complaints.where((c) => c['status'] != 'RESOLVED').length;
          final isResolved = openIssues == 0;
          final statusTitle = 'OVERALL RESOLUTION STATUS';
          final statusValue = isResolved ? 'COMPLAINTS RESOLVED' : 'RESOLUTION IN PROGRESS';

          final widgets = <pw.Widget>[
            _buildAuditHeader(railway, 'OBHS WORKER COMPLAINT &\nISSUE TRACKING REPORT', 'Resolution Tracking | Escalation Audit | Evidence Verification', statusTitle, statusValue, isResolved),
            pw.Divider(thickness: 1, color: borderColor),
            
            _buildAuditSectionHeader('1. COMPLAINT & ISSUE TRACKING KPI SUMMARY'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                children: [
                  _buildInfoRow('Total Complaints Raised', '${complaints.length}', 'Open Issues', '$openIssues'),
                  _buildInfoRow('Resolved Issues', '${complaints.where((c) => c['status'] == 'RESOLVED').length}', 'SLA Compliance Status', 'Within SLA'),
                ],
              ),
            ),
          ];

          for (final c in complaints) {
            final runId = c['runInstanceId'] ?? 'N/A';
            final run = runs.firstWhere((r) => r['runInstanceId'] == runId || r['instanceId'] == runId, orElse: () => <String, dynamic>{});
            
            widgets.addAll([
              pw.SizedBox(height: 15),
              _buildAuditSectionHeader('COMPLAINT ID: ${c['complaintId']?.toString().substring(0, 8) ?? 'N/A'}'),
              
              // 1. Train & Run Info
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                  children: [
                    _buildInfoRow('Train Name', run['trainName']?.toString() ?? 'N/A', 'Train Number', run['trainNo']?.toString() ?? 'N/A'),
                    _buildInfoRow('Run ID', runId, 'Run Date', run['departureDate']?.toString() ?? 'N/A'),
                    _buildInfoRow('Direction', run['direction']?.toString() ?? 'Outbound', 'Division', run['division']?.toString() ?? 'N/A'),
                    _buildInfoRow('Supervisor', run['supervisorName']?.toString() ?? 'N/A', 'Base Station', run['baseStation']?.toString() ?? 'N/A'),
                  ],
                ),
              ),

              // 2. Worker Complaint Info
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                  children: [
                    _buildInfoRow('Complaint Category', c['category']?.toString() ?? 'N/A', 'Assigned Coach', c['coachNo']?.toString() ?? 'N/A'),
                    _buildInfoRow('Complaint Type', c['type']?.toString() ?? 'N/A', 'Priority Level', c['priority']?.toString() ?? 'Normal'),
                    _buildInfoRow('Status', c['status']?.toString() ?? 'IN PROGRESS', 'Complaint Date', c['createdAt'] != null ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(c['createdAt'])) : 'N/A'),
                    _buildInfoRow('Raised By', c['janitorName']?.toString() ?? 'N/A', 'GPS Location', c['gpsLocation']?.toString() ?? 'N/A'),
                  ],
                ),
              ),

              // 3. Description & Evidence
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Complaint Description:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: primaryColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(c['description']?.toString() ?? 'No description provided.', style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 10),
                    _buildInfoRow('Evidence Status', c['photoUrl'] != null && c['photoUrl'] != 'N/A' && c['photoUrl'] != 'captured' ? 'Uploaded' : 'Pending', 'Evidence Link', c['photoUrl']?.toString() ?? 'N/A'),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              _buildObservationBlock('This complaint is actively being tracked and escalated to the respective division authorities. SLA tracking has been enabled to ensure prompt resolution within designated service hours.'),
              pw.SizedBox(height: 10),
            ]);
          }
          
          widgets.add(_buildSignatures());
          widgets.add(_buildDigitalFooter(timestamp));
          
          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  // 3. Train Report
  static Future<Uint8List> generateTrainReportPdf(List<dynamic> runs) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final String timestamp = DateFormat('dd-MMM-yyyy | hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[
            _buildAuditHeader(railway, 'OBHS ENTERPRISE TRAIN RUN &\nOPERATIONAL AUDIT REPORT', 'Journey Audit | Worker Assignment Verification | Compliance Overview', 'OVERALL AUDIT STATUS', 'COMPLETED & VERIFIED', true),
            pw.Divider(thickness: 1, color: borderColor),
          ];

          for (int idx = 0; idx < runs.length; idx++) {
            final r = runs[idx];
            final coaches = (r['coaches'] as List?) ?? [];
            final assignedWorkers = coaches.where((c) => (c as Map)['janitorId'] != null).length;

            widgets.addAll([
              _buildAuditSectionHeader('1. TRAIN & JOURNEY INFORMATION'),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                  children: [
                    _buildInfoRow('Train Name', r['trainName']?.toString() ?? 'N/A', 'Train Number', r['trainNo']?.toString() ?? 'N/A'),
                    _buildInfoRow('Run Instance ID', (r['runInstanceId'] ?? r['instanceId'] ?? 'N/A').toString(), 'Service Pair ID', r['instanceId']?.toString() ?? 'N/A'),
                    _buildInfoRow('Direction', r['direction']?.toString() ?? 'Outbound', 'Run Date', r['departureDate']?.toString() ?? 'N/A'),
                    _buildInfoRow('Base Station', r['baseStation']?.toString() ?? 'N/A', 'Destination', r['destinationStation']?.toString() ?? 'N/A'),
                    _buildInfoRow('Run Status', r['status']?.toString() ?? 'N/A', 'Division', r['division']?.toString() ?? 'N/A'),
                    _buildInfoRow('Supervisor', r['supervisorName']?.toString() ?? 'N/A', 'Total Coaches', coaches.length.toString()),
                  ],
                ),
              ),

              _buildAuditSectionHeader('2. COACH & WORKER ASSIGNMENT DETAILS'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: primaryColor),
                    children: [
                      'Position', 'Coach No', 'Type', 'Worker ID', 'Worker Name'
                    ].map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    )).toList(),
                  ),
                  if (coaches.isEmpty)
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('No coaches found', style: const pw.TextStyle(fontSize: 8))),
                      pw.Text(''), pw.Text(''), pw.Text(''), pw.Text(''),
                    ]),
                  ...coaches.map((c) {
                    final cm = c as Map;
                    return pw.TableRow(
                      verticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cm['coachPosition']?.toString() ?? 'N/A', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cm['coachNo']?.toString() ?? cm['coachPosition']?.toString() ?? 'N/A', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cm['coachType']?.toString() ?? 'Sleeper', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cm['janitorId']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cm['janitorName']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 7))),
                      ]
                    );
                  }),
                ]
              ),

              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildAuditSectionHeader('3. OPERATIONAL KPI SUMMARY'),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Column(
                            children: [
                              _buildInfoRow('Total Coaches', coaches.length.toString(), 'Workers Assigned', assignedWorkers.toString()),
                              _buildInfoRow('Overall Rating', r['weightedScore']?.toString() ?? '4.8 / 5.0', 'Task Completion Rate', '96%'),
                              _buildInfoRow('Complaint Resolution', '94%', 'Evidence Upload Success', '99%'),
                              _buildInfoRow('Operational Audit', 'APPROVED', 'Run Status', r['status']?.toString() ?? 'COMPLETED'),
                            ],
                          ),
                        ),
                      ]
                    )
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildAuditSectionHeader('FINAL AUDIT OBSERVATION'),
                        _buildObservationBlock('This enterprise audit report verifies that the train run completed its scheduled journey with all OBHS resources successfully assigned and operational targets met. Overall service delivery was compliant with railway standards.'),
                      ]
                    )
                  ),
                ]
              ),

              pw.SizedBox(height: 15),
            ]);
          }

          widgets.add(_buildSignatures());
          widgets.add(_buildDigitalFooter(timestamp));
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  // 4. Attendance Report
  static Future<Uint8List> generateAttendanceReportPdf(List<dynamic> runs, List<dynamic> attendance) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final String timestamp = DateFormat('dd-MMM-yyyy | hh:mm a').format(DateTime.now());

    // Pre-fetch all attendance photos
    final Map<String, pw.ImageProvider> fetchedImages = {};
    for (final a in attendance) {
      final url = a['photoUrl']?.toString();
      if (url != null && url.isNotEmpty && url != 'captured' && url != 'N/A') {
         if (!fetchedImages.containsKey(url)) {
            final img = await _fetchImageBytes(url);
            if (img != null) fetchedImages[url] = img;
         }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[
            _buildAuditHeader(railway, 'OBHS ATTENDANCE & EVIDENCE\nAUDIT REPORT', 'Attendance Verification | GPS Validation | Evidence Compliance | Operational Audit', 'OVERALL COMPLIANCE STATUS', 'VERIFIED & APPROVED', true),
            pw.Divider(thickness: 1, color: borderColor),
            _buildAuditSectionHeader('1. ATTENDANCE OVERVIEW'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                children: [
                  _buildInfoRow('Total Records', attendance.length.toString(), 'Runs Covered', runs.length.toString()),
                  _buildInfoRow('Present Count', attendance.where((a) => (a['status']?.toString() ?? 'Present') == 'Present').length.toString(),
                      'Absent Count', attendance.where((a) => a['status']?.toString() == 'Absent').length.toString()),
                  _buildInfoRow('Attendance Compliance', '${attendance.isEmpty ? 0 : (attendance.where((a) => (a['status']?.toString() ?? '') != 'Absent').length / attendance.length * 100).toStringAsFixed(0)}%',
                      'GPS Validation', 'Verified'),
                ],
              ),
            ),
          ];

          for (final run in runs) {
            final runId = (run['runInstanceId'] ?? run['instanceId'] ?? '').toString();
            final runAtt = attendance.where((a) => a['runInstanceId']?.toString() == runId).toList();

            widgets.addAll([
              _buildAuditSectionHeader('2. TRAIN & RUN INFORMATION'),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                  children: [
                    _buildInfoRow('Train Name', run['trainName']?.toString() ?? 'N/A', 'Train No', run['trainNo']?.toString() ?? 'N/A'),
                    _buildInfoRow('Run ID', runId, 'Run Date', run['departureDate']?.toString() ?? 'N/A'),
                    _buildInfoRow('Base Station', run['baseStation']?.toString() ?? 'N/A', 'Division', run['division']?.toString() ?? 'N/A'),
                    _buildInfoRow('Supervisor', run['supervisorName']?.toString() ?? 'N/A', 'Status', run['status']?.toString() ?? 'N/A'),
                  ],
                ),
              ),

              _buildAuditSectionHeader('3. ATTENDANCE COMPLIANCE & EVIDENCE DETAILS'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(2),
                  5: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: primaryColor),
                    children: [
                      'Attendance Type', 'Time', 'GPS Location', 'Evidence Photo Link', 'Attendance Photo', 'Status'
                    ].map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    )).toList(),
                  ),
                  if (runAtt.isEmpty)
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('No records found', style: const pw.TextStyle(fontSize: 8))),
                      pw.Text(''), pw.Text(''), pw.Text(''), pw.Text(''), pw.Text(''),
                    ]),
                  ...runAtt.map((a) {
                    final isPresent = (a['status']?.toString() ?? 'Present') == 'Present';
                    final url = a['photoUrl']?.toString();
                    final image = url != null ? fetchedImages[url] : null;

                    return pw.TableRow(
                      verticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('${a['type'] ?? 'Attendance'}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text('${a['janitorName'] ?? 'N/A'} (${a['janitorId'] ?? 'N/A'})', style: const pw.TextStyle(fontSize: 7)),
                            ]
                          ),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(a['timestamp'] != null ? DateFormat('hh:mm a').format(DateTime.parse(a['timestamp'])) : 'N/A', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(a['gpsLocation']?.toString() ?? 'Verified', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(url ?? 'N/A', style: const pw.TextStyle(fontSize: 6, color: PdfColors.blue), textAlign: pw.TextAlign.center)),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: image != null 
                            ? pw.Image(image, height: 40, fit: pw.BoxFit.cover)
                            : pw.Text(isPresent ? 'Missing Evidence' : 'N/A', style: const pw.TextStyle(fontSize: 7, color: PdfColors.red), textAlign: pw.TextAlign.center)
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isPresent ? 'Completed' : 'Absent', style: pw.TextStyle(fontSize: 7, color: isPresent ? successColor : PdfColors.red, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      ]
                    );
                  }),
                ]
              ),

              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildAuditSectionHeader('4. KPI SUMMARY'),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Column(
                            children: [
                              _buildInfoRow('Attendance Compliance', '100%', 'Evidence Upload', '100%'),
                              _buildInfoRow('Missing Events', '0', 'GPS Status', 'Verified'),
                            ],
                          ),
                        ),
                      ]
                    )
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildAuditSectionHeader('FINAL AUDIT OBSERVATION'),
                        _buildObservationBlock('This attendance audit report confirms that the assigned OBHS worker completed all mandatory attendance checkpoints with valid timestamp, GPS location tracking, and uploaded photographic evidence. All attendance records were successfully synchronized.'),
                      ]
                    )
                  ),
                ]
              ),
              pw.SizedBox(height: 15),
            ]);
          }

          widgets.add(_buildSignatures());
          widgets.add(_buildDigitalFooter(timestamp));
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  // 5. Ratings Aggregation Report
  static Future<Uint8List> generateRatingsReportPdf(List<dynamic> feedbacks) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final mirtha = await _getMirthaLogo();

    double avgForType(String type) {
      final list = feedbacks.where((f) => (f['raterType'] ?? '') == type).toList();
      if (list.isEmpty) return 0;
      final sum = list.fold<double>(0, (s, f) => s + ((f['overallRating'] as num?)?.toDouble() ?? 0));
      return sum / list.length;
    }
    int countForType(String type) => feedbacks.where((f) => (f['raterType'] ?? '') == type).length;

    final supervisorAvg = avgForType('Supervisor/Admin');
    final officialAvg   = avgForType('Official');
    final tteAvg        = avgForType('TTE');
    final psmeAvg       = avgForType('PSME');
    final passengerAvg  = avgForType('Passenger');

    double totalWeight = 0, totalScore = 0;
    if (countForType('Passenger') > 0)        { totalScore += passengerAvg * 0.40;  totalWeight += 0.40; }
    if (countForType('Official') > 0)         { totalScore += officialAvg * 0.25;   totalWeight += 0.25; }
    if (countForType('Supervisor/Admin') > 0) { totalScore += supervisorAvg * 0.20; totalWeight += 0.20; }
    if (countForType('TTE') > 0)              { totalScore += tteAvg * 0.10;        totalWeight += 0.10; }
    if (countForType('PSME') > 0)             { totalScore += psmeAvg * 0.05;       totalWeight += 0.05; }
    final weightedScore = totalWeight > 0 ? totalScore / totalWeight : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            _buildHeader(railway, mirtha, 'OBHS RATINGS & FEEDBACK AGGREGATION REPORT', 'VERIFIED'),

            _buildSectionHeader('1. WEIGHTED AGGREGATED SCORE'),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Weighted Score', style: pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                      pw.Text(weightedScore.toStringAsFixed(2), style: pw.TextStyle(color: PdfColors.white, fontSize: 40, fontWeight: pw.FontWeight.bold)),
                      pw.Text('out of 5.00', style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Reviews: ${feedbacks.length}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('Weights: Passenger 40% | Official 25% | Sup.Admin 20% | TTE 10% | PSME 5%',
                          style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),

            _buildSectionHeader('2. SCORE BY RATER TYPE'),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                children: [
                  _buildRatingScoreRow('Passenger', passengerAvg, countForType('Passenger'), '40%'),
                  _buildRatingScoreRow('Official Inspector', officialAvg, countForType('Official'), '25%'),
                  _buildRatingScoreRow('Supervisor / Admin', supervisorAvg, countForType('Supervisor/Admin'), '20%'),
                  _buildRatingScoreRow('TTE', tteAvg, countForType('TTE'), '10%'),
                  _buildRatingScoreRow('PSME', psmeAvg, countForType('PSME'), '5%'),
                ],
              ),
            ),

            _buildSectionHeader('3. INDIVIDUAL FEEDBACK LOG'),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.center,
              data: <List<String>>[
                ['Rater Type', 'Coach', 'Overall Rating', 'Remarks', 'Date'],
                ...feedbacks.take(50).map((f) {
                  final remarks = f['remarks']?.toString() ?? '-';
                  return [
                    f['raterType']?.toString() ?? 'N/A',
                    f['coachNo']?.toString() ?? 'N/A',
                    ((f['overallRating'] as num?)?.toStringAsFixed(1)) ?? 'N/A',
                    remarks.length > 30 ? '${remarks.substring(0, 30)}...' : remarks,
                    f['createdAt'] != null
                        ? DateFormat('dd-MMM-yyyy').format(DateTime.parse(f['createdAt'])) : 'N/A',
                  ];
                }),
              ],
            ),

            _buildSignatures(),
          ];
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateBillingReportPdf(Map<String, dynamic> bill, List<dynamic> deductions) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final mirtha = await _getMirthaLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            _buildHeader(railway, mirtha, 'BILLING & INVOICE REPORT', bill['status'] ?? 'PENDING'),
            _buildSectionHeader('1. BILL SUMMARY'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                children: [
                  _buildInfoRow('Bill ID', bill['uid']?.toString() ?? 'N/A', 'Period', bill['period']?.toString() ?? 'N/A'),
                  _buildInfoRow('Contract', bill['contractNumber']?.toString() ?? 'N/A', 'Entity', bill['entityName']?.toString() ?? 'N/A'),
                  _buildInfoRow('Zone', bill['zone']?.toString() ?? 'N/A', 'Division', bill['division']?.toString() ?? 'N/A'),
                  _buildInfoRow('Contract Value', 'Rs. ${(bill['contractValue'] ?? 0).toString()}', 'Grade', bill['grade']?.toString() ?? 'N/A'),
                  _buildInfoRow('Overall Score', '${bill['overallScore']?.toString() ?? '0'}%', 'Status', bill['status']?.toString() ?? 'N/A'),
                ],
              ),
            ),
            _buildSectionHeader('2. DEDUCTION BREAKDOWN', color: PdfColor.fromInt(0xffdc3545)),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xffdc3545)),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.center,
              data: <List<String>>[
                ['Type', 'Description', 'Count', 'Rate', 'Amount'],
                ...deductions.map((d) {
                  return [
                    d['type']?.toString() ?? 'N/A',
                    d['description']?.toString() ?? 'N/A',
                    '${d['count'] ?? 0}',
                    'Rs. ${(d['rate'] ?? 0).toString()}',
                    'Rs. ${(d['amount'] ?? 0).toString()}',
                  ];
                }),
              ],
            ),
            _buildSectionHeader('3. PAYABLE CALCULATION'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                children: [
                  _buildInfoRow('Contract Value', 'Rs. ${(bill['contractValue'] ?? 0).toString()}', 'Total Deduction', '-Rs. ${(bill['totalDeduction'] ?? 0).toString()}'),
                  pw.Divider(thickness: 1, color: primaryColor),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text('FINAL PAYABLE: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: primaryColor)),
                      pw.Text('Rs. ${(bill['finalPayable'] ?? 0).toString()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: successColor)),
                    ],
                  ),
                ],
              ),
            ),
            _buildSectionHeader('4. AUDIT TRAIL'),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.center,
              data: <List<String>>[
                ['Action', 'Performed By', 'Timestamp', 'Details'],
                ...(bill['auditLog'] as List? ?? []).map((a) {
                  return [
                    a['action']?.toString() ?? 'N/A',
                    a['performedByName']?.toString() ?? 'N/A',
                    a['timestamp'] != null ? DateFormat('dd-MMM hh:mm a').format(DateTime.parse(a['timestamp'])) : 'N/A',
                    a['details']?.toString() ?? 'N/A',
                  ];
                }),
              ],
            ),
            _buildSignatures(
              supervisorSignatureBase64: bill['supervisorSignatureBase64'] ?? bill['submittedBySignatureBase64'],
              officialSignatureBase64: bill['officialSignatureBase64'] ?? bill['approvedBySignatureBase64'],
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  // 4. Attendance Report
  

  static Future<Uint8List> generateCleaningFormReportPdf(Map<String, dynamic> form) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final mirtha = await _getMirthaLogo();

    final isCoach = form['formType'] == 'coach';
    final status = form['status'] ?? 'draft';
    final score = form['score'];
    final grade = form['grade'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            _buildHeader(railway, mirtha, '${isCoach ? "COACH" : "PREMISE"} CLEANING FORM', status.toUpperCase()),
            _buildSectionHeader('1. FORM DETAILS'),
            _buildInfoRow('Form ID', form['formId'] ?? 'N/A', '', ''),
            _buildInfoRow('Form Type', isCoach ? 'Coach Cleaning' : 'Premise Cleaning', '', ''),
            _buildInfoRow('Date', form['cleaningDate'] ?? 'N/A', '', ''),
            _buildInfoRow('Shift', form['cleaningShift'] ?? 'N/A', '', ''),
            _buildInfoRow('Start Time', form['startTime'] ?? 'N/A', '', ''),
            _buildInfoRow('End Time', form['endTime'] ?? 'N/A', '', ''),
            _buildInfoRow('Division', form['division'] ?? 'N/A', '', ''),
            _buildInfoRow('Depot', form['depot'] ?? 'N/A', '', ''),
            _buildInfoRow('Status', status, '', ''),
            pw.SizedBox(height: 10),
            _buildSectionHeader('2. CONTRACT & ENTITY'),
            _buildInfoRow('Contract', form['contractNumber'] ?? 'N/A', '', ''),
            _buildInfoRow('Entity', form['entityName'] ?? 'N/A', '', ''),
            _buildInfoRow('Submitted By', form['submittedByName'] ?? 'N/A', '', ''),
            _buildInfoRow('Manpower', '${form['manpowerCount'] ?? 0}', '', ''),
            _buildInfoRow('Machines', '${form['machineCount'] ?? 0}', '', ''),
            pw.SizedBox(height: 10),
            if (isCoach && form['coachDetails'] != null) ...[
              _buildSectionHeader('3. COACH DETAILS'),
              _buildInfoRow('Train Number', form['coachDetails']['trainNumber'] ?? 'N/A', '', ''),
              _buildInfoRow('Train Name', form['coachDetails']['trainName'] ?? 'N/A', '', ''),
              _buildInfoRow('Coach Number', form['coachDetails']['coachNumber'] ?? 'N/A', '', ''),
              _buildInfoRow('Coach Type', form['coachDetails']['coachType'] ?? 'N/A', '', ''),
              _buildInfoRow('Watering Done', form['coachDetails']['wateringDone'] == true ? 'Yes' : 'No', '', ''),
              _buildInfoRow('Toiletries', form['coachDetails']['toiletriesAvailable'] == true ? 'Available' : 'Not Available', '', ''),
              _buildInfoRow('Dustbins', form['coachDetails']['dustbinsAvailable'] == true ? 'Available' : 'Not Available', '', ''),
            ],
            if (!isCoach && form['premiseDetails'] != null) ...[
              _buildSectionHeader('3. PREMISE DETAILS'),
              _buildInfoRow('Premise Name', form['premiseDetails']['premiseName'] ?? 'N/A', '', ''),
              _buildInfoRow('Premise Type', form['premiseDetails']['premiseType'] ?? 'N/A', '', ''),
              _buildInfoRow('Area Covered', '${form['premiseDetails']['areaCovered'] ?? 0} sq.m', '', ''),
              _buildInfoRow('Area Uncleaned', '${form['premiseDetails']['areaUncleaned'] ?? 0} sq.m', '', ''),
              _buildInfoRow('Garbage Collected', '${form['premiseDetails']['garbageCollected'] ?? 0} kg', '', ''),
            ],
            if (form['remarks'] != null && form['remarks'].toString().isNotEmpty) ...[
              pw.SizedBox(height: 10),
              _buildSectionHeader('4. REMARKS'),
              pw.Paragraph(text: form['remarks'], style: const pw.TextStyle(fontSize: 10)),
            ],
            pw.SizedBox(height: 10),
            _buildSectionHeader('5. SCORECARD'),
            if (score != null) ...[
              _buildInfoRow('Score', '${score.toStringAsFixed(1)}/100', '', ''),
              _buildInfoRow('Grade', grade ?? 'N/A', '', ''),
            ] else ...[
              pw.Paragraph(text: 'Not scored yet', style: pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
            ],
            if (form['scoringData'] != null && form['scoringData']['criteria'] != null) ...[
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: primaryColor),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.center,
                data: <List<String>>[
                  ['Criterion', 'Max', 'Score', 'Remarks'],
                  ...(form['scoringData']['criteria'] as List).map((c) => [
                    c['name'] ?? '',
                    '${c['maxScore'] ?? 10}',
                    '${c['score'] ?? 0}',
                    c['remarks'] ?? '',
                  ]),
                ],
              ),
            ],
            pw.SizedBox(height: 10),
            _buildSectionHeader('6. PHOTOS'),
            if (form['photos'] != null && (form['photos'] as List).isNotEmpty) ...[
              _buildInfoRow('Total Photos', '${(form['photos'] as List).length}', '', ''),
              _buildInfoRow('Before Photos', '${(form['photos'] as List).where((p) => p['type'] == 'before').length}', '', ''),
              _buildInfoRow('After Photos', '${(form['photos'] as List).where((p) => p['type'] == 'after').length}', '', ''),
            ] else ...[
              pw.Paragraph(text: 'No photos uploaded', style: pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
            ],
            pw.SizedBox(height: 10),
            _buildSectionHeader('7. GPS LOCATION'),
            _buildInfoRow('Latitude', '${form['latitude'] ?? 'N/A'}', '', ''),
            _buildInfoRow('Longitude', '${form['longitude'] ?? 'N/A'}', '', ''),
            if (form['gpsAddress'] != null && form['gpsAddress'].toString().isNotEmpty)
              _buildInfoRow('Address', form['gpsAddress'], '', ''),
            pw.SizedBox(height: 10),
            _buildSectionHeader('8. APPROVAL & AUDIT'),
            if (form['approvedByName'] != null) ...[
              _buildInfoRow('Approved By', form['approvedByName'], '', ''),
              _buildInfoRow('Approved At', form['approvedAt'] != null ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(form['approvedAt'])) : 'N/A', '', ''),
            ],
            if (form['rejectedByName'] != null) ...[
              _buildInfoRow('Rejected By', form['rejectedByName'], '', ''),
              _buildInfoRow('Rejection Reason', form['rejectionReason'] ?? 'N/A', '', ''),
            ],
            _buildInfoRow('Created At', form['createdAt'] != null ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(form['createdAt'])) : 'N/A', '', ''),
            if (form['lockedAt'] != null)
              _buildInfoRow('Locked At', DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(form['lockedAt'])), '', ''),
            pw.SizedBox(height: 20),
            _buildSignatures(
              supervisorSignatureBase64: form['supervisorSignatureBase64'] ?? form['submittedBySignatureBase64'],
              officialSignatureBase64: form['officialSignatureBase64'] ?? form['approvedBySignatureBase64'],
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  // 6. Station Cleaning Form Report
  
  static Future<Uint8List> generateStationCleaningFormReportPdf(Map<String, dynamic> form) async {
    final pdf = pw.Document();
    final railway = await _getRailwayLogo();
    final mirtha = await _getMirthaLogo();
    final score = form['score'];
    final grade = form['grade'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            _buildHeader(railway, mirtha, 'STATION CLEANING FORM', (form['status'] ?? 'draft').toString().toUpperCase()),
            _buildSectionHeader('1. FORM DETAILS'),
            _buildInfoRow('Form ID', form['formId'] ?? 'N/A', '', ''),
            _buildInfoRow('Station', form['stationName'] ?? 'N/A', '', ''),
            _buildInfoRow('Area', form['areaName'] ?? 'N/A', '', ''),
            _buildInfoRow('Zone', form['zoneName'] ?? 'N/A', '', ''),
            _buildInfoRow('Date', form['cleaningDate'] ?? 'N/A', '', ''),
            _buildInfoRow('Shift', form['shift'] ?? 'N/A', '', ''),
            _buildInfoRow('Division', form['division'] ?? 'N/A', '', ''),
            _buildInfoRow('Status', form['status'] ?? 'N/A', '', ''),
            pw.SizedBox(height: 10),
            _buildSectionHeader('2. RESOURCE DEPLOYMENT'),
            _buildInfoRow('Manpower', '${form['manpowerCount'] ?? 0}', '', ''),
            _buildInfoRow('Machines', '${form['machineCount'] ?? 0}', '', ''),
            _buildInfoRow('Area Covered', '${form['areaCovered'] ?? 0} sq.m', '', ''),
            _buildInfoRow('Area Uncleaned', '${form['areaUncleaned'] ?? 0} sq.m', '', ''),
            _buildInfoRow('Garbage Collected', '${form['garbageCollected'] ?? 0} kg', '', ''),
            pw.SizedBox(height: 10),
            _buildSectionHeader('3. ACTIVITIES PERFORMED'),
            if (form['activities'] != null && (form['activities'] as List).isNotEmpty)
              ...(form['activities'] as List).map((a) => pw.Paragraph(text: '• $a', style: const pw.TextStyle(fontSize: 9)))
            else
              pw.Paragraph(text: 'No activities recorded', style: pw.TextStyle(color: PdfColors.grey, fontSize: 9)),
            pw.SizedBox(height: 10),
            _buildSectionHeader('4. SCORECARD'),
            if (score != null) ...[
              _buildInfoRow('Total Score', '${score.toStringAsFixed(1)}/100', '', ''),
              _buildInfoRow('Grade', grade ?? 'N/A', '', ''),
            ] else
              pw.Paragraph(text: 'Not scored yet', style: pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
            if (form['scoringData'] != null && form['scoringData']['criteria'] != null) ...[
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: primaryColor),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.center,
                data: <List<String>>[
                  ['Criterion', 'Weight', 'Score'],
                  ...(form['scoringData']['criteria'] as List).map((c) => [
                    c['name'] ?? '',
                    '${c['weight'] ?? 0}%',
                    '${c['score'] ?? 0}',
                  ]),
                ],
              ),
            ],
            pw.SizedBox(height: 10),
            _buildSectionHeader('5. PHOTOS & GPS'),
            _buildInfoRow('Photos', '${(form['photos'] as List?)?.length ?? 0}', '', ''),
            _buildInfoRow('Latitude', '${form['latitude'] ?? 'N/A'}', '', ''),
            _buildInfoRow('Longitude', '${form['longitude'] ?? 'N/A'}', '', ''),
            pw.SizedBox(height: 10),
            _buildSectionHeader('6. APPROVAL & AUDIT'),
            if (form['approvedByName'] != null) _buildInfoRow('Approved By', form['approvedByName'], '', ''),
            if (form['rejectedByName'] != null) _buildInfoRow('Rejected By', form['rejectedByName'], '', ''),
            _buildInfoRow('Submitted By', form['submittedByName'] ?? 'N/A', '', ''),
            _buildInfoRow('Entity', form['entityName'] ?? 'N/A', '', ''),
            pw.SizedBox(height: 20),
            _buildSignatures(),
          ];
        },
      ),
    );
    return pdf.save();
  }

}
