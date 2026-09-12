import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/view/common_railways/station_management/station_master_screen.dart';


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
  String? dashboardError;
  String? stationsError;

  StationDashboardSummary? dashboard;
  List<Station> stations = [];
  List<Station> _allStations = [];

  Station? _selectedStation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDashboard();
    _loadStations();
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

  void _applyFilters() {
    List<Station> tempStations = List.from(_allStations);

    if (_selectedStation != null) {
      tempStations = tempStations.where((s) => s.uid == _selectedStation!.uid).toList();
    }

    setState(() {
      stations = tempStations;
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isAdmin, isSupervisor),
          _buildStationsTab(isAdmin),
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

    int totalStationsCount = d.totalStations;
    int activeStationsCount = d.activeStations;

    if (_selectedStation != null) {
      totalStationsCount = stations.length;
      activeStationsCount = stations.where((s) => s.active).length;
    }

    final divisionsCount = _allStations.map((s) => s.division.toLowerCase()).toSet().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              _summaryCard('Zones', '${d.totalZones}', kWarningOrange, Icons.map),
              _summaryCard('Divisions', '$divisionsCount', Colors.teal, Icons.account_tree),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _filterChip(
                    Icons.train,
                    _selectedStation != null ? _selectedStation!.stationName : 'Station',
                    _showStationFilterOptions,
                    isActive: _selectedStation != null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

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
                    icon: Icons.visibility,
                    title: 'View All',
                    subtitle: 'See all stations',
                    color: kWarningOrange,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ),
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
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
}
