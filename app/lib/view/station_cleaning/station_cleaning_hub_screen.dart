import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/view/common_railways/station_management/station_feedback_list_screen.dart';
import 'dashboard/station_dashboard_kpi_screen.dart';
import 'dashboard/supervisor_dashboard_screen.dart';
import 'attendance/station_attendance_screen.dart';
import 'activities/daily_activity_list_screen.dart';
import 'billing/billing_support_pack_screen.dart';
import 'pest_control/pest_control_list_screen.dart';
import 'complaint/complaint_list_screen.dart';
import 'machine/machine_tracking_screen.dart';
import 'garbage/garbage_management_screen.dart';
import 'reporting/report_list_screen.dart';
import 'reporting/audit_report_list_screen.dart';
import 'feedback/feedback_qr_screen.dart';
import 'cleaning_form/station_cleaning_form_list_screen.dart';
import 'schedule/station_schedule_screen.dart';
import 'area_config/area_config_screen.dart';
import 'zone/station_zones_screen.dart';
import 'contractor/contractor_mapping_screen.dart';
import 'worker_tasks/worker_task_view_screen.dart';
import 'supervisor_review/supervisor_review_screen.dart';
import 'execution/cs_field_execution_screen.dart';
import 'supervisor_log/supervisor_daily_log_screen.dart';
import 'hierarchical_dashboard/hierarchical_dashboard_screen.dart';
import 'workforce/workforce_deployment_screen.dart';
import '../common_railways/station_management/qr_code_screen.dart';
import '../common_railways/station_management/worker_checkin_screen.dart';
import '../common_railways/station_management/task_generation_screen.dart';
import '../common_railways/station_management/task_approval_screen.dart';
import '../common_railways/station_management/area_performance_dashboard.dart';
import '../common_railways/station_management/area_comparison_screen.dart';
import '../common_railways/station_management/area_assignment_screen.dart';
import '../common_railways/station_management/platform_list_screen.dart';
import '../common_railways/station_management/frequency_list_screen.dart';
import '../../repositories/station_run_repository.dart';
import '../../repositories/station_cleaning_repository.dart';
import '../../model/station_run_model.dart';
import 'attendance/worker_attendance_screen.dart';
import 'inspection/inspection_list_screen.dart';
import 'petty_issue/petty_issue_list_screen.dart';
import 'task_master/task_type_list_screen.dart';
import 'workers/worker_management_screen.dart';
import 'field_work/photo_submission_screen.dart';
import 'shift_summary_approval_screen.dart';

class StationCleaningHubScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String? contractId;

  const StationCleaningHubScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    this.contractId,
  });

  @override
  State<StationCleaningHubScreen> createState() => _StationCleaningHubScreenState();
}

class _StationCleaningHubScreenState extends State<StationCleaningHubScreen> {
  String _selectedStationId = '';
  String _selectedStationName = '';
  List<Station> _availableStations = [];
  bool _loadingStations = true;

  @override
  void initState() {
    super.initState();
    _selectedStationId = widget.stationId;
    _selectedStationName = widget.stationName;
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    try {
      final all = await ApiService.getStations();
      setState(() {
        _availableStations = all;
        _loadingStations = false;
      });
    } catch (e) {
      setState(() => _loadingStations = false);
    }
  }

  void _onStationChanged(String? uid) {
    if (uid == null) return;
    final station = _availableStations.firstWhere((s) => s.uid == uid, orElse: () => Station(stationCode: '', stationName: '', zone: '', division: ''));
    setState(() {
      _selectedStationId = uid;
      _selectedStationName = station.stationName;
    });
  }

