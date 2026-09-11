import 'dart:convert';
import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/repositories/station_report_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/services/pdf_report_service.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportListScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String? role;
  const ReportListScreen({super.key, required this.stationId, required this.stationName, this.role});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingReports = false;
  bool _isLoadingSchedules = false;

  List<StationReport> _reports = [];
  List<Map<String, dynamic>> _schedules = [];

  String? _filterReportType;
  int _filterMonth = DateTime.now().month;
  int _filterYear = DateTime.now().year;

  final List<String> _allReportTypes = [
    'daily_attendance', 'daily_activity', 'daily_scorecard', 'daily_complaint',
    'daily_feedback', 'daily_inspection', 'daily_supervisor_log', 'missed_activity',
    'archive_retrieval',
    'monthly_attendance', 'monthly_cleaning', 'monthly_scorecard',
    'monthly_complaint', 'monthly_feedback', 'monthly_billing', 'monthly_penalty',
    'monthly_performance',
  ];

  static const _contractorSupervisorTypes = [
    'daily_attendance', 'daily_activity', 'daily_scorecard', 'daily_complaint',
    'daily_feedback', 'missed_activity',
  ];

  late final List<String> _reportTypes = _getReportTypes();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReports();
    _loadSchedules();
  }

  List<String> _getReportTypes() {
    final r = (widget.role ?? '').toUpperCase();
    if (r == 'CONTRACTOR_SUPERVISOR' || r == 'CONTRACTOR_ADMIN') return _contractorSupervisorTypes;
    return _allReportTypes;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final query = <String, String>{
        'stationId': widget.stationId,
        'month': _filterMonth.toString(),
        'year': _filterYear.toString(),
      };
      if (_filterReportType != null) query['reportType'] = _filterReportType!;
      var list = await StationReportRepository.list(query);
      final r = (widget.role ?? '').toUpperCase();
      if (r == 'CONTRACTOR_ADMIN' || r == 'CONTRACTOR_SUPERVISOR') {
        list = list.where((report) => _contractorSupervisorTypes.contains(report.reportType)).toList();
      }
      setState(() => _reports = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reports: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoadingSchedules = true);
    try {
      final list = await StationReportRepository.listSchedules();
      setState(() => _schedules = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load schedules: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSchedules = false);
    }
  }

  void _showGenerateDialog() {
    String selectedType = _reportTypes.first;
    DateTime selectedDate = DateTime.now();
    DateTime archiveStartDate = DateTime.now().subtract(const Duration(days: 7));
    DateTime archiveEndDate = DateTime.now();
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;
    var isDaily = selectedType.startsWith('daily_') || selectedType == 'missed_activity';
    var isArchive = selectedType == 'archive_retrieval';
    bool datePicked = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Generate Report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Report Type', border: OutlineInputBorder()),
                  items: _reportTypes.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.replaceAll('_', ' ').toUpperCase()),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedType = val;
                        isDaily = val.startsWith('daily_') || val == 'missed_activity';
                        isArchive = val == 'archive_retrieval';
                        datePicked = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (isArchive) ...[
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: archiveStartDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() { archiveStartDate = picked; datePicked = true; });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder()),
                      child: Text('${archiveStartDate.year}-${archiveStartDate.month.toString().padLeft(2, '0')}-${archiveStartDate.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: archiveEndDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() { archiveEndDate = picked; datePicked = true; });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'End Date', border: OutlineInputBorder()),
                      child: Text('${archiveEndDate.year}-${archiveEndDate.month.toString().padLeft(2, '0')}-${archiveEndDate.day.toString().padLeft(2, '0')}'),
                    ),
                  ),
                ] else if (isDaily)
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 90)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() { selectedDate = picked; datePicked = true; });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                      child: Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
                    ),
                  )
                else ...[
                  DropdownButtonFormField<int>(
                    value: selectedMonth,
                    decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                    items: List.generate(12, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(DateTime(2000, i + 1).month.toString()),
                    )),
                    onChanged: (val) {
                      if (val != null) setDialogState(() { selectedMonth = val; datePicked = true; });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                    items: List.generate(5, (i) => DropdownMenuItem(
                      value: DateTime.now().year - 2 + i,
                      child: Text((DateTime.now().year - 2 + i).toString()),
                    )),
                    onChanged: (val) {
                      if (val != null) setDialogState(() { selectedYear = val; datePicked = true; });
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: datePicked ? () async {
                Navigator.pop(ctx);
                setState(() => _isLoadingReports = true);
                try {
                  if (selectedType == 'archive_retrieval') {
                    final startStr = '${archiveStartDate.year}-${archiveStartDate.month.toString().padLeft(2, '0')}-${archiveStartDate.day.toString().padLeft(2, '0')}';
                    final endStr = '${archiveEndDate.year}-${archiveEndDate.month.toString().padLeft(2, '0')}-${archiveEndDate.day.toString().padLeft(2, '0')}';
                    await StationReportRepository.generateArchiveRetrieval(widget.stationId, startStr, endStr);
                  } else if (selectedType.startsWith('daily_') || selectedType == 'missed_activity') {
                    final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                    await StationReportRepository.generateDaily(selectedType, widget.stationId, dateStr);
                  } else {
                    await StationReportRepository.generateMonthly(selectedType, widget.stationId, selectedMonth, selectedYear);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report generated'), backgroundColor: kSuccessGreen),
                    );
                    _loadReports();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Generation failed: $e'), backgroundColor: kErrorRed),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoadingReports = false);
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kRailwayBlue,
                foregroundColor: Colors.white,
              ),
              child: datePicked ? const Text('Generate') : const Text('Select a date first'),
            ),
          ],
        ),
      ),
    );
  }

  void _sendEmail(StationReport report) {
    try {
      if (report.reportType == 'archive_retrieval') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archive retrieval reports are on-demand only; no email dispatch'), backgroundColor: kWarningOrange),
          );
        }
        return;
      }
      if (report.reportType.startsWith('monthly_')) {
        final parts = report.date.split('-');
        final m = parts.length > 1 ? int.tryParse(parts[1]) ?? DateTime.now().month : DateTime.now().month;
        final y = parts.isNotEmpty ? int.tryParse(parts[0]) ?? DateTime.now().year : DateTime.now().year;
        AutoEmailService.dispatchMonthlyReport(report.reportType, report.stationId, m, y);
      } else {
        AutoEmailService.dispatchDailyReport(report.reportType, report.stationId, report.date);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email dispatched'), backgroundColor: kSuccessGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email failed: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  Future<void> _downloadReport(StationReport report) async {
    try {
      final pdfBytes = await PDFReportService.generateStationReportPdf(report);
      final slug = report.reportType.replaceAll('_', '-');
      final dateStr = report.date.replaceAll('-', '');
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'StationReport_${report.stationId}_${slug}_$dateStr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Generated Reports'),
            Tab(text: 'Schedules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsTab(),
          _buildSchedulesTab(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                DropdownButton<String>(
                  value: _filterReportType,
                  hint: const Text('All Report Types'),
                  isExpanded: true,
                  items: _reportTypes.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12)),
                  )).toList()..insert(0, const DropdownMenuItem(value: null, child: Text('All Report Types'))),
                  onChanged: (val) {
                    setState(() => _filterReportType = val);
                    _loadReports();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _filterMonth,
                        decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text((i + 1).toString()))),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _filterMonth = val);
                            _loadReports();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _filterYear,
                        decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                        items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - 2 + i, child: Text((DateTime.now().year - 2 + i).toString()))),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _filterYear = val);
                            _loadReports();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoadingReports
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const Center(child: Text('No reports found'))
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView.builder(
                        itemCount: _reports.length,
                        itemBuilder: (context, idx) {
                          final report = _reports[idx];
                          final previewKeys = report.summary.keys.take(2).join(', ');
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(report.reportType.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('${report.date} | ${report.generatedAt.toString().split('.').first}\n$previewKeys'),
                              isThreeLine: true,
                              trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download, color: kSuccessGreen),
                                  onPressed: () => _downloadReport(report),
                                  tooltip: 'Download PDF',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.email, color: kRailwayBlue),
                                  onPressed: () => _sendEmail(report),
                                  tooltip: 'Send Email',
                                ),
                              ],
                            ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSchedulesTab() {
    return _isLoadingSchedules
        ? const Center(child: CircularProgressIndicator())
        : _schedules.isEmpty
            ? const Center(child: Text('No schedules found'))
            : RefreshIndicator(
                onRefresh: _loadSchedules,
                child: ListView.builder(
                  itemCount: _schedules.length,
                  itemBuilder: (context, idx) {
                    final schedule = _schedules[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(schedule['reportType']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'Report', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Cron: ${schedule['cronExpression'] ?? 'N/A'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: kErrorRed),
                          onPressed: () async {
                            final uid = schedule['uid'] ?? schedule['id'];
                            if (uid == null) return;
                            try {
                              await StationReportRepository.deleteSchedule(uid.toString());
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Schedule deleted'), backgroundColor: kSuccessGreen),
                                );
                                _loadSchedules();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e'), backgroundColor: kErrorRed),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
  }
}

class AutoEmailService {
  static Future<void> dispatchDailyReport(String reportType, String stationId, String date) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('${ApiService.baseUrl}/api/station-reports/auto-email/daily'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'reportType': reportType, 'stationId': stationId, 'date': date}),
      );
    } catch (_) {}
  }

  static Future<void> dispatchMonthlyReport(String reportType, String stationId, int month, int year) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('${ApiService.baseUrl}/api/station-reports/auto-email/monthly'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'reportType': reportType, 'stationId': stationId, 'month': month, 'year': year}),
      );
    } catch (_) {}
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}
