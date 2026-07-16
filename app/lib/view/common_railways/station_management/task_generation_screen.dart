import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/repositories/obhs_repository.dart';
import 'package:crm_train/repositories/platform_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

class TaskGenerationScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;
  const TaskGenerationScreen({super.key, this.stationId, this.stationName});

  @override
  State<TaskGenerationScreen> createState() => _TaskGenerationScreenState();
}

class _TaskGenerationScreenState extends State<TaskGenerationScreen> {
  List<Station> _stations = [];
  List<StationArea> _areas = [];
  List<StationArea> _allStationAreas = [];
  List<String> _selectedAreaIds = [];
  Station? _selectedStation;
  bool _isLoadingStations = true;
  bool _isSubmitting = false;
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);
  String _shift = 'morning';
  String _frequency = 'daily';
  Map<String, dynamic>? _result;

  List<Map<String, dynamic>> _workers = [];
  String? _selectedWorkerId;
  bool _isLoadingWorkers = false;
  List<Map<String, dynamic>> _assignments = [];
  
  List<StationZone> _zones = [];
  List<String> _selectedZoneIds = [];
  bool _isLoadingZones = false;
  String _assignedPlatformName = '';
  Set<String> _existingTaskAreaIds = {};

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final role = user?.role ?? '';
      debugPrint('TaskGenerationScreen: User role is "$role", stationId: "${user?.stationId}", areaId: "${user?.areaId}"');
      _stations = await ApiService.getStations(active: true);
      if (widget.stationId != null) {
        _stations = _stations.where((s) => s.uid == widget.stationId).toList();
      } else if (role == 'Station Master' || role == 'Area Master' || role == 'Platform Master') {
        if (user?.stationId != null && user!.stationId!.isNotEmpty) {
          _stations = _stations.where((s) => s.uid == user.stationId).toList();
        }
      }
      debugPrint('TaskGenerationScreen: Found ${_stations.length} stations');
      if (_stations.isNotEmpty) {
        _selectedStation = _stations.first;
        _loadAreas();
        _loadWorkers();
      }
    } catch (e) {
      debugPrint('TaskGenerationScreen: Error loading stations: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _loadAreas() async {
    if (_selectedStation == null) return;
    try {
      final fetched = await ApiService.getStationAreas(_selectedStation!.uid ?? '');
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final role = user?.role ?? '';
      
      String platformName = '';
      final assignedPlatformId = user?.areaId;
      if (assignedPlatformId != null && assignedPlatformId.isNotEmpty) {
        try {
          final platformDoc = await PlatformRepository.getById(assignedPlatformId);
          platformName = platformDoc.displayName;
        } catch (_) {}
      }

      if (platformName.isEmpty && assignedPlatformId != null) {
        final platformArea = fetched.firstWhere((a) => a.uid == assignedPlatformId, orElse: () => StationArea(stationId: '', name: ''));
        if (platformArea.name.isNotEmpty) platformName = platformArea.name;
      }

      List<StationArea> filteredAreas = fetched;
      if (role == 'Area Master' || role == 'Platform Master') {
        if (assignedPlatformId != null && assignedPlatformId.isNotEmpty) {
          filteredAreas = fetched.where((a) => a.platformId == assignedPlatformId).toList();
        }
      }

      if (mounted) {
        setState(() {
          _assignedPlatformName = platformName;
        });
      }

      debugPrint('TaskGenerationScreen: Loaded ${fetched.length} areas, filtered down to ${filteredAreas.length} areas for role "$role"');

      final assignmentsResult = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/area-assignments',
        queryParams: {'stationId': _selectedStation!.uid ?? '', 'isActive': 'true'},
        parser: (d) => d,
      );
      final rawAssignments = (assignmentsResult['assignments'] as List? ?? []).map((a) => a as Map<String, dynamic>).toList();
      if (mounted) {
        setState(() {
          _allStationAreas = fetched;
          _areas = filteredAreas;
          _assignments = rawAssignments;
          // Pre-select the area automatically if it's role-restricted
          if (role == 'Area Master' || role == 'Platform Master') {
            _selectedAreaIds = filteredAreas.where((a) => a.uid != null).map((a) => a.uid!).toList();
          }
        });
        _loadZonesForSelectedAreas();
        _loadExistingTasks();
      }
    } catch (_) {}
  }

  Future<void> _loadExistingTasks() async {
    if (_selectedStation == null) return;
    try {
      final existingResult = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/tasks',
        queryParams: {
          'stationId': _selectedStation!.uid ?? '',
          'date': _selectedDate,
        },
        parser: (d) => d,
      );
      final List tasksList = existingResult['tasks'] as List? ?? [];
      final activeAreaIds = tasksList
          .where((t) => t['shift'] == _shift && t['workerId'] != null && t['workerId'].toString().trim().isNotEmpty)
          .map((t) => t['areaId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
      
      if (mounted) {
        setState(() {
          _existingTaskAreaIds = activeAreaIds;
          // Deselect any areas that now have active tasks
          _selectedAreaIds.removeWhere((id) => activeAreaIds.contains(id));
        });
      }
    } catch (_) {}
  }

  Future<void> _loadZonesForSelectedAreas() async {
    if (_selectedStation == null || _selectedAreaIds.isEmpty) {
      setState(() {
        _zones = [];
        _selectedZoneIds = [];
      });
      return;
    }
    setState(() => _isLoadingZones = true);
    try {
      final List<StationZone> allZones = [];
      for (final areaId in _selectedAreaIds) {
        final result = await ApiService.getStationZones(_selectedStation!.uid ?? '', areaId: areaId);
        allZones.addAll(result);
      }
      if (mounted) {
        setState(() {
          _zones = allZones;
          _selectedZoneIds = allZones.where((z) => z.uid != null).map((z) => z.uid!).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingZones = false);
    }
  }

  Future<void> _loadWorkers() async {
    if (_selectedStation == null) return;
    if (mounted) setState(() => _isLoadingWorkers = true);
    try {
      final workersList = await OBHSRepository.getRailwayWorkers();
      if (mounted) {
        setState(() {
          _workers = workersList.where((w) {
            final statusUpper = w.status.toUpperCase();
            return statusUpper == 'APPROVED' || statusUpper == 'ACTIVE' || statusUpper == 'VERIFIED';
          }).map((w) => {
            'uid': w.uid,
            'fullName': w.fullName,
            'role': w.role,
            'designation': w.designation,
          }).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingWorkers = false);
  }

  Future<void> _generateTasks() async {
    if (_selectedAreaIds.isEmpty || _selectedStation == null) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/tasks-v2/generate',
        body: {
          'stationId': _selectedStation!.uid,
          'areaIds': _selectedAreaIds,
          'zoneIds': _selectedZoneIds,
          'date': _selectedDate,
          'shift': _shift,
          'frequency': _frequency,
          if (_selectedWorkerId != null) 'workerId': _selectedWorkerId,
        },
        parser: (d) => d,
      );
      _result = result;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result['count'] ?? 0} tasks generated'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kErrorRed));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Generate Tasks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingStations
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Task Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                             DropdownButtonFormField<Station>(
                              value: _selectedStation,
                              decoration: const InputDecoration(
                                labelText: 'Station',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.train),
                                isDense: true,
                              ),
                              isExpanded: true,
                              items: _stations.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text('${s.stationCode} - ${s.stationName}', overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: _stations.length <= 1 || Provider.of<AuthProvider>(context, listen: false).currentUser?.role == 'Area Master' || Provider.of<AuthProvider>(context, listen: false).currentUser?.role == 'Platform Master' ? null : (v) {
                                setState(() {
                                  _selectedStation = v;
                                  _selectedWorkerId = null;
                                });
                                _loadAreas();
                                _loadWorkers();
                              },
                            ),
                          if (Provider.of<AuthProvider>(context, listen: false).currentUser?.role == 'Area Master' ||
                              Provider.of<AuthProvider>(context, listen: false).currentUser?.role == 'Platform Master') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: kRailwayBlue.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kRailwayBlue.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.view_quilt, color: kRailwayBlue, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _assignedPlatformName.isNotEmpty
                                          ? 'Platform: $_assignedPlatformName'
                                          : 'Loading platform...',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: kRailwayBlue, fontSize: 13),
                                    ),
                                  ),
                                  const Icon(Icons.lock_outline, color: kRailwayBlue, size: 14),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                            readOnly: true,
                            controller: TextEditingController(text: _selectedDate),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.parse(_selectedDate),
                                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked.toIso8601String().substring(0, 10);
                                  _result = null;
                                });
                                _loadExistingTasks();
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _shift,
                            decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder(), prefixIcon: Icon(Icons.schedule)),
                            items: ['morning', 'afternoon', 'evening', 'night'].map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _shift = v);
                                _loadExistingTasks();
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _frequency,
                            decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder(), prefixIcon: Icon(Icons.repeat)),
                            items: ['daily', 'weekly', 'monthly'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(),
                            onChanged: (v) { if (v != null) setState(() => _frequency = v); },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedWorkerId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Assign to specific worker (Optional)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.person),
                              suffixIcon: _isLoadingWorkers
                                  ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                    )
                                  : null,
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Use default assigned worker(s)')),
                              ..._workers.map((w) => DropdownMenuItem(
                                    value: w['uid'] as String,
                                    child: Text('${w['fullName'] ?? ''} (${w['designation'] ?? w['role'] ?? ''})'),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedWorkerId = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Areas (${_selectedAreaIds.length} selected)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          if (_areas.where((a) => !_existingTaskAreaIds.contains(a.uid)).isEmpty)
                            const Text('No areas remaining for this date & shift', style: TextStyle(color: Colors.grey))
                          else
                            Wrap(
                              spacing: 8, runSpacing: 4,
                              children: _areas.where((a) => !_existingTaskAreaIds.contains(a.uid)).map((a) {
                                final areaAssignments = _assignments.where((assign) => assign['areaId'] == a.uid).toList();
                                final workerLabel = areaAssignments.isEmpty
                                    ? '(No assigned worker)'
                                    : areaAssignments.map((assign) => '${assign['workerName']} (${assign['shift']})').join(', ');
                                final parentArea = _allStationAreas.where((sa) => sa.uid == a.platformId).firstOrNull;
                                final chipLabel = parentArea != null ? '${a.name} (${parentArea.name})' : a.name;
                                return FilterChip(
                                  label: Text('$chipLabel - $workerLabel', style: const TextStyle(fontSize: 12)),
                                  selected: _selectedAreaIds.contains(a.uid),
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) {
                                        _selectedAreaIds.add(a.uid!);
                                      } else {
                                        _selectedAreaIds.remove(a.uid);
                                      }
                                    });
                                    _loadZonesForSelectedAreas();
                                  },
                                  selectedColor: kRailwayBlue.withOpacity(0.2),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingZones)
                    const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()))
                  else if (_zones.isNotEmpty)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Sub-Areas / Zones (${_selectedZoneIds.length} selected)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8, runSpacing: 4,
                              children: _zones.map((z) {
                                return FilterChip(
                                  label: Text(z.name, style: const TextStyle(fontSize: 12)),
                                  selected: _selectedZoneIds.contains(z.uid),
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) { _selectedZoneIds.add(z.uid!); }
                                      else { _selectedZoneIds.remove(z.uid); }
                                    });
                                  },
                                  selectedColor: kRailwayBlue.withOpacity(0.2),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_result != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      color: kSuccessGreen.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: kSuccessGreen, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_result!['count'] ?? 0} tasks generated', style: const TextStyle(fontWeight: FontWeight.bold, color: kSuccessGreen)),
                                  Text('For ${_result!['date'] ?? _selectedDate} - ${_result!['shift'] ?? _shift}',
                                      style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting || _selectedAreaIds.isEmpty ? null : () async {
                          await _generateTasks();
                          _loadExistingTasks();
                        },
                        icon: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isSubmitting ? 'Generating...' : 'Generate Tasks (${_selectedAreaIds.length} areas)'),
                      style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
