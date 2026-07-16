import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/view/common_contractor/form_screen/forms/cts_form_screen_v2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_services.dart';
import '../../../services/dashboard_counts_service.dart';
import '../../common_railways/widgets/DonutChart.dart';
import '../../common_railways/widgets/indicator_color.dart';
import '../../common_railways/widgets/status_tile.dart';
import '../../onboarding_screens/login_screen.dart';
import '../alert/contractor_master_alert_screen.dart';
import '../profile/contractor_master_profile_screen.dart';
import '../form_screen/forms/new_coach_form.dart';
import '../form_screen/forms/new_premises_form.dart';
import '../form_screen/contractor_master_forms_screen.dart';

import '../../common_railways/entities/common_entity_managment_screen.dart';
import '../../common_railways/trains/common_train_screen.dart';
import '../../common_railways/users/common_user_management_screen.dart';
import '../../common_railways/contracts/common_contracts_screen.dart';
import '../../common_railways/divisions/division_management_screen.dart';
import '../../obhs_screens/obhs_runs_list_screen.dart';
import '../../obhs_screens/obhs_attendance_list_screen.dart';
import '../../common_railways/complaints/admin_complaints_screen.dart';
import '../../common_railways/audit/audit_log_screen.dart';
import '../../common_railways/billing/billing_dashboard_screen.dart';
import '../../common_railways/cleaning_forms/cleaning_form_dashboard.dart';
import '../../station_cleaning_screens/station_cleaning_runs_list_screen.dart';
import '../../common_railways/station_management/station_dashboard_screen.dart';
import '../../common_railways/report/common_report_screen.dart';
import '../../common_railways/attendance/attendance_exception_dashboard.dart';
import '../../common_railways/ratings/admin_ratings_screen.dart';
import '../../common_railways/station_management/area_list_screen.dart';
import '../../common_railways/station_management/task_generation_screen.dart';
import '../../common_railways/station_management/task_approval_screen.dart';
import '../../common_railways/station_management/machine_master_list_screen.dart';
import '../../common_railways/station_management/material_list_screen.dart';
import '../../common_railways/station_management/area_performance_dashboard.dart';

class ContractorMasterDashboard extends StatefulWidget {
  const ContractorMasterDashboard({super.key});

  @override
  _ContractorMasterDashboardState createState() => _ContractorMasterDashboardState();
}

class _ContractorMasterDashboardState extends State<ContractorMasterDashboard> {

  int coachTotal = 0;
  int coachPending = 0;
  int coachManpowerApproved = 0;
  int coachRejected = 0;
  int coachScoringProgress = 0;
  int coachAutoApproved = 0;
  int coachLocked = 0;

  int premisesTotal = 0;
  int premisesPending = 0;
  int premisesManpowerApproved = 0;
  int premisesRejected = 0;
  int premisesScoringProgress = 0;
  int premisesAutoApproved = 0;
  int premisesLocked = 0;

  int ctsTotal = 0;
  int ctsPending = 0;
  int ctsManpowerApproved = 0;
  int ctsRejected = 0;
  int ctsScoringProgress = 0;
  int ctsAutoApproved = 0;
  int ctsLocked = 0;


  Map<String, dynamic> coachCleaningStats = {};
  Map<String, dynamic> premisesCleaningStats = {};
  Map<String, dynamic> ctsStats = {};
  bool isChartLoading = true;
  bool isStatsLoading = true;

  String dateRange = 'Last 30 days';

  List<Map<String, dynamic>> get coachKpi => [
    {'title': 'Pending', 'value': coachPending.toString()},
    {'title': 'Approved', 'value': coachManpowerApproved.toString()},
    {'title': 'Rejected', 'value': coachRejected.toString()},
    {'title': 'Scoring Progress', 'value': coachScoringProgress.toString()},
    {'title': 'Auto-Approved', 'value': coachAutoApproved.toString()},
    {'title': 'Locked', 'value': coachLocked.toString()},
  ];

  List<Map<String, dynamic>> get premisesKpi => [
    {'title': 'Pending', 'value': premisesPending.toString()},
    {'title': 'Approved', 'value': premisesManpowerApproved.toString()},
    {'title': 'Rejected', 'value': premisesRejected.toString()},
    {'title': 'Scoring Progress', 'value': premisesScoringProgress.toString()},
    {'title': 'Auto-Approved', 'value': premisesAutoApproved.toString()},
    {'title': 'Locked', 'value': premisesLocked.toString()},
  ];

