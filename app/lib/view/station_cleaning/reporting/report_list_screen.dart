import 'dart:convert';
import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/providers/station_cleaning_provider.dart';
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
  const ReportListScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    this.role,
  });

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingReports = false;
  bool _isLoadingLive = false;

  List<StationReport> _reports = [];

  Map<String, dynamic>? _dailyReport;
  Map<String, dynamic>? _weeklyReport;
  Map<String, dynamic>? _monthlyReport;

  String? _filterReportType;
  int _filterMonth = DateTime.now().month;
  int _filterYear = DateTime.now().year;

  bool get _showLiveDashboard {
    final r = (widget.role ?? '').toUpperCase().replaceAll(' ', '_');
    return r == 'CONTRACTOR_SUPERVISOR' ||
        r == 'CONTRACTOR_ADMIN' ||
        r == 'CONTRACTOR_MASTER' ||
        r == 'COMPANY_MASTER';
  }

  bool get _isContractor {
    final r = (widget.role ?? '').toUpperCase().replaceAll(' ', '_');
    return r == 'CONTRACTOR_SUPERVISOR' ||
        r == 'CONTRACTOR_ADMIN' ||
        r == 'CONTRACTOR_MASTER' ||
        r == 'COMPANY_MASTER';
  }

  static const Map<String, Map<String, dynamic>> _reportMeta = {
    'daily_attendance': {
      'icon': Icons.how_to_reg,
      'title': 'Attendance Report',
      'frequency': 'Daily',
      'description':
          'View biometric/API attendance and manpower availability per shift.',
      'color': Color(0xFF1565C0),
    },
    'daily_activity': {
      'icon': Icons.cleaning_services,
      'title': 'Cleaning Activity Report',
      'frequency': 'Daily',
      'description':
          'Track completed, pending, overdue, and rejected cleaning tasks.',
      'color': Color(0xFF2E7D32),
    },
    'daily_inspection': {
      'icon': Icons.fact_check,
      'title': 'Inspection Report',
      'frequency': 'Daily',
      'description':
          'Capture not-cleaned areas, scores, photo evidence, and inspection remarks.',
      'color': Color(0xFF6A1B9A),
    },
    'daily_feedback': {
      'icon': Icons.feedback,
      'title': 'Passenger Feedback Report',
      'frequency': 'Daily',
      'description':
          'View PNR-validated feedback, section-wise scores, and negative feedback trends.',
      'color': Color(0xFFE65100),
    },
    'missed_activity': {
      'icon': Icons.warning_amber,
      'title': 'Overdue Task / Exception Report',
      'frequency': 'Daily',
      'description':
          'Highlight missed, delayed, or overdue cleaning tasks and exceptions.',
      'color': Color(0xFFC62828),
    },
    'daily_petty_issue': {
      'icon': Icons.construction,
      'title': 'Petty Issue Report',
      'frequency': 'Daily',
      'description':
          'Track station asset-related petty issues and their status.',
      'color': Color(0xFF37474F),
    },
    'daily_scorecard': {
      'icon': Icons.score,
      'title': 'Daily Scorecard',
      'frequency': 'Daily',
      'description':
          'Daily quality score with grade distribution across all areas.',
      'color': Color(0xFF00838F),
    },
    'daily_complaint': {
      'icon': Icons.report_problem,
      'title': 'Complaint Report',
      'frequency': 'Daily',
      'description':
          'Track open, resolved, and escalated complaints by category.',
      'color': Color(0xFFAD1457),
    },
    'daily_supervisor_log': {
      'icon': Icons.list_alt,
      'title': 'Supervisor Daily Log',
      'frequency': 'Daily',
      'description':
          'View submitted supervisor logs, issues reported, and materials used.',
      'color': Color(0xFF4527A0),
    },
    'monthly_attendance': {
      'icon': Icons.calendar_month,
      'title': 'Monthly Attendance',
      'frequency': 'Monthly',
      'description':
          'Summary of supervisor attendance, overtime, and availability trends.',
      'color': Color(0xFF1565C0),
    },
    'monthly_cleaning': {
      'icon': Icons.cleaning_services,
      'title': 'Monthly Cleaning Summary',
      'frequency': 'Monthly',
      'description':
          'Completed activities, garbage collection, waste breakdown, and area completion rates.',
      'color': Color(0xFF2E7D32),
    },
    'monthly_performance': {
      'icon': Icons.assessment,
      'title': 'Performance Score Report',
      'frequency': 'Monthly',
      'description':
          'Combined score from task completion, inspections, feedback, and scorecard trends.',
      'color': Color(0xFFFF6F00),
    },
    'monthly_billing': {
      'icon': Icons.receipt_long,
      'title': 'Billing Support Report',
      'frequency': 'Monthly',
      'description':
          'Support billing verification with task, attendance, photo, score, and feedback data.',
      'color': Color(0xFF00695C),
    },
    'monthly_feedback': {
      'icon': Icons.rate_review,
      'title': 'Monthly Feedback Summary',
      'frequency': 'Monthly',
      'description':
          'Aggregate passenger feedback with rating distribution and category breakdown.',
      'color': Color(0xFFE65100),
    },
    'monthly_complaint': {
      'icon': Icons.gavel,
      'title': 'Monthly Complaint Summary',
      'frequency': 'Monthly',
      'description':
          'Complaint trends with SLA breaches, resolution times, and escalation stats.',
      'color': Color(0xFFAD1457),
    },
    'monthly_penalty': {
      'icon': Icons.money_off,
      'title': 'Monthly Penalty Report',
      'frequency': 'Monthly',
      'description':
          'Machine downtime, SLA breaches, and penalty amounts from low scores.',
      'color': Color(0xFFC62828),
    },
    'monthly_petty_issue': {
      'icon': Icons.construction,
      'title': 'Monthly Petty Issue Summary',
      'frequency': 'Monthly',
      'description':
          'Monthly summary of station asset-related petty issues by status and severity.',
      'color': Color(0xFF37474F),
    },
  };

  static const List<String> _allReportKeys = [
    'daily_attendance',
    'daily_activity',
    'daily_inspection',
    'daily_feedback',
    'missed_activity',
    'daily_scorecard',
    'daily_complaint',
    'daily_supervisor_log',
    'daily_petty_issue',
    'monthly_attendance',
    'monthly_cleaning',
    'monthly_performance',
    'monthly_billing',
    'monthly_feedback',
    'monthly_complaint',
    'monthly_penalty',
    'monthly_petty_issue',
  ];

  static const List<String> _contractorReportKeys = [
    'daily_attendance',
    'daily_activity',
    'daily_feedback',
    'missed_activity',
    'daily_inspection',
    'daily_petty_issue',
    'monthly_performance',
    'monthly_billing',
    'monthly_petty_issue',
  ];

  List<String> get _availableReportKeys =>
      _isContractor ? _contractorReportKeys : _allReportKeys;
  List<String> get _dailyKeys => _availableReportKeys
      .where((k) => k.startsWith('daily_') || k == 'missed_activity')
      .toList();
  List<String> get _monthlyKeys =>
      _availableReportKeys.where((k) => k.startsWith('monthly_')).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _showLiveDashboard ? 3 : 2,
      vsync: this,
    );
    _loadReports();
    if (_showLiveDashboard) _loadLiveDashboard();
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
      final list = await StationReportRepository.list(query);
      list.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      final seen = <String>{};
      final deduped = <StationReport>[];
      for (final r in list) {
        final key = '${r.reportType}|${r.stationId}|${r.date}|${r.endDate}';
        if (seen.add(key)) deduped.add(r);
      }
      setState(() => _reports = deduped);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reports: $e'),
            backgroundColor: kErrorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _loadLiveDashboard() async {
    setState(() => _isLoadingLive = true);
    try {
      final provider = StationCleaningProvider();
      final results = await Future.wait([
        provider.fetchDailyReport(widget.stationId),
        provider.fetchWeeklyReport(widget.stationId),
        provider.fetchMonthlyReport(widget.stationId),
      ]);
      if (!mounted) return;
      setState(() {
        _dailyReport = results[0];
        _weeklyReport = results[1];
        _monthlyReport = results[2];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load live dashboard: $e'),
            backgroundColor: kErrorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLive = false);
    }
  }

  void _showGenerateSheet(String reportKey) {
    final meta = _reportMeta[reportKey]!;
    final isDaily =
        reportKey.startsWith('daily_') || reportKey == 'missed_activity';
    DateTime selectedDate = DateTime.now();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    bool useRange = false;
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;
    bool isGenerating = false;

    Future<DateTime?> pickDate(
      BuildContext sheetCtx,
      DateTime initial, {
      DateTime? firstDate,
      DateTime? lastDate,
    }) async {
      return showDatePicker(
        context: sheetCtx,
        initialDate: initial,
        firstDate:
            firstDate ?? DateTime.now().subtract(const Duration(days: 90)),
        lastDate: lastDate ?? DateTime.now(),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: meta['color'].withValues(alpha: 0.12),
                        child: Icon(
                          meta['icon'],
                          color: meta['color'],
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta['title'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              meta['frequency'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meta['description'],
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 20),
                  if (isDaily) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Single Day'),
                              selected: !useRange,
                              onSelected: (_) =>
                                  setSheetState(() => useRange = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Date Range'),
                              selected: useRange,
                              onSelected: (_) =>
                                  setSheetState(() => useRange = true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      useRange ? 'Select Start Date' : 'Select Date',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = useRange ? startDate : selectedDate;
                        final picked = await pickDate(ctx, date);
                        if (picked != null)
                          setSheetState(
                            () => useRange
                                ? startDate = picked
                                : selectedDate = picked,
                          );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event),
                        ),
                        child: Text(
                          DateFormat(
                            'yyyy-MM-dd',
                          ).format(useRange ? startDate : selectedDate),
                        ),
                      ),
                    ),
                    if (useRange) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Select End Date',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await pickDate(
                              ctx,
                              endDate,
                              firstDate: startDate,
                            );
                          if (picked != null)
                            setSheetState(() => endDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.event_repeat),
                          ),
                          child: Text(DateFormat('yyyy-MM-dd').format(endDate)),
                        ),
                      ),
                      if (endDate.isBefore(startDate)) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'End date cannot be before start date',
                          style: TextStyle(color: kErrorRed, fontSize: 12),
                        ),
                      ],
                    ],
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedMonth,
                            decoration: const InputDecoration(
                              labelText: 'Month',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text(
                                  DateFormat(
                                    'MMMM',
                                  ).format(DateTime(2000, i + 1)),
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (val != null)
                                setSheetState(() => selectedMonth = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(
                              5,
                              (i) => DropdownMenuItem(
                                value: DateTime.now().year - 2 + i,
                                child: Text(
                                  (DateTime.now().year - 2 + i).toString(),
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (val != null)
                                setSheetState(() => selectedYear = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed:
                          isGenerating ||
                              (useRange && endDate.isBefore(startDate))
                          ? null
                          : () async {
                              setSheetState(() => isGenerating = true);
                              try {
                                late StationReport generated;
                                if (isDaily && useRange) {
                                  generated =
                                      await StationReportRepository.generateRange(
                                        reportKey,
                                        widget.stationId,
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(startDate),
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(endDate),
                                      );
                                } else if (isDaily) {
                                  generated =
                                      await StationReportRepository.generateDaily(
                                        reportKey,
                                        widget.stationId,
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(selectedDate),
                                      );
                                } else {
                                  generated =
                                      await StationReportRepository.generateMonthly(
                                        reportKey,
                                        widget.stationId,
                                        selectedMonth,
                                        selectedYear,
                                      );
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${meta["title"]} generated',
                                      ),
                                      backgroundColor: kSuccessGreen,
                                    ),
                                  );
                                  _loadReports();
                                  Navigator.pop(ctx);
                                  _tabController.animateTo(
                                    _showLiveDashboard ? 2 : 1,
                                  );
                                  await Future.delayed(
                                    const Duration(milliseconds: 250),
                                  );
                                  _downloadReport(generated);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Generation failed: $e'),
                                      backgroundColor: kErrorRed,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted)
                                  setSheetState(() => isGenerating = false);
                              }
                            },
                      icon: isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        isGenerating ? 'Generating...' : 'Generate Report',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: meta['color'],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendEmail(StationReport report) {
    try {
      if (report.reportType == 'archive_retrieval') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archive retrieval reports are on-demand only'),
              backgroundColor: kWarningOrange,
            ),
          );
        }
        return;
      }
      if (report.reportType.startsWith('monthly_')) {
        final parts = report.date.split('-');
        final m = parts.length > 1
            ? int.tryParse(parts[1]) ?? DateTime.now().month
            : DateTime.now().month;
        final y = parts.isNotEmpty
            ? int.tryParse(parts[0]) ?? DateTime.now().year
            : DateTime.now().year;
        AutoEmailService.dispatchMonthlyReport(
          report.reportType,
          report.stationId,
          m,
          y,
        );
      } else {
        AutoEmailService.dispatchDailyReport(
          report.reportType,
          report.stationId,
          report.date,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email dispatched'),
            backgroundColor: kSuccessGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email failed: $e'),
            backgroundColor: kErrorRed,
          ),
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
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: kErrorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Reports — ${widget.stationName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _showLiveDashboard
              ? const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Generate'),
                  Tab(text: 'History'),
                ]
              : const [Tab(text: 'Generate'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _showLiveDashboard
            ? [_buildOverviewTab(), _buildGenerateTab(), _buildHistoryTab()]
            : [_buildGenerateTab(), _buildHistoryTab()],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadLiveDashboard,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_isLoadingLive && _dailyReport == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _buildPeriodCard('Today', _dailyReport, showDate: true),
            const SizedBox(height: 12),
            _buildPeriodCard('This Week', _weeklyReport, showRange: true),
            const SizedBox(height: 12),
            _buildPeriodCard('This Month', _monthlyReport, showRange: true),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodCard(
    String title,
    Map<String, dynamic>? data, {
    bool showDate = false,
    bool showRange = false,
  }) {
    if (data == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$title — no data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }
    final total = (data['totalTasks'] ?? 0).toInt();
    final completed = (data['completedTasks'] ?? 0).toInt();
    final pending = (data['pendingTasks'] ?? total - completed).toInt();
    final avgScore = (data['averageScore'] ?? 0).toInt();
    final grade = data['grade']?.toString() ?? 'N/A';
    final rate =
        (data['completionRate'] ??
                (total > 0 ? (completed / total * 100).round() : 0))
            .toInt();

    String subtitle = '';
    if (showDate) subtitle = 'Date: ${data['date'] ?? ''}';
    if (showRange)
      subtitle =
          data['period']?.toString() ??
          '${data['startDate'] ?? ''} to ${data['endDate'] ?? ''}';

    Color gradeColor = grade == 'A'
        ? Colors.green
        : grade == 'B'
        ? Colors.lightGreen
        : grade == 'C'
        ? Colors.orange
        : Colors.red;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Grade $grade',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: gradeColor,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    Icons.cleaning_services,
                    'Total',
                    '$total',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBox(
                    Icons.check_circle,
                    'Done',
                    '$completed',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBox(
                    Icons.pending,
                    'Pending',
                    '$pending',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    Icons.star,
                    'Score',
                    '$avgScore%',
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBox(Icons.percent, 'Rate', '$rate%', Colors.teal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total > 0 ? completed / total : 0,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  rate >= 80
                      ? Colors.green
                      : rate >= 50
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _reportDateLabel(StationReport report) {
    final hasRange =
        report.endDate != null &&
        report.endDate!.isNotEmpty &&
        report.endDate != report.date;
    if (hasRange) return '${report.date} to ${report.endDate}';
    if (report.reportType.startsWith('monthly_'))
      return '${report.month}/${report.year}';
    return report.date;
  }

  Widget _buildGenerateTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadReports();
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSectionHeader('Daily Reports', Icons.wb_sunny),
          const SizedBox(height: 8),
          ..._dailyKeys.map((k) => _buildReportCard(k)),
          const SizedBox(height: 20),
          _buildSectionHeader('Monthly Reports', Icons.calendar_month),
          const SizedBox(height: 8),
          ..._monthlyKeys.map((k) => _buildReportCard(k)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: kRailwayBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kRailwayBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(String reportKey) {
    final meta = _reportMeta[reportKey];
    if (meta == null) return const SizedBox.shrink();
    final color = meta['color'] as Color;

    final existing = _reports.where((r) => r.reportType == reportKey).toList();
    final latestDate = existing.isNotEmpty ? existing.first.date : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: InkWell(
        onTap: () => _showGenerateSheet(reportKey),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta['icon'], color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          meta['frequency'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (latestDate != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last: $latestDate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
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
                  items:
                      _availableReportKeys
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                (_reportMeta[t]?['title'] ?? t).toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList()
                        ..insert(
                          0,
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Report Types'),
                          ),
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(
                              DateFormat('MMM').format(DateTime(2000, i + 1)),
                            ),
                          ),
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        items: List.generate(
                          5,
                          (i) => DropdownMenuItem(
                            value: DateTime.now().year - 2 + i,
                            child: Text(
                              (DateTime.now().year - 2 + i).toString(),
                            ),
                          ),
                        ),
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
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No reports found',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Go to Generate tab and create your first report',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _reports.length,
                    itemBuilder: (context, idx) {
                      final report = _reports[idx];
                      final meta = _reportMeta[report.reportType];
                      final color = meta?['color'] ?? Colors.grey;
                      final preview = report.summary.entries
                          .take(3)
                          .map((e) => '${e.key}: ${e.value}')
                          .join(' · ');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(
                              meta?['icon'] ?? Icons.description,
                              color: color,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            meta?['title'] ?? report.reportType,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _reportDateLabel(report),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (preview.isNotEmpty)
                                Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'pdf') _downloadReport(report);
                              if (v == 'email') _sendEmail(report);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'pdf',
                                child: Row(
                                  children: [
                                    Icon(Icons.download, size: 18),
                                    SizedBox(width: 8),
                                    Text('Download PDF'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'email',
                                child: Row(
                                  children: [
                                    Icon(Icons.email, size: 18),
                                    SizedBox(width: 8),
                                    Text('Send Email'),
                                  ],
                                ),
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
}

class AutoEmailService {
  static Future<void> dispatchDailyReport(
    String reportType,
    String stationId,
    String date,
  ) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('${ApiService.baseUrl}/api/station-reports/auto-email/daily'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'reportType': reportType,
          'stationId': stationId,
          'date': date,
        }),
      );
    } catch (_) {}
  }

  static Future<void> dispatchMonthlyReport(
    String reportType,
    String stationId,
    int month,
    int year,
  ) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/api/station-reports/auto-email/monthly',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'reportType': reportType,
          'stationId': stationId,
          'month': month,
          'year': year,
        }),
      );
    } catch (_) {}
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}
