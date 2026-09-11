import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crm_train/model/user_entity_model.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/view/common_railways/station_management/station_master_screen.dart';
import 'package:crm_train/view/common_railways/station_management/station_cleaning_form_screen.dart';
import 'package:crm_train/view/common_railways/station_management/station_form_detail_screen.dart';
import 'package:crm_train/view/common_railways/station_management/activity_list_screen.dart';
import 'package:crm_train/view/common_railways/station_management/frequency_list_screen.dart';
import 'package:crm_train/view/common_railways/station_management/material_list_screen.dart';
import 'package:crm_train/view/common_railways/station_management/station_feedback_list_screen.dart';
import 'package:crm_train/view/common_railways/station_management/area_list_screen.dart';
import 'package:crm_train/view/station_cleaning/attendance/station_attendance_screen.dart';
import 'package:crm_train/view/station_cleaning/activities/daily_activity_list_screen.dart';
import 'package:crm_train/view/station_cleaning/billing/billing_support_pack_screen.dart';
import 'package:crm_train/view/common_railways/station_management/machine_master_list_screen.dart';
import 'package:crm_train/view/common_railways/station_management/archive_list_screen.dart';
import 'package:crm_train/view/station_cleaning/station_cleaning_hub_screen.dart';


class StationDashboardScreen extends StatefulWidget {
  const StationDashboardScreen({super.key});

  @override
  State<StationDashboardScreen> createState() => _StationDashboardScreenState();
}

