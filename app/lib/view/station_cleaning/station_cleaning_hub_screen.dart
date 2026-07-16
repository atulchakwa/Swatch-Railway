import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/view/common_railways/station_management/station_feedback_list_screen.dart';
import 'package:crm_train/view/common_railways/station_management/material_list_screen.dart';
import 'dashboard/station_dashboard_kpi_screen.dart';
import 'dashboard/supervisor_dashboard_screen.dart';
import 'dashboard/station_master_dashboard_screen.dart';
import 'dashboard/platform_master_dashboard_screen.dart';
import 'attendance/station_attendance_screen.dart';
import 'activities/daily_activity_list_screen.dart';
import 'billing/billing_support_pack_screen.dart';
import 'execution/execution_plan_list_screen.dart';
import 'evidence/evidence_gallery_screen.dart';
import 'supervisor_log/supervisor_log_list_screen.dart';
import 'inspection/inspection_list_screen.dart';
import 'scorecard/scorecard_list_screen.dart';
import 'complaint/complaint_list_screen.dart';
import 'pest_control/pest_control_list_screen.dart';
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
import 'hierarchical_dashboard/hierarchical_dashboard_screen.dart';
import 'workforce/workforce_deployment_screen.dart';
import '../common_railways/station_management/qr_code_screen.dart';
import '../common_railways/station_management/worker_checkin_screen.dart';
import '../common_railways/station_management/task_generation_screen.dart';
import '../common_railways/station_management/task_approval_screen.dart';
import '../common_railways/station_management/area_performance_dashboard.dart';
import '../common_railways/station_management/area_comparison_screen.dart';
import '../common_railways/station_management/area_history_screen.dart';
import '../common_railways/station_management/area_assignment_screen.dart';
import '../common_railways/station_management/platform_list_screen.dart';
import '../common_railways/station_management/frequency_list_screen.dart';

class StationCleaningHubScreen extends StatelessWidget {
  final String stationId;
  final String stationName;
  final String? contractId;