  List<Map<String, dynamic>> get ctsKpi => [
    {'title': 'Pending', 'value': ctsPending.toString()},
    {'title': 'Approved', 'value': ctsAutoApproved.toString()},
    {'title': 'Rejected', 'value': ctsRejected.toString()},
    {'title': 'Scoring Progress', 'value': ctsScoringProgress.toString()},
    {'title': 'Auto-Approved', 'value': ctsAutoApproved.toString()},
    {'title': 'Locked', 'value': ctsLocked.toString()},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  int _getDaysFromRange() {
    switch (dateRange) {
      case 'Last 7 days':
        return 7;
      case 'Last 30 days':
        return 30;
      case 'Last 90 days':
        return 90;
      case 'This month':
        final now = DateTime.now();
        return now.day;
      default:
        return 30;
    }
  }

  DateTime? _getStartDate() {
    final now = DateTime.now();
    switch (dateRange) {
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 days':
        return now.subtract(const Duration(days: 30));
      case 'Last 90 days':
        return now.subtract(const Duration(days: 90));
      case 'This month':
        return DateTime(now.year, now.month, 1);
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  DateTime? _getEndDate() {
    final now = DateTime.now();
    if (dateRange == 'This month') {
      return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }
    return now;
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadFormStatusCounts(),
      _loadCleaningStats(),
    ]);
  }

  Future<void> _loadFormStatusCounts() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      return;
    }

    setState(() => isChartLoading = true);