class _StationDashboardScreenState extends State<StationDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isDashboardLoading = true;
  bool isStationsLoading = true;
  bool isFormsLoading = true;
  bool isContractorsLoading = false;
  String? dashboardError;
  String? stationsError;
  String? formsError;

  StationDashboardSummary? dashboard;
  List<Station> stations = [];
  List<StationCleaningForm> forms = [];

  List<Station> _allStations = [];
  List<StationCleaningForm> _allForms = [];
  List<EntityModel> contractors = [];

  DateTimeRange? _selectedDateRange;
  Station? _selectedStation;
  EntityModel? _selectedContractor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboard();
    _loadStations();
    _loadForms();
    _loadContractors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() { isDashboardLoading = true; dashboardError = null; });
    try {
      final data = await ApiService.getStationDashboard();
      if (mounted) setState(() { dashboard = data; isDashboardLoading = false; });
    } catch (e) {
      if (mounted) setState(() { isDashboardLoading = false; dashboardError = e.toString(); });
    }
  }

  Future<void> _loadContractors() async {
    if (mounted) setState(() { isContractorsLoading = true; });
    try {
      final data = await ApiService.getApprovedEntity();
      if (mounted) setState(() { contractors = data; isContractorsLoading = false; });
    } catch (e) {
      if (mounted) setState(() { isContractorsLoading = false; });
    }
  }

  void _applyFilters() {
    List<Station> tempStations = List.from(_allStations);
    List<StationCleaningForm> tempForms = List.from(_allForms);

    if (_selectedStation != null) {
      tempStations = tempStations.where((s) => s.uid == _selectedStation!.uid).toList();
      tempForms = tempForms.where((f) => f.stationId == _selectedStation!.uid).toList();
    }

    if (_selectedContractor != null) {
      tempForms = tempForms.where((f) => f.entityId == _selectedContractor!.uid).toList();
    }

    if (_selectedDateRange != null) {
      tempForms = tempForms.where((f) {
        if (f.cleaningDate == null || f.cleaningDate!.isEmpty) return false;
        try {
          final date = DateTime.parse(f.cleaningDate!);
          return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                 date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    setState(() {
      stations = tempStations;
      forms = tempForms;
    });
  }

  bool _isContractorRole(String role) {
    final r = role.toUpperCase().replaceAll(' ', '_');
    return r == 'CONTRACTOR_ADMIN' || r == 'CONTRACTOR_MASTER' || r == 'CONTRACTOR_SUPERVISOR';
  }

  Future<void> _loadStations() async {
    setState(() { isStationsLoading = true; stationsError = null; });
    try {
      final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '';
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final data = await ApiService.getStations();
      if (mounted) {
        List<Station> all = data;
        final roleUpper = role.toUpperCase().replaceAll(' ', '_');
        if (roleUpper == 'RAILWAY_SUPERVISOR') {
          all = all.where((s) => s.division == user?.division).toList();
        } else if (_isContractorRole(role)) {
          final userStationIds = <String>{};
          if (user?.stationId != null && user!.stationId!.isNotEmpty) {
            userStationIds.add(user.stationId!);
          }
          if (user?.stations != null && user!.stations.isNotEmpty) {
            userStationIds.addAll(user.stations);
          }
          if (userStationIds.isNotEmpty) {
            all = all.where((s) => s.uid != null && userStationIds.contains(s.uid)).toList();
          }
        }
        setState(() {
          _allStations = all;
          isStationsLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) setState(() { isStationsLoading = false; stationsError = e.toString(); });
    }
  }

  Future<void> _loadForms() async {
    setState(() { isFormsLoading = true; formsError = null; });
    try {
      final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '';
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final data = await ApiService.getStationCleaningForms();
      if (mounted) {
        List<StationCleaningForm> all = data;
        if (role == 'Railway Supervisor') {
          all = all.where((f) => f.division == user?.division).toList();
        } else if (role == 'Contractor Admin' || role == 'Contractor' || role == 'Contractor Master') {
          all = all.where((f) => f.submittedBy == user?.uid).toList();
        }
        setState(() {
          _allForms = all;
          isFormsLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) setState(() { isFormsLoading = false; formsError = e.toString(); });
    }
  }

  void _showDateFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Date Filter Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.date_range, color: kRailwayBlue),
              title: const Text('Select Date Range'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: _selectedDateRange,
                );
                if (picked != null) {
                  setState(() {
                    _selectedDateRange = picked;
                    _applyFilters();
                  });
                }
              },
            ),
            if (_selectedDateRange != null)
              ListTile(
                leading: const Icon(Icons.clear, color: kErrorRed),
                title: const Text('Clear Filter', style: TextStyle(color: kErrorRed)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedDateRange = null;
                    _applyFilters();
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showStationFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredStationsList = _allStations.where((s) =>
              s.stationName.toLowerCase().contains(searchQuery.toLowerCase()) ||
              s.stationCode.toLowerCase().contains(searchQuery.toLowerCase())
            ).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Select Station', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search Station...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_selectedStation != null)
                    ListTile(
                      leading: const Icon(Icons.clear, color: kErrorRed),
                      title: const Text('Clear Filter', style: TextStyle(color: kErrorRed, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedStation = null;
                          _applyFilters();
                        });
                      },
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredStationsList.length,
                      itemBuilder: (context, index) {
                        final station = filteredStationsList[index];
                        final isSelected = _selectedStation?.uid == station.uid;
                        return ListTile(
                          title: Text(station.stationName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text(station.stationCode),
                          trailing: isSelected ? const Icon(Icons.check, color: kSuccessGreen) : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedStation = station;
                              _applyFilters();
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showContractorFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredContractorsList = contractors.where((c) =>
              (c.contractorName ?? '').toLowerCase().contains(searchQuery.toLowerCase())
            ).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Select Contractor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search Contractor...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_selectedContractor != null)
                    ListTile(
                      leading: const Icon(Icons.clear, color: kErrorRed),
                      title: const Text('Clear Filter', style: TextStyle(color: kErrorRed, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedContractor = null;
                          _applyFilters();
                        });
                      },
                    ),
                  isContractorsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Expanded(
                          child: ListView.builder(
                            itemCount: filteredContractorsList.length,
                            itemBuilder: (context, index) {
                              final contractor = filteredContractorsList[index];
                              final isSelected = _selectedContractor?.uid == contractor.uid;
                              return ListTile(
                                title: Text(contractor.contractorName ?? '', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                subtitle: Text(contractor.email ?? ''),
                                trailing: isSelected ? const Icon(Icons.check, color: kSuccessGreen) : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _selectedContractor = contractor;
                                    _applyFilters();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Color _statusColor(StationFormStatus status) {
    switch (status) {
      case StationFormStatus.draft: return Colors.grey;
      case StationFormStatus.submitted: return Colors.blue;
      case StationFormStatus.approved: return kSuccessGreen;
      case StationFormStatus.scored: return Colors.purple;
      case StationFormStatus.locked: return Colors.grey.shade800;
      case StationFormStatus.rejected: return kErrorRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context).currentUser?.role ?? '';
    final isAdmin = role == 'SUPER_ADMIN' || role == 'Super Admin' || role == 'Railway Admin' || role == 'Railway Master' || role == 'Company Master' || role == 'Contractor Admin';
    final isSupervisor = role == 'Railway Supervisor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
            Tab(text: 'Stations', icon: Icon(Icons.train, size: 18)),
            Tab(text: 'Cleaning Forms', icon: Icon(Icons.cleaning_services, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isAdmin, isSupervisor),
          _buildStationsTab(isAdmin),
          _buildFormsTab(isAdmin, isSupervisor),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isAdmin, bool isSupervisor) {
    if (isDashboardLoading) return const Center(child: CircularProgressIndicator());
    if (dashboardError != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
      const SizedBox(height: 16),
      Text(dashboardError!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 8),
      ElevatedButton(onPressed: _loadDashboard, child: const Text('Retry')),
    ]));
    final d = dashboard;
    if (d == null) return const Center(child: Text('No data'));

    // Dynamic stats calculations based on filters
    double avgScore = d.averageScore;
    int pendingFormsCount = d.pendingReview;
    int totalStationsCount = d.totalStations;
    int activeStationsCount = d.activeStations;

    if (_selectedStation != null || _selectedContractor != null || _selectedDateRange != null) {
      totalStationsCount = stations.length;
      activeStationsCount = stations.where((s) => s.active).length;
      pendingFormsCount = forms.where((f) => f.status == StationFormStatus.submitted).length;
      
      final scoredForms = forms.where((f) => f.status == StationFormStatus.scored || f.status == StationFormStatus.locked).toList();
      if (scoredForms.isNotEmpty) {
        final totalScore = scoredForms.fold<double>(0.0, (sum, f) => sum + (f.score ?? 0.0));
        avgScore = totalScore / scoredForms.length;
      } else {
        avgScore = 0.0;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: [
              _summaryCard('Total Stations', '$totalStationsCount', kRailwayBlue, Icons.train),
              _summaryCard('Active Stations', '$activeStationsCount', kSuccessGreen, Icons.check_circle),
              _summaryCard('Areas', '${d.totalAreas}', Colors.teal, Icons.layers),
              _summaryCard('Zones', '${d.totalZones}', kWarningOrange, Icons.map),
              _summaryCard('Pending Forms', '$pendingFormsCount', kErrorRed, Icons.pending_actions),
              _summaryCard('Avg Score', '${avgScore.toStringAsFixed(1)}%', Colors.purple, Icons.score),
            ],
          ),
          const SizedBox(height: 20),

          // Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _filterChip(
                    Icons.calendar_today,
                    _selectedDateRange != null
                        ? "${DateFormat('dd/MM').format(_selectedDateRange!.start)}-${DateFormat('dd/MM').format(_selectedDateRange!.end)}"
                        : 'Date',
                    _showDateFilterOptions,
                    isActive: _selectedDateRange != null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _filterChip(
                    Icons.train,
                    _selectedStation != null ? _selectedStation!.stationName : 'Station',
                    _showStationFilterOptions,
                    isActive: _selectedStation != null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _filterChip(
                    Icons.person,
                    _selectedContractor?.contractorName ?? 'Contractor',
                    _showContractorFilterOptions,
                    isActive: _selectedContractor != null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Quick Actions
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _actionCard(
                    icon: Icons.add_location_alt,
                    title: 'Add Station',
                    subtitle: 'Register new station',
                    color: kRailwayBlue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StationMasterScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    icon: Icons.post_add,
                    title: 'New Cleaning Form',
                    subtitle: 'Create cleaning form',
                    color: kSuccessGreen,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StationCleaningFormScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    icon: Icons.visibility,
                    title: 'View All',
                    subtitle: 'See all stations',
                    color: kWarningOrange,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _actionCard(
                    icon: Icons.people,
                    title: 'Attendance',
                    subtitle: 'Mark daily attendance',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StationAttendanceScreen(
                          stationId: _selectedStation?.uid ?? '',
                          stationName: _selectedStation?.stationName ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    icon: Icons.assignment_turned_in,
                    title: 'Daily Activities',
                    subtitle: 'Record cleaning tasks',
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DailyActivityListScreen(
                          stationId: _selectedStation?.uid ?? '',
                          stationName: _selectedStation?.stationName ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    icon: Icons.receipt_long,
                    title: 'Billing Packs',
                    subtitle: 'Monthly billing packs',
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BillingSupportPackScreen(
                          stationId: _selectedStation?.uid ?? '',
                          stationName: _selectedStation?.stationName ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Master Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _actionCard(
                    icon: Icons.cleaning_services,
                    title: 'Activities',
                    subtitle: 'Activity types',
                    color: kRailwayBlue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionCard(
                    icon: Icons.schedule,
                    title: 'Frequencies',
                    subtitle: 'Cleaning frequencies',
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FrequencyListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionCard(
                    icon: Icons.map,
                    title: 'Areas',
                    subtitle: 'Station areas',
                    color: Colors.brown,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AreaListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionCard(
                    icon: Icons.inventory_2,
                    title: 'Materials',
                    subtitle: 'Stock & tracking',
                    color: kWarningOrange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialListScreen())),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _actionCard(
                    icon: Icons.feedback,
                    title: 'Feedback',
                    subtitle: 'Passenger feedback',
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StationFeedbackListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionCard(
                    icon: Icons.precision_manufacturing,
                    title: 'Machines',
                    subtitle: 'Equipment master',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MachineMasterListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionCard(
                    icon: Icons.archive,
                    title: 'Archives',
                    subtitle: 'Monthly archives',
                    color: Colors.brown,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveListScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(2, 3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isActive ? kRailwayBlue.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? kRailwayBlue : Colors.grey.shade300, width: isActive ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? kRailwayBlue : Colors.grey[600]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? kRailwayBlue : Colors.grey[700],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: isActive ? kRailwayBlue : Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsTab(bool isAdmin) {
    if (isStationsLoading) return const Center(child: CircularProgressIndicator());
    if (stationsError != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
      const SizedBox(height: 16),
      Text(stationsError!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 8),
      ElevatedButton(onPressed: _loadStations, child: const Text('Retry')),
    ]));
    if (stations.isEmpty) return const Center(child: Text('No stations found'));

    return RefreshIndicator(
      onRefresh: _loadStations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final s = stations[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.train, color: kRailwayBlue, size: 24),
              ),
              title: Text(s.stationName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Code: ${s.stationCode}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(s.categoryLabel, style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${s.zone} / ${s.division}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cleaning_services, color: kSuccessGreen),
                    tooltip: 'Station Cleaning',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StationCleaningHubScreen(
                          stationId: s.uid ?? '', stationName: s.stationName ?? '',
                          contractId: null,
                        ),
                      ));
                    },
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => StationMasterScreen(existingStation: s)
                )).then((_) => _loadStations());
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormsTab(bool isAdmin, bool isSupervisor) {
    if (isFormsLoading) return const Center(child: CircularProgressIndicator());
    if (formsError != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
      const SizedBox(height: 16),
      Text(formsError!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 8),
      ElevatedButton(onPressed: _loadForms, child: const Text('Retry')),
    ]));
    if (forms.isEmpty) return const Center(child: Text('No cleaning forms found'));

    return RefreshIndicator(
      onRefresh: _loadForms,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: forms.length,
        itemBuilder: (context, index) {
          final f = forms[index];
          final statusColor = _statusColor(f.status);
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.cleaning_services, color: statusColor, size: 22),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(f.formId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(f.statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Station: ${f.stationName}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    const SizedBox(height: 2),
                    Text('Date: ${f.cleaningDate} | Shift: ${f.shift}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              isThreeLine: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StationFormDetailScreen(formUid: f.uid ?? ''))),
            ),
          );
        },
      ),
    );
  }
}