  bool _canSwitchStation(String role) {
    final r = role.toUpperCase().replaceAll(' ', '_');
    const switchable = {'SUPER_ADMIN', 'ADMIN', 'RAILWAY_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'CONTRACTOR_MASTER'};
    return switchable.contains(r);
  }

  // Each role has a permission set defining which card indices are visible
  Set<int> _visibleCards(String role) {
    final r = role.toUpperCase().replaceAll(' ', '_');
    switch (r) {
      case 'RAILWAY_MASTER':
        return {0, 1, 8, 9, 15, 16, 23, 24, 29, 30, 31, 35};
      case 'RAILWAY_ADMIN':
        return {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 35};
      case 'RAILWAY_INSPECTOR':
        return {15, 35};
      case 'RAILWAY_SUPERVISOR':
        return {0, 1, 14, 15, 22, 28, 30, 31, 35};
      case 'COMPANY_MASTER':
        return {0, 1, 8, 9, 15, 18, 30, 31, 35};
      case 'CONTRACTOR_MASTER':
        return {0, 1, 8, 9, 15, 18, 30, 31};
      case 'CONTRACTOR_ADMIN':
        return {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31};
      case 'CONTRACTOR_SUPERVISOR':
        return {0, 1, 9, 30, 32, 33, 34};
      case 'WORKER':
      case 'RAILWAY_WORKER':
      case 'JANITOR':
      case 'ATTENDANT':
        return {0, 1, 14, 20, 30};
      default:
        return {0, 1, 5, 8, 9, 15, 21, 22, 29, 30, 31};
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context).currentUser?.role ?? '';
    final visible = _visibleCards(role);

    final allCards = <Widget>[
      _moduleCard(context, Icons.dashboard, 'Dashboard', kRailwayBlue, () => _openDashboard(context)),             // 0
      _moduleCard(context, Icons.people, 'Attendance', Colors.teal, () => _openAttendance(context)),               // 1
      _moduleCard(context, Icons.assignment, 'Activities', Colors.orange, () => _openActivities(context)),         // 2
      _moduleCard(context, Icons.cleaning_services, 'Cleaning\nForm', Colors.lightBlue, () => _openCleaningForm(context)), // 3
      _moduleCard(context, Icons.bug_report, 'Pest\nControl', Colors.green, () => _openPestControl(context)),       // 4
      _moduleCard(context, Icons.report, 'Complaints', Colors.red, () => _openComplaint(context)),                  // 5
      _moduleCard(context, Icons.precision_manufacturing, 'Machines', Colors.blueGrey, () => _openMachine(context)),// 6
      _moduleCard(context, Icons.delete, 'Garbage', Colors.brown.shade700, () => _openGarbage(context)),            // 7
      _moduleCard(context, Icons.receipt, 'Billing', Colors.deepOrange, () => _openBilling(context)),               // 8
      _moduleCard(context, Icons.assessment, 'Reports', Colors.purple, () => _openReports(context)),                // 9
      _moduleCard(context, Icons.security, 'Audit\nReports', Colors.indigo, () => _openAuditReports(context)),      // 10
      _moduleCard(context, Icons.feedback, 'Feedback', Colors.amber.shade700, () => _openFeedback(context)),        // 11
      _moduleCard(context, Icons.schedule, 'Schedule', Colors.teal, () => _openSchedule(context)),                  // 12
      _moduleCard(context, Icons.map, 'Area\nConfig', Colors.lightGreen, () => _openAreaConfig(context)),            // 13
      _moduleCard(context, Icons.assignment_turned_in, 'My\nTasks', Colors.deepOrange, () => _openWorkerTasks(context)), // 14
      _moduleCard(context, Icons.search, 'Inspection', Colors.deepPurple, () => _openInspection(context)), // 15
      _moduleCard(context, Icons.dashboard_customize, 'Hier.\nDashboard', Colors.indigo.shade400, () => _openHierDashboard(context)), // 16
      _moduleCard(context, Icons.layers, 'Zones', Colors.teal.shade700, () => _openZones(context)),                 // 17
      _moduleCard(context, Icons.business, 'Contractors', Colors.brown, () => _openContractors(context)),           // 18
      _moduleCard(context, Icons.qr_code, 'QR\nGenerator', Colors.indigo, () => _openQRGenerator(context)),        // 19
      _moduleCard(context, Icons.login, 'Check-in', kSuccessGreen, () => _openCheckin(context)),                  // 20
      _moduleCard(context, Icons.auto_awesome, 'Task\nGen', Colors.deepPurple, () => _openTaskGen(context)),       // 21
      _moduleCard(context, Icons.rate_review_outlined, 'Task\nApproval', kWarningOrange, () => _openTaskApproval(context)), // 22
      _moduleCard(context, Icons.speed, 'Area\nPerf.', kRailwayBlue, () => _openAreaPerformance(context)),         // 23
      _moduleCard(context, Icons.compare_arrows, 'Area\nCompare', Colors.teal, () => _openAreaComparison(context)),// 24
      _moduleCard(context, Icons.people, 'Area\nAssign', Colors.blueGrey, () => _openAreaAssignment(context)),     // 25
      _moduleCard(context, Icons.groups, 'Workforce', Colors.indigo.shade700, () => _openWorkforce(context)),       // 26
      _moduleCard(context, Icons.repeat, 'Frequency', Colors.cyan.shade700, () => _openFrequency(context)),         // 27
      _moduleCard(context, Icons.warning_amber_rounded, 'Att.\nExceptions', Colors.deepOrange, () => _openExceptionAction(context)), // 28
      _moduleCard(context, Icons.view_quilt, 'Platforms', Colors.teal, () => _openPlatforms(context)),             // 29
      _moduleCard(context, Icons.report_problem_outlined, 'Petty\nIssues', kWarningOrange, () => _openPettyIssues(context)), // 30
      _moduleCard(context, Icons.checklist, 'Task\nTypes', Colors.blue.shade700, () => _openTaskTypes(context)),            // 31
      _moduleCard(context, Icons.book, 'Daily\nLog', Colors.blue, () => _openDailyLog(context)),                    // 32
      _moduleCard(context, Icons.groups, 'Workers', Colors.teal, () => _openWorkers(context)),                     // 33
      _moduleCard(context, Icons.camera_alt, 'Field\nWork', Colors.deepOrange, () => _openFieldWork(context)),     // 34
      _moduleCard(context, Icons.approval, 'Shift\nSummary', Colors.teal.shade700, () => _openShiftSummaryApproval(context)), // 35
    ];

    final cards = <Widget>[];
    for (var i = 0; i < allCards.length; i++) {
      if (visible.contains(i)) cards.add(allCards[i]);
    }

    final titleWidget = _loadingStations
        ? Text(_selectedStationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        : _canSwitchStation(role)
            ? DropdownButton<String>(
                value: _availableStations.any((s) => s.uid == _selectedStationId) ? _selectedStationId : null,
                dropdownColor: kRailwayBlue,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: _availableStations.map((s) => DropdownMenuItem(
                  value: s.uid,
                  child: Text(s.stationName, style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: _onStationChanged,
              )
            : Text(_selectedStationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));

    return Scaffold(
      appBar: AppBar(
        title: titleWidget,
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cards.isEmpty
          ? const Center(child: Text('No modules available for your role'))
          : GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(12),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
              children: cards,
            ),
    );
  }

  Widget _moduleCard(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), radius: 24, child: Icon(icon, color: color, size: 26)),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _openDashboard(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final role = user?.role ?? '';
    final r = role.toUpperCase().replaceAll(' ', '_');
    if (r == 'RAILWAY_SUPERVISOR' || r == 'CONTRACTOR_SUPERVISOR') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorDashboardScreen(
        stationId: _selectedStationId, stationName: _selectedStationName,
        platformId: user?.platformId,
      )));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => StationDashboardKpiScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
    }
  }