  const StationCleaningHubScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    this.contractId,
  });

  // Each role has a permission set defining which card indices are visible
  Set<int> _visibleCards(String role) {
    final r = role.toUpperCase().replaceAll(' ', '_');
    if (['SUPER_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'ADMIN', 'RAILWAY_ADMIN'].contains(r)) {
      return {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36};
    }
    if (r == 'RAILWAY_SUPERVISOR') {
      return {0, 1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 16, 17, 19, 20, 24, 25, 26, 28, 29, 30, 31, 35, 36};
    }
    if (r == 'CONTRACTOR_ADMIN') {
      return {0, 1, 2, 3, 5, 6, 10, 11, 12, 16, 18, 19, 20, 24, 25, 28, 30, 35, 36};
    }
    if (r == 'STATION_MASTER' || r == 'AREA_MASTER') {
      return {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36};
    }
    if (r == 'PLATFORM_MASTER') {
      return {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36};
    }
    if (r == 'CONTRACTOR_SUPERVISOR') {
      return {0, 1, 2, 3, 5, 6, 10, 11, 12, 19, 20, 24, 25, 28, 30, 35};
    }
    if (['WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT'].contains(r)) {
      return {0, 1, 2, 20, 22, 27};
    }
    return {};
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
      _moduleCard(context, Icons.calendar_month, 'Execution\nPlan', Colors.indigo, () => _openExecution(context)),  // 4
      _moduleCard(context, Icons.camera_alt, 'Evidence', Colors.brown, () => _openEvidence(context)),               // 5
      _moduleCard(context, Icons.description, 'Sup. Log', Colors.cyan, () => _openSupervisorLog(context)),          // 6
      _moduleCard(context, Icons.search, 'Inspection', Colors.deepPurple, () => _openInspection(context)),          // 7
      _moduleCard(context, Icons.star, 'Scorecard', Colors.pink, () => _openScorecard(context)),                    // 8
      _moduleCard(context, Icons.report, 'Complaints', Colors.red, () => _openComplaint(context)),                  // 9
      _moduleCard(context, Icons.bug_report, 'Pest\nControl', Colors.green, () => _openPestControl(context)),       // 10
      _moduleCard(context, Icons.precision_manufacturing, 'Machines', Colors.blueGrey, () => _openMachine(context)),// 11
      _moduleCard(context, Icons.delete, 'Garbage', Colors.brown.shade700, () => _openGarbage(context)),            // 12
      _moduleCard(context, Icons.receipt, 'Billing', Colors.deepOrange, () => _openBilling(context)),               // 13
      _moduleCard(context, Icons.assessment, 'Reports', Colors.purple, () => _openReports(context)),                // 14
      _moduleCard(context, Icons.security, 'Audit\nReports', Colors.indigo, () => _openAuditReports(context)),      // 15
      _moduleCard(context, Icons.feedback, 'Feedback', Colors.amber.shade700, () => _openFeedback(context)),        // 16
      _moduleCard(context, Icons.schedule, 'Schedule', Colors.teal, () => _openSchedule(context)),                  // 17
      _moduleCard(context, Icons.inventory_2, 'Materials', Colors.blueGrey, () => _openMaterials(context)),         // 18
      _moduleCard(context, Icons.map, 'Area\nConfig', Colors.lightGreen, () => _openAreaConfig(context)),            // 19
      _moduleCard(context, Icons.assignment_turned_in, 'My\nTasks', Colors.deepOrange, () => _openWorkerTasks(context)), // 20
      _moduleCard(context, Icons.rate_review, 'Super.\nReview', Colors.purple, () => _openSupervisorReview(context)), // 21
      _moduleCard(context, Icons.dashboard_customize, 'Hier.\nDashboard', Colors.indigo.shade400, () => _openHierDashboard(context)), // 22
      _moduleCard(context, Icons.touch_app, 'Start\nTask', Colors.amber, () => _openQuickStart(context)),            // 23
      _moduleCard(context, Icons.layers, 'Zones', Colors.teal.shade700, () => _openZones(context)),                 // 24
      _moduleCard(context, Icons.business, 'Contractors', Colors.brown, () => _openContractors(context)),           // 25
      _moduleCard(context, Icons.qr_code, 'QR\nGenerator', Colors.indigo, () => _openQRGenerator(context)),        // 26
      _moduleCard(context, Icons.login, 'Check-in', kSuccessGreen, () => _openCheckin(context)),                  // 27
      _moduleCard(context, Icons.auto_awesome, 'Task\nGen', Colors.deepPurple, () => _openTaskGen(context)),       // 28
      _moduleCard(context, Icons.rate_review_outlined, 'Task\nApproval', kWarningOrange, () => _openTaskApproval(context)), // 29
      _moduleCard(context, Icons.speed, 'Area\nPerf.', kRailwayBlue, () => _openAreaPerformance(context)),         // 30
      _moduleCard(context, Icons.compare_arrows, 'Area\nCompare', Colors.teal, () => _openAreaComparison(context)),// 31
      _moduleCard(context, Icons.history, 'Area\nHistory', Colors.brown, () => _openAreaHistory(context)),         // 32
      _moduleCard(context, Icons.people, 'Area\nAssign', Colors.blueGrey, () => _openAreaAssignment(context)),     // 33
      _moduleCard(context, Icons.view_quilt, 'Platforms', Colors.teal, () => _openPlatforms(context)),             // 34
      _moduleCard(context, Icons.groups, 'Workforce', Colors.indigo.shade700, () => _openWorkforce(context)),       // 35
      _moduleCard(context, Icons.repeat, 'Frequency', Colors.cyan.shade700, () => _openFrequency(context)),         // 36
    ];

    final cards = <Widget>[];
    for (var i = 0; i < allCards.length; i++) {
      if (visible.contains(i)) cards.add(allCards[i]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(stationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    if (r == 'STATION_MASTER' || r == 'AREA_MASTER') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => StationMasterDashboardScreen(stationId: stationId, stationName: stationName)));
    } else if (r == 'PLATFORM_MASTER') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlatformMasterDashboardScreen(
        stationId: stationId, stationName: stationName,
        platformId: user?.platformId ?? '',
      )));
    } else if (r == 'RAILWAY_SUPERVISOR' || r == 'CONTRACTOR_SUPERVISOR') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorDashboardScreen(
        stationId: stationId, stationName: stationName,
        platformId: user?.platformId,
      )));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => StationDashboardKpiScreen(stationId: stationId, stationName: stationName)));
    }
  }

  void _openAttendance(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationAttendanceScreen(stationId: stationId, stationName: stationName)));
  }

  void _openActivities(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DailyActivityListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openExecution(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExecutionPlanListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openEvidence(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EvidenceGalleryScreen(stationId: stationId, stationName: stationName)));
  }

  void _openSupervisorLog(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorLogListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openInspection(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => InspectionListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openScorecard(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScorecardListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openComplaint(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ComplaintListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openPestControl(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PestControlListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openMachine(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MachineTrackingScreen(stationId: stationId, stationName: stationName)));
  }

  void _openGarbage(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GarbageManagementScreen(stationId: stationId, stationName: stationName)));
  }

  void _openBilling(BuildContext context) {
    if (contractId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => BillingSupportPackScreen(contractId: contractId!, stationId: stationId, stationName: stationName)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contract linked to this station')));
    }
  }

  void _openReports(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openAuditReports(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AuditReportListScreen(stationId: stationId, stationName: stationName)));
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackQrScreen(stationId: stationId, stationName: stationName)));
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.list, color: Colors.white)),
              title: const Text('View Feedback'),
              subtitle: const Text('Browse submitted passenger feedback'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => StationFeedbackListScreen(stationId: stationId)));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openCleaningForm(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationCleaningFormListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openSchedule(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationScheduleScreen(stationId: stationId, stationName: stationName)));
  }

  void _openMaterials(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MaterialListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openAreaConfig(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final role = user?.role ?? '';
    final r = role.toUpperCase().replaceAll(' ', '_');
    final platformId = r == 'PLATFORM_MASTER' ? user?.platformId : null;
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaConfigScreen(stationId: stationId, stationName: stationName, platformId: platformId)));
  }

  void _openWorkerTasks(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerTaskViewScreen(
          workerId: user?.uid ?? '',
          workerName: user?.fullName ?? '',
        ),
      ),
    );
  }

  void _openSupervisorReview(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorReviewScreen(stationId: stationId)));
  }

  void _openHierDashboard(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final role = user?.role ?? '';
    final r = role.toUpperCase().replaceAll(' ', '_');
    String? level;
    String? levelId;
    if (r == 'PLATFORM_MASTER') {
      level = 'platform';
      levelId = user?.platformId;
    } else if (r == 'STATION_MASTER' || r == 'AREA_MASTER') {
      level = 'station';
      levelId = stationId;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => HierarchicalDashboardScreen(initialLevel: level, levelId: levelId)));
  }

  void _openQuickStart(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.play_arrow, color: Colors.white)),
                title: const Text('Start Next Pending Task'),
                subtitle: const Text('Open your first pending task for today'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => WorkerTaskViewScreen(workerId: user?.uid ?? '', workerName: user?.fullName ?? ''),
                  ));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.preview, color: Colors.white)),
                title: const Text('Review Pending Tasks'),
                subtitle: const Text('View completed tasks awaiting approval'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorReviewScreen(stationId: stationId)));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.dashboard, color: Colors.white)),
                title: const Text('View Dashboard'),
                subtitle: const Text('Open the hierarchical dashboard'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HierarchicalDashboardScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openZones(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationZonesScreen(stationId: stationId, stationName: stationName)));
  }

  void _openContractors(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ContractorMappingScreen(stationId: stationId, stationName: stationName)));
  }

  void _openQRGenerator(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => QRCodeScreen(stationId: stationId, stationName: stationName)));
  }

  void _openCheckin(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerCheckinScreen(stationId: stationId, stationName: stationName)));
  }

  void _openTaskGen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskGenerationScreen(stationId: stationId, stationName: stationName)));
  }

  void _openTaskApproval(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskApprovalScreen(stationId: stationId, stationName: stationName)));
  }

  void _openAreaPerformance(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaPerformanceDashboard(stationId: stationId, stationName: stationName)));
  }

  void _openAreaComparison(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaComparisonScreen(stationId: stationId, stationName: stationName)));
  }

  void _openAreaHistory(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaHistoryScreen(stationId: stationId, stationName: stationName)));
  }

  void _openAreaAssignment(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaAssignmentScreen(stationId: stationId, stationName: stationName)));
  }

  void _openPlatforms(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlatformListScreen(stationId: stationId, stationName: stationName)));
  }

  void _openWorkforce(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WorkforceDeploymentScreen(stationId: stationId, stationName: stationName)));
  }

  void _openFrequency(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FrequencyListScreen()));
  }
}
