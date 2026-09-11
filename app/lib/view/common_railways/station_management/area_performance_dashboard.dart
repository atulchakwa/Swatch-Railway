import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/model/platform_model.dart';
import 'package:crm_train/repositories/platform_repository.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

class AreaPerformanceDashboard extends StatefulWidget {
  final String? areaId;
  final String? areaName;
  final String? stationId;
  final String? stationName;
  const AreaPerformanceDashboard({super.key, this.areaId, this.areaName, this.stationId, this.stationName});

  @override
  State<AreaPerformanceDashboard> createState() => _AreaPerformanceDashboardState();
}

class _AreaPerformanceDashboardState extends State<AreaPerformanceDashboard> {
  List<Station> _stations = [];
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;

  String? _selectedStationId;
  String? _selectedPlatformId;
  List<Platform> _platformsOfStation = [];
  bool _loadingPlatforms = false;

  @override
  void initState() {
    super.initState();
    _selectedStationId = widget.stationId;
    if (_selectedStationId != null) {
      _loadDashboard();
      _loadStations();
    } else {
      _loadStations();
    }
  }

  Future<void> _loadStations() async {
    try {
      final stationsList = await ApiService.getStations(active: true);
      setState(() {
        _stations = stationsList;
      });
      if (_selectedStationId != null) {
        await _loadPlatformsForStation(_selectedStationId!);
      }
    } catch (_) {}
    if (_selectedStationId == null && mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlatformsForStation(String stationId) async {
    if (mounted) setState(() => _loadingPlatforms = true);
    try {
      final platforms = await PlatformRepository.getByStation(stationId);
      setState(() {
        _platformsOfStation = platforms;
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingPlatforms = false);
  }

  Future<void> _loadDashboard() async {
    if (_selectedStationId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final path = _selectedPlatformId != null
          ? '/api/dashboard/platform/$_selectedPlatformId'
          : '/api/dashboard/station/$_selectedStationId';

      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: path,
        parser: (d) => d,
      );
      setState(() {
        _dashboardData = result;
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Performance';
    if (_dashboardData != null) {
      final level = _dashboardData!['level'] ?? 'station';
      if (level == 'station') {
        title = 'Performance: ${_dashboardData!['stationName'] ?? ''}';
      } else {
        title = 'Performance: Platform ${_dashboardData!['platformNumber'] ?? _dashboardData!['platformName'] ?? ''}';
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: kErrorRed),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadDashboard, child: const Text('Retry')),
                    ],
                  ),
                )
              : _dashboardData == null
                  ? _buildSelectionUI()
                  : RefreshIndicator(
                      onRefresh: _loadDashboard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDashboardUI(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildDashboardUI() {
    final level = _dashboardData!['level'] ?? 'station';
    if (level == 'station') {
      return _buildStationDashboard();
    } else {
      return _buildPlatformDashboard();
    }
  }

  Widget _buildStationDashboard() {
    final cleaning = _dashboardData!['cleaning'] ?? {};
    final attendance = _dashboardData!['attendance'] ?? {};
    final feedback = _dashboardData!['feedback'] ?? {};
    final complaints = _dashboardData!['complaints'] ?? {};
    final machines = _dashboardData!['machines'] ?? {};
    final activities = _dashboardData!['activities'] ?? {};
    final platformsList = _dashboardData!['platforms'] as List<dynamic>? ?? [];

    final totalTasks = (cleaning['total'] ?? 0).toString();
    final approvedTasks = (cleaning['approved'] ?? 0).toString();
    final pendingTasks = (cleaning['pending'] ?? 0).toString();
    final inProgressTasks = (cleaning['inProgress'] ?? 0).toString();
    final rejectedTasks = (cleaning['rejected'] ?? 0).toString();

    final attendanceRate = attendance['attendanceRate'] ?? 0;
    final avgRating = feedback['averageRating'] ?? 0.0;
    final openComplaints = complaints['open'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLevelBadge('Station Level'),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.speed, color: kRailwayBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
                const Divider(height: 20),
                Row(
                  children: [
                    _statItem('Attendance Rate', '$attendanceRate%', kSuccessGreen),
                    _statItem('Avg Rating', '$avgRating/5', Colors.amber),
                    _statItem('Open Complaints', '$openComplaints', kErrorRed),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.cleaning_services, color: Colors.teal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Cleaning Tasks', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
                const Divider(height: 20),
                Row(
                  children: [
                    _statItem('Total', totalTasks, kRailwayBlue),
                    _statItem('Pending', pendingTasks, kWarningOrange),
                    _statItem('In Progress', inProgressTasks, Colors.teal),
                    _statItem('Done', approvedTasks, kSuccessGreen),
                  ],
                ),
                if (rejectedTasks != '0') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      Text('Rejected Tasks: $rejectedTasks', style: const TextStyle(color: kErrorRed, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.analytics, color: Colors.purple, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Operational Metrics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
                const Divider(height: 20),
                _metricRow(Icons.build_circle, 'Machines In Maintenance', '${machines['inMaintenance'] ?? 0} / ${machines['total'] ?? 0}'),
                _metricRow(Icons.task_alt, 'Daily Activities Completed', '${activities['completed'] ?? 0} / ${activities['total'] ?? 0}'),
                _metricRow(Icons.receipt_long, 'Billing Readiness Count', '${_dashboardData!['billingReadiness']?['ready'] ?? 0}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (platformsList.isNotEmpty) ...[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.view_carousel, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Platforms List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(height: 20),
                  ...platformsList.map((p) => ListTile(
                        leading: const Icon(Icons.train, color: kRailwayBlue),
                        title: Text(p['platformNumber'] != null && p['platformNumber'].toString().isNotEmpty ? 'Platform ${p['platformNumber']}' : (p['platformName'] ?? '')),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                        onTap: () {
                          setState(() {
                            _selectedPlatformId = p['platformId'];
                            _isLoading = true;
                          });
                          _loadDashboard();
                        },
                      )),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _dashboardData = null;
                _selectedPlatformId = null;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Change Station / Platform'),
            style: TextButton.styleFrom(foregroundColor: kRailwayBlue),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPlatformDashboard() {
    final cleaning = _dashboardData!['cleaning'] ?? {};
    final areasList = _dashboardData!['areas'] as List<dynamic>? ?? [];
    final areaCount = _dashboardData!['areaCount'] ?? 0;
    final runCount = _dashboardData!['runCount'] ?? 0;

    final totalTasks = (cleaning['total'] ?? 0).toString();
    final approvedTasks = (cleaning['approved'] ?? 0).toString();
    final pendingTasks = (cleaning['pending'] ?? 0).toString();
    final inProgressTasks = (cleaning['inProgress'] ?? 0).toString();
    final rejectedTasks = (cleaning['rejected'] ?? 0).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLevelBadge('Platform Level'),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.speed, color: kRailwayBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Platform Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
                const Divider(height: 20),
                Row(
                  children: [
                    _statItem('Total Areas', '$areaCount', kRailwayBlue),
                    _statItem('Runs Today', '$runCount', kSuccessGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.cleaning_services, color: Colors.teal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Cleaning Tasks', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
                const Divider(height: 20),
                Row(
                  children: [
                    _statItem('Total', totalTasks, kRailwayBlue),
                    _statItem('Pending', pendingTasks, kWarningOrange),
                    _statItem('In Progress', inProgressTasks, Colors.teal),
                    _statItem('Done', approvedTasks, kSuccessGreen),
                  ],
                ),
                if (rejectedTasks != '0') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      Text('Rejected Tasks: $rejectedTasks', style: const TextStyle(color: kErrorRed, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (areasList.isNotEmpty) ...[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.area_chart, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Areas on this Platform', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(height: 20),
                  ...areasList.map((a) => ListTile(
                        leading: const Icon(Icons.layers, color: Colors.teal),
                        title: Text(a['areaName'] ?? ''),
                        subtitle: Text('Frequency: ${a['cleaningFrequency'] ?? 'daily'} | Shift: ${a['defaultShift'] ?? 'morning'}'),
                      )),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _dashboardData = null;
                _selectedPlatformId = null;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Change Station / Platform'),
            style: TextButton.styleFrom(foregroundColor: kRailwayBlue),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildLevelBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kRailwayBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kRailwayBlue.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user, color: kRailwayBlue, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildSelectionUI() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dashboard_customize, color: kRailwayBlue, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Select Station & Platform',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please select a station and platform to view performance metrics.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const Divider(height: 32),
                if (widget.stationId == null) ...[
                  const Text('Station *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedStationId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.train, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: _stations.map((s) => DropdownMenuItem(
                      value: s.uid ?? s.stationCode,
                      child: Text('${s.stationCode} - ${s.stationName}'),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedStationId = v;
                          _selectedPlatformId = null;
                        });
                        _loadPlatformsForStation(v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Platform (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: _selectedPlatformId,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.view_carousel, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    suffixIcon: _loadingPlatforms
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Platforms (Station Level)'),
                    ),
                    ..._platformsOfStation.map((p) => DropdownMenuItem<String?>(
                      value: p.uid,
                      child: Text(p.displayName),
                    )),
                  ],
                  onChanged: _selectedStationId == null
                      ? null
                      : (v) {
                          setState(() {
                            _selectedPlatformId = v;
                          });
                        },
                  hint: Text(_selectedStationId == null ? 'Select station first' : 'All Platforms (Station Level)'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _selectedStationId == null
                        ? null
                        : () => _loadDashboard(),
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Performance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRailwayBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