  void _openAttendance(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final role = user?.role?.toUpperCase().replaceAll(' ', '_') ?? '';
    final isWorker = ['WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT', 'CONTRACTOR_SUPERVISOR'].contains(role);
    if (isWorker) {
      _openWorkerAttendance(context, user!.uid, user.fullName ?? '');
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => StationAttendanceScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
    }
  }

  void _openWorkerAttendance(BuildContext context, String workerId, String workerName) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FutureBuilder<List<StationCleaningRunModel>>(
        future: StationRunRepository.getMyStationRuns(),
        builder: (ctx, snapshot) {
          String resolvedRunId;
          String resolvedStationId;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())));
          }
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final runs = snapshot.data!;
            StationCleaningRunModel? todayRun;
            try {
              todayRun = runs.firstWhere(
                (r) => r.date == today && ['scheduled', 'in progress', 'active'].contains(r.status.toLowerCase()),
              );
            } catch (_) {
              todayRun = runs.isNotEmpty ? runs.first : null;
            }
            resolvedRunId = todayRun?.runInstanceId ?? '${_selectedStationId}_$today';
            resolvedStationId = todayRun?.stationId ?? _selectedStationId;
          } else {
            resolvedRunId = '${_selectedStationId}_$today';
            resolvedStationId = _selectedStationId;
          }
          return FutureBuilder<Map<String, dynamic>>(
            future: StationCleaningRepository.getStationAttendanceStatus(workerId: workerId),
            builder: (ctx, attSnapshot) {
              final startMarked = attSnapshot.hasData && attSnapshot.data?['isStartMarked'] == true;
              final midMarked = attSnapshot.hasData && attSnapshot.data?['isMidMarked'] == true;
              final endMarked = attSnapshot.hasData && attSnapshot.data?['isEndMarked'] == true;
              return AlertDialog(
                title: const Text('Select Attendance Type'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _attendanceTypeButton(ctx, workerId, workerName, resolvedRunId, resolvedStationId,
                        'start', startMarked ? 'Start (Already Marked)' : 'Start Attendance',
                        Icons.play_arrow, startMarked ? Colors.grey : Colors.green, enabled: !startMarked),
                    const SizedBox(height: 8),
                    _attendanceTypeButton(ctx, workerId, workerName, resolvedRunId, resolvedStationId,
                        'mid', midMarked ? 'Mid (Already Marked)' : 'Mid Attendance',
                        Icons.pause, midMarked ? Colors.grey : Colors.orange, enabled: !midMarked),
                    const SizedBox(height: 8),
                    _attendanceTypeButton(ctx, workerId, workerName, resolvedRunId, resolvedStationId,
                        'end', endMarked ? 'End (Already Marked)' : 'End Attendance',
                        Icons.stop, endMarked ? Colors.grey : Colors.red, enabled: !endMarked),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _attendanceTypeButton(BuildContext context, String workerId, String workerName, String runInstanceId, String stationId, String type, String label, IconData icon, Color color, {bool enabled = true}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => StationWorkerAttendanceScreen(
              workerId: workerId,
              workerName: workerName,
              runInstanceId: runInstanceId,
              stationId: stationId,
              attendanceType: type,
            ),
          ));
        } : null,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey[300], padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }

  void _openActivities(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DailyActivityListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openPestControl(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PestControlListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openComplaint(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openMachine(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MachineTrackingScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openGarbage(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GarbageManagementScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openBilling(BuildContext context) {
    if (widget.contractId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => BillingSupportPackScreen(contractId: widget.contractId!, stationId: _selectedStationId, stationName: _selectedStationName)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contract linked to this station')));
    }
  }

  void _openReports(BuildContext context) {
    final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '';
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportListScreen(stationId: _selectedStationId, stationName: _selectedStationName, role: role)));
  }

  void _openAuditReports(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AuditReportListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openFeedback(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Feedback Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.qr_code, color: Colors.white)),
              title: const Text('Generate QR Code'),
              subtitle: const Text('Print & display for passenger feedback'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackQrScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.list, color: Colors.white)),
              title: const Text('View Feedback'),
              subtitle: const Text('Browse submitted passenger feedback'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => StationFeedbackListScreen(stationId: _selectedStationId)));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openCleaningForm(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationCleaningFormListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openSchedule(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationScheduleScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openAreaConfig(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaConfigScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openWorkerTasks(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CSFieldExecutionScreen()));
  }

  void _openDailyLog(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorDailyLogScreen()));
  }

  void _openSupervisorReview(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorReviewScreen(stationId: _selectedStationId)));
  }

  void _openInspection(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => InspectionListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openHierDashboard(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HierarchicalDashboardScreen(initialLevel: null, levelId: null)));
  }

  void _openZones(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationZonesScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openContractors(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ContractorMappingScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openQRGenerator(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => QRCodeScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openCheckin(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerCheckinScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openTaskGen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskGenerationScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openTaskApproval(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskApprovalScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openAreaPerformance(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaPerformanceDashboard(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openAreaComparison(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaComparisonScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openAreaAssignment(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaAssignmentScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openWorkforce(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkforceDeploymentScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openFrequency(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FrequencyListScreen()));
  }

  void _openExceptionAction(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationAttendanceScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openPlatforms(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlatformListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openPettyIssues(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PettyIssueListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openTaskTypes(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskTypeListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openWorkers(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerManagementScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openFieldWork(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoSubmissionScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openShiftSummaryApproval(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ShiftSummaryApprovalScreen(stationId: _selectedStationId)));
  }
}