    try {
      final days = _getDaysFromRange();

      final coachStats = await FirebaseCountService.getFormStatusCounts(
        formType: 'coach',
        days: days,
        entityId: user.entityId,
      );

      print("Coach Forms Stats: $coachStats");

      final premisesStatsData = await FirebaseCountService.getFormStatusCounts(
        formType: 'premises',
        days: days,
        entityId: user.entityId,
      );

      print("Premises Forms Stats: $premisesStatsData");

      final ctsStatsData = await FirebaseCountService.getFormStatusCounts(
        formType: 'cts',
        days: days,
        entityId: user.entityId,
      );

      print("CTS Forms Stats: $ctsStatsData");

      print("=" * 60);

      setState(() {
        coachTotal = coachStats['total'] ?? 0;
        coachPending = coachStats['pending'] ?? 0;
        coachManpowerApproved = coachStats['manpowerApproved'] ?? 0;
        coachRejected = coachStats['rejected'] ?? 0;
        coachScoringProgress = coachStats['scoringProgress'] ?? 0;
        coachAutoApproved = coachStats['autoApproved'] ?? 0;
        coachLocked = coachStats['locked'] ?? 0;

        premisesTotal = premisesStatsData['total'] ?? 0;
        premisesPending = premisesStatsData['pending'] ?? 0;
        premisesManpowerApproved = premisesStatsData['manpowerApproved'] ?? 0;
        premisesRejected = premisesStatsData['rejected'] ?? 0;
        premisesScoringProgress = premisesStatsData['scoringProgress'] ?? 0;
        premisesAutoApproved = premisesStatsData['autoApproved'] ?? 0;
        premisesLocked = premisesStatsData['locked'] ?? 0;

        ctsTotal = ctsStatsData['total'] ?? 0;
        ctsPending = ctsStatsData['pending'] ?? 0;
        ctsManpowerApproved = ctsStatsData['manpowerApproved'] ?? 0;
        ctsRejected = ctsStatsData['rejected'] ?? 0;
        ctsScoringProgress = ctsStatsData['scoringProgress'] ?? 0;
        ctsAutoApproved = ctsStatsData['autoApproved'] ?? 0;
        ctsLocked = ctsStatsData['locked'] ?? 0;

        isChartLoading = false;
      });
    } catch (e) {
      print("Error loading form status counts: $e");
      setState(() => isChartLoading = false);
    }
  }

  Future<void> _loadCleaningStats() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => isStatsLoading = true);

    try {
      final startDate = _getStartDate();
      final endDate = _getEndDate();

      print("Loading Cleaning Stats...");

      final coachStatsData = await FirebaseCountService.getCoachCleaningStats(
        userRole: user.role,
        uid: user.uid,
        zone: user.zone,
        division: user.division,
        depot: user.depot,
        entityId: user.entityId,
        startDate: startDate,
        endDate: endDate,
      );


      final premisesStatsData = await FirebaseCountService.getPremisesCleaningStats(
        userRole: user.role,
        uid: user.uid,
        zone: user.zone,
        division: user.division,
        depot: user.depot,
        entityId: user.entityId,
        startDate: startDate,
        endDate: endDate,
      );


      setState(() {
        coachCleaningStats = coachStatsData;
        premisesCleaningStats = premisesStatsData;
        isStatsLoading = false;
      });
    } catch (e) {
      print("Error loading cleaning stats: $e");
      setState(() => isStatsLoading = false);
    }
  }

  final List<String> dateRanges = [
    'Last 7 days',
    'Last 30 days',
    'Last 90 days',
    'This month'
  ];

  @override

  List<Map<String, dynamic>> _getSidebarMenuItems(String? userRole) {
    return [
      {
        "icon": Icons.dashboard_rounded,
        "title": "Dashboard",
        "route": null,
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin", "Railway Supervisor", "Contractor Supervisor"]
      },
      {
        "icon": Icons.admin_panel_settings,
        "title": "Masters",
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin"],
        "children": [
          {"title": "User Management", "route": "users"},
          {"title": "Entity Management", "route": "entities"},
          {"title": "Contract Management", "route": "contracts"},
          {"title": "Station Management", "route": "station_management_master"},
          {"title": "Train Management", "route": "trains"},
          {"title": "Division Management", "route": "divisions"},
          {"title": "Billing Rules", "route": "billing_rules"},
        ]
      },
      {
        "icon": Icons.cleaning_services,
        "title": "Operations",
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin", "Railway Supervisor", "Contractor Supervisor"],
        "children": [
          {"title": "Coach Cleaning", "route": "coach_cleaning"},
          {"title": "Premise Cleaning", "route": "premise_cleaning"},
          {"title": "CTS Forms", "route": "cts_cleaning"},
          {"title": "Station Cleaning Forms", "route": "station_cleaning"},
          {"title": "Station Cleaning Runs", "route": "station_cleaning_runs"},
        ]
      },
      {
        "icon": Icons.cleaning_services_rounded,
        "title": "Station Cleaning",
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin", "Railway Supervisor", "Contractor Supervisor"],
        "children": [
          {"title": "Dashboard", "route": "sc_dashboard"},
          {"title": "Area Management", "route": "sc_areas"},
          {"title": "Generate Tasks", "route": "sc_generate_tasks"},
          {"title": "Task Approval", "route": "sc_approval"},
          {"title": "Machines", "route": "sc_machines"},
          {"title": "Materials", "route": "sc_materials"},
          {"title": "Performance Reports", "route": "sc_performance"},
        ]
      },
      {
        "icon": Icons.directions_run,
        "title": "OBHS",
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin", "Railway Supervisor", "Contractor Supervisor"],
        "children": [
          {"title": "Attendance", "route": "obhs_attendance"},
          {"title": "Attendance Exceptions", "route": "attendance_exceptions"},
          {"title": "Tasks", "route": "obhs_tasks"},
          {"title": "Complaints", "route": "complaints"},
        ]
      },
      {
        "icon": Icons.analytics,
        "title": "Reports",
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin", "Railway Supervisor", "Contractor Supervisor"],
        "children": [
          {"title": "Coach Reports", "route": "coach_reports"},
          {"title": "Premise Reports", "route": "premise_reports"},
          {"title": "Station Reports", "route": "station_reports"},
          {"title": "OBHS Reports", "route": "obhs_reports"},
        ]
      },
      {
        "icon": Icons.receipt_long,
        "title": "Billing",
        "route": "billing",
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin", "Railway Supervisor"]
      },
      {
        "icon": Icons.star_outline,
        "title": "Ratings",
        "route": "ratings",
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin", "Railway Supervisor"]
      },
      {
        "icon": Icons.security,
        "title": "Audit & Compliance",
        "roles": ["Contractor Master", "Company Master", "Contractor Admin", "Railway Master", "Railway Admin"],
        "children": [
          {"title": "Compliance & Security Tracking", "route": "audit_logs"},
          {"title": "Business Activities", "route": "activity_logs"},
        ]
      },
    ].where((item) => (item['roles'] as List<String>).contains(userRole)).toList();
  }

  void _handleSidebarNavigation(String? route, BuildContext context, String? userRole) {
    if (route == null) {
      Navigator.pop(context); // Close drawer
      return;
    }

    Navigator.pop(context); // Always close drawer on selection

    switch (route) {
      case "users":
        Navigator.push(context, MaterialPageRoute(builder: (context) => CommonUserManagementScreen()));
        break;
      case "entities":
        Navigator.push(context, MaterialPageRoute(builder: (context) => CommonEntityManagmentScreen()));
        break;
      case "contracts":
        Navigator.push(context, MaterialPageRoute(builder: (context) => CommonContractsScreen(userRole: userRole ?? '')));
        break;
      case "station_management_master":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const StationDashboardScreen()));
        break;
      case "trains":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CommonTrainScreen()));
        break;
      case "coach_cleaning":
        Navigator.push(context, MaterialPageRoute(builder: (context) => ContractorMasterFormsScreen(initialTabIndex: 0)));
        break;
      case "premise_cleaning":
        Navigator.push(context, MaterialPageRoute(builder: (context) => ContractorMasterFormsScreen(initialTabIndex: 1)));
        break;
      case "cts_cleaning":
        Navigator.push(context, MaterialPageRoute(builder: (context) => ContractorMasterFormsScreen(initialTabIndex: 2)));
        break;
      case "station_cleaning":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const StationDashboardScreen()));
        break;
      case "station_cleaning_runs":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const StationCleaningRunsListScreen()));
        break;
      case "sc_dashboard":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const StationDashboardScreen()));
        break;
      case "sc_areas":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AreaListScreen()));
        break;
      case "sc_generate_tasks":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskGenerationScreen()));
        break;
      case "sc_approval":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskApprovalScreen()));
        break;
      case "sc_machines":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MachineMasterListScreen()));
        break;
      case "sc_materials":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MaterialListScreen()));
        break;
      case "sc_performance":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AreaPerformanceDashboard()));
        break;
      case "obhs_attendance":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const OBHSAttendanceListScreen()));
        break;
      case "attendance_exceptions":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceExceptionDashboard()));
        break;
      case "obhs_tasks":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const OBHSRunsListScreen()));
        break;
      case "coach_reports":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CommonReportScreen(initialIndex: 1)));
        break;
      case "premise_reports":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CommonReportScreen(initialIndex: 0)));
        break;
      case "station_reports":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CommonReportScreen(initialIndex: 2)));
        break;
      case "obhs_reports":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CommonReportScreen(initialIndex: 3)));
        break;
      case "divisions":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const DivisionManagementScreen()));
        break;
      case "billing_rules":
      case "billing":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const BillingDashboardScreen()));
        break;
      case "ratings":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRatingsScreen()));
        break;
      case "audit_logs":
      case "activity_logs":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AuditLogScreen()));
        break;
      case "complaints":
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminComplaintsScreen()));
        break;
      default:
        break;
    }
  }

  Widget _buildDrawer(var user, List<Map<String, dynamic>> sidebarMenuItems) {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kRailwayBlue, Colors.lightBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 35,
                  child: Icon(Icons.person, size: 40, color: kRailwayBlue),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.role ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sidebarMenuItems.length,
              itemBuilder: (context, index) {
                final item = sidebarMenuItems[index];
                final isCurrentScreen = item['route'] == null && !item.containsKey('children');

                if (item.containsKey('children')) {
                  final children = item['children'] as List<Map<String, dynamic>>;
                  return ExpansionTile(
                    leading: Icon(
                      item['icon'] as IconData,
                      color: Colors.grey[700],
                    ),
                    title: Text(
                      item['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    children: children.map((child) {
                      return ListTile(
                        contentPadding: const EdgeInsets.only(left: 72, right: 16),
                        title: Text(
                          child['title'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        onTap: () => _handleSidebarNavigation(
                          child['route'] as String?,
                          context,
                          user?.role,
                        ),
                      );
                    }).toList(),
                  );
                }

                return ListTile(
                  leading: Icon(
                    item['icon'] as IconData,
                    color: isCurrentScreen ? kRailwayBlue : Colors.grey[700],
                  ),
                  title: Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontWeight: isCurrentScreen ? FontWeight.bold : FontWeight.w500,
                      color: isCurrentScreen ? kRailwayBlue : Colors.grey[800],
                    ),
                  ),
                  selected: isCurrentScreen,
                  selectedTileColor: kRailwayBlue.withOpacity(0.1),
                  onTap: () => _handleSidebarNavigation(
                    item['route'] as String?,
                    context,
                    user?.role,
                  ),
                );
              },
            ),
          ),
          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              onTap: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final entityDetails = authProvider.entityDetails;
    const cardBg = Colors.white;
    const accentGreen = Color(0xFF12C27D);
    const softBorder = Color(0xFFE8E8F0);

    final sidebarMenuItems = _getSidebarMenuItems(user?.role);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: kRailwayBlue,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: (){

            Navigator.push(context, MaterialPageRoute(builder: (context) => ContractorMasterProfileScreen()));

          }, icon: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Icon(Icons.person,color: kRailwayBlue))),
          IconButton(onPressed: (){

            Navigator.push(context, MaterialPageRoute(builder: (context) => ContractorMasterAlertScreen()));

          }, icon: Icon(Icons.notifications,color: Colors.white,)),
          IconButton(onPressed: (){
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
            );
          },
              icon: Icon(Icons.logout,color: Colors.white,)),

        ],

      ),
      drawer: _buildDrawer(user, sidebarMenuItems),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          color: kRailwayBlue,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: kRailwayBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10)
                        ),
                        child:  Icon(Icons.location_city_outlined, color: kRailwayBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:  [
                            Text(user?.fullName ?? "NA",
                                style:
                                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            SizedBox(height: 4),
                            Text( entityDetails?['companyName'] ?? 'N/A',
                                style: TextStyle(fontSize: 13, color: Colors.black54)),
                            SizedBox(height: 2),
                            Text(entityDetails?['registeredAddress'] ?? 'N/A',
                                style: TextStyle(fontSize: 12, color: Colors.black45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date Range',
                        style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _buildDropdown(
                          current: dateRange,
                          items: dateRanges,
                          onChanged: (v) {
                            setState(() => dateRange = v!);
                            _loadAllData();
                          }),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Text("Forms Overview",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),

                SizedBox(
                  height: 370,
                  child: ListView(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFormsCard(
                        'Coach\nCleaning',
                        pending: coachPending,
                        approved: coachManpowerApproved,
                        rejected: coachRejected,
                        progress: coachScoringProgress,
                        autoApproved: coachAutoApproved,
                        locked: coachLocked,
                      ),
                      const SizedBox(width: 16),
                      _buildFormsCard(
                        'Premises\nCleaning',
                        pending: premisesPending,
                        approved: premisesManpowerApproved,
                        rejected: premisesRejected,
                        progress: premisesScoringProgress,
                        autoApproved: premisesAutoApproved,
                        locked: premisesLocked,
                      ),
                      const SizedBox(width: 16),
                      _buildFormsCard(
                        'CTS\nForm',
                        pending: ctsPending,
                        approved: ctsManpowerApproved,
                        rejected: ctsRejected,
                        progress: ctsScoringProgress,
                        autoApproved: ctsAutoApproved,
                        locked: ctsLocked,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text("Coach Cleaning Forms",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: List.generate(coachKpi.length, (index) {
                        final item = coachKpi[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: StatusTile(
                            number: int.parse(item['value']),
                            label: item['title'],
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text("Premises Cleaning Forms",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: List.generate(premisesKpi.length, (index) {
                        final item = premisesKpi[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: StatusTile(
                            number: int.parse(item['value']),
                            label: item['title'],
                          ),
                        );
                      }),
                    ),
                  ),
                ),


                const SizedBox(height: 20),

                Text("CTS Forms",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: List.generate(ctsKpi.length, (index) {
                        final item = ctsKpi[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: StatusTile(
                            number: int.parse(item['value']),
                            label: item['title'],
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Column(
                  children: [
                    _scoreCardCoach(
                      title: 'Overall Score — Coach Cleaning',
                      accent: accentGreen,
                      softBorder: softBorder,
                      cardBg: cardBg,
                      subtitle: 'Based on selected filters',
                      iconInner: Icons.cleaning_services,
                    ),

                    const SizedBox(height: 12),
                    _scoreCardPremises(
                      title: 'Overall Score — Premises Cleaning',
                      accent: accentGreen,
                      softBorder: softBorder,
                      cardBg: cardBg,
                      subtitle: 'Based on selected filters',
                      iconInner: Icons.cleaning_services,
                    ),
                  ],
                ),

                const SizedBox(height: 18),



                if(user?.role == 'Contractor Supervisor')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0,3))
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick Actions',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => const NewCoachFormScreen()));
                                },
                                child: Container(
                                  height: 96,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8FBF0),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                    Border.all(color: const Color(0xFFCFF3E2)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.note_add, size: 28, color: Colors.green),
                                      SizedBox(height: 8),
                                      Text('New Coach Form',
                                          style: TextStyle(fontWeight: FontWeight.w600))
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>  PremisesCleaningForm()));
                                },
                                child: Container(
                                  height: 96,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6EDFF),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                    Border.all(color: const Color(0xFFEBDEF9)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.library_add, size: 28, color: Colors.purple),
                                      SizedBox(height: 8),
                                      Text('New Premises Form',
                                          style: TextStyle(fontWeight: FontWeight.w600))
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12,),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => const NewCTSFormScreen()));
                                },
                                child: Container(
                                  height: 96,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color:   Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                    Border.all(color:  Colors.orange.shade100),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.note_add, size: 28, color: Colors.orange),
                                      SizedBox(height: 8),
                                      Text('New CTS Form',
                                          style: TextStyle(fontWeight: FontWeight.w600))
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          ],
                        )
                      ],
                    ),
                  ),


                const SizedBox(height: 28)
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _scoreCardPremises({
    required String title,
    required Color accent,
    required String subtitle,
    required Color cardBg,
    required Color softBorder,
    required IconData iconInner,
  }) {
    final List<Map<String, String>> grades = [
      {'grade': '>90', 'pct': '${premisesCleaningStats['gradeAbove90Pct'] ?? '0.0'}%'},
      {'grade': '81-90', 'pct': '${premisesCleaningStats['grade81to90Pct'] ?? '0.0'}%'},
      {'grade': '71-80', 'pct': '${premisesCleaningStats['grade71to80Pct'] ?? '0.0'}%'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: softBorder),
      ),
      child: isStatsLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
        children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.black54, fontSize: 13))
                ]),
          ),

          Row(
            children: grades
                .map((g) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 50,
                height: 60,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      g['grade']!,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      g['pct']!,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _scoreCardCoach({
    required String title,
    required Color accent,
    required String subtitle,
    required Color cardBg,
    required Color softBorder,
    required IconData iconInner,
  }) {
    final List<Map<String, String>> grades = [
      {'grade': 'A', 'pct': '${coachCleaningStats['gradeAPercent'] ?? '0.0'}%'},
      {'grade': 'B', 'pct': '${coachCleaningStats['gradeBPercent'] ?? '0.0'}%'},
      {'grade': 'C', 'pct': '${coachCleaningStats['gradeCPercent'] ?? '0.0'}%'},
      {'grade': 'D', 'pct': '${coachCleaningStats['gradeDPercent'] ?? '0.0'}%'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: softBorder),
      ),
      child: isStatsLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
        children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.black54, fontSize: 13))
                ]),
          ),
          Row(
            children: grades
                .map((g) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 50,
                height: 60,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      g['grade']!,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      g['pct']!,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ))
                .toList(),
          ),
        ],
      ),
    );
  }




  Widget _buildFormsCard(
      String title, {
        required int pending,
        required int approved,
        required int rejected,
        required int progress,
        required int autoApproved,
        required int locked,
      }) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: isChartLoading
                  ? Center(child: CircularProgressIndicator())
                  : DonutChart(
                midText: title,
                pending: pending,
                approved: approved,
                rejected: rejected,
                progress: progress,
                autoApproved: autoApproved,
                locked: locked,
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LegendItem(color: Colors.green, label: "Pending"),
                SizedBox(width: 16),
                LegendItem(color: Colors.orange, label: "Approved"),
                SizedBox(width: 16),
                LegendItem(color: Colors.purple, label: "Rejected"),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LegendItem(color: Colors.blue, label: "Progress"),
                SizedBox(width: 16),
                LegendItem(color: Colors.grey, label: "Auto-Approved"),
                SizedBox(width: 16),
                LegendItem(color: Colors.red, label: "Locked"),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String current,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12,vertical: 10),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE6E6F0)),
          color: Colors.white),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
            isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
        value: items.contains(current) ? current : null,
        onChanged: onChanged,
        items: items
            .map((e) => DropdownMenuItem<String>(
          value: e,
          child: Text(e, style: const TextStyle(fontSize: 13)),
        ))
            .toList(),
      ),
    );
  }

}