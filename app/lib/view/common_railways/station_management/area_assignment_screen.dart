import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/area_cleaning_models.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

class AreaAssignmentScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;
  const AreaAssignmentScreen({super.key, this.stationId, this.stationName});

  @override
  State<AreaAssignmentScreen> createState() => _AreaAssignmentScreenState();
}

class _AreaAssignmentScreenState extends State<AreaAssignmentScreen> {
  List<Station> _stations = [];
  List<StationArea> _areas = [];
  List<AreaWorkerAssignment> _assignments = [];
  List<Map<String, dynamic>> _workers = [];
  Station? _selectedStation;
  StationArea? _selectedArea;
  String _selectedShift = 'morning';
  bool _isLoadingStations = true;
  bool _isLoadingAreas = false;
  bool _isLoadingAssignments = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      _stations = await ApiService.getStations(active: true);
      if (_stations.isNotEmpty) {
        final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
        if (user?.stationId != null && user!.stationId!.isNotEmpty) {
          final match = _stations.where((s) => s.uid == user!.stationId).firstOrNull;
          if (match != null) _selectedStation = match;
        }
        _selectedStation ??= _stations.first;
        _loadAreas();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _loadAreas() async {
    if (_selectedStation == null) return;
    setState(() => _isLoadingAreas = true);
    try {
      _areas = await ApiService.getStationAreas(_selectedStation!.uid ?? '');
      if (_areas.isNotEmpty) {
        _selectedArea = _areas.first;
        _loadAssignments();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
  }

  Future<void> _loadAssignments() async {
    if (_selectedArea?.uid == null) return;
    setState(() => _isLoadingAssignments = true);
    try {
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/area-assignments/area/${_selectedArea!.uid}',
        parser: (d) => d,
      );
      final raw = result['assignments'] as List? ?? [];
      _assignments = raw.map((a) => AreaWorkerAssignment.fromJson(a as Map<String, dynamic>)).toList();
      final rawWorkers = result['workers'] as List? ?? [];
      _workers = rawWorkers.map((w) => w as Map<String, dynamic>).toList();
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        // try loading from worker areas endpoint
      }
    } finally {
      if (mounted) setState(() => _isLoadingAssignments = false);
    }
  }

  Future<void> _assignWorker(Map<String, dynamic> worker) async {
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/area-assignments',
        body: {
          'areaId': _selectedArea!.uid,
          'workerId': worker['uid'],
          'workerName': worker['fullName'] ?? '',
          'shift': _selectedShift,
        },
        parser: (d) => d,
      );
      _loadAssignments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker assigned'), backgroundColor: kSuccessGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  Future<void> _removeAssignment(AreaWorkerAssignment a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: Text('Remove ${a.workerName} from this area?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kErrorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || a.uid == null) return;
    try {
      await BaseRepository.apiCall(
        method: 'DELETE',
        path: '/api/area-assignments/${a.uid}',
        parser: (d) => d,
      );
      _loadAssignments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kErrorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Area Assignments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingStations
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: DropdownButtonFormField<Station>(
                    value: _selectedStation,
                    decoration: const InputDecoration(
                      labelText: 'Station',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.train),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _stations.map((s) => DropdownMenuItem(value: s, child: Text('${s.stationCode} - ${s.stationName}'))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedStation = v);
                      _loadAreas();
                    },
                  ),
                ),
                if (_areas.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: Colors.white,
                    child: DropdownButtonFormField<StationArea>(
                      value: _selectedArea,
                      decoration: const InputDecoration(
                        labelText: 'Area',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.map),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _areas.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedArea = v);
                        _loadAssignments();
                      },
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Text('Shift: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'morning', label: Text('Morning')),
                          ButtonSegment(value: 'evening', label: Text('Evening')),
                          ButtonSegment(value: 'night', label: Text('Night')),
                        ],
                        selected: {_selectedShift},
                        onSelectionChanged: (v) => setState(() => _selectedShift = v.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoadingAssignments
                      ? const Center(child: CircularProgressIndicator())
                      : _assignments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  const Text('No workers assigned', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Text('Assign workers to ${_selectedArea?.name ?? "this area"}', style: TextStyle(color: Colors.grey[400])),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadAssignments,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _assignments.length,
                                itemBuilder: (context, index) {
                                  final a = _assignments[index];
                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: kRailwayBlue.withOpacity(0.1),
                                        child: Text(a.workerName.isNotEmpty ? a.workerName[0].toUpperCase() : '?',
                                            style: TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold)),
                                      ),
                                      title: Text(a.workerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Row(
                                        children: [
                                          _chip(a.shift, Colors.teal),
                                          const SizedBox(width: 6),
                                          if (a.isPrimary) _chip('Primary', kRailwayBlue),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: kErrorRed),
                                        onPressed: () => _removeAssignment(a),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
      floatingActionButton: _selectedArea != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final workers = await _fetchUnassignedWorkers();
                if (workers.isEmpty || !mounted) return;
                _showWorkerPicker(workers);
              },
              backgroundColor: kRailwayBlue,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Assign Worker', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUnassignedWorkers() async {
    try {
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/area-assignments',
        queryParams: {'areaId': _selectedArea!.uid ?? ''},
        parser: (d) => d,
      );
      final allWorkers = result['workers'] as List? ?? [];
      return allWorkers.map((w) => w as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  void _showWorkerPicker(List<Map<String, dynamic>> workers) {
    final assignedIds = _assignments.map((a) => a.workerId).toSet();
    final available = workers.where((w) => !assignedIds.contains(w['uid'])).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Available Workers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kRailwayBlue)),
            ),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No unassigned workers available'),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (context, i) {
                    final w = available[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kRailwayBlue.withOpacity(0.1),
                        child: Text((w['fullName'] ?? '?').toString().substring(0, 1).toUpperCase(),
                            style: TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(w['fullName'] ?? ''),
                      subtitle: Text(w['designation'] ?? w['role'] ?? ''),
                      onTap: () {
                        Navigator.pop(ctx);
                        _assignWorker(w);
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}
