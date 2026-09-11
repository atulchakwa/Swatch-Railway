import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

class BulkAssignmentScreen extends StatefulWidget {
  const BulkAssignmentScreen({super.key});

  @override
  State<BulkAssignmentScreen> createState() => _BulkAssignmentScreenState();
}

class _BulkAssignmentScreenState extends State<BulkAssignmentScreen> {
  List<Station> _stations = [];
  List<StationArea> _areas = [];
  List<Map<String, dynamic>> _workers = [];
  List<String> _selectedAreaIds = [];
  List<String> _selectedWorkerIds = [];
  Station? _selectedStation;
  bool _isLoadingStations = true;
  bool _isLoadingAreas = false;
  bool _isLoadingWorkers = false;
  bool _isSubmitting = false;
  String _shift = 'morning';
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
        _loadWorkers();
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
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);
    try {
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/users/workers',
        parser: (d) => d,
      );
      _workers = (result['workers'] as List? ?? []).map((w) => w as Map<String, dynamic>).toList();
    } catch (_) {
      _workers = [];
    } finally {
      if (mounted) setState(() => _isLoadingWorkers = false);
    }
  }

  Future<void> _bulkAssign() async {
    if (_selectedAreaIds.isEmpty || _selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select areas and workers'), backgroundColor: kWarningOrange),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/area-assignments/bulk',
        body: {
          'areaIds': _selectedAreaIds,
          'workerIds': _selectedWorkerIds,
          'shift': _shift,
        },
        parser: (d) => d,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk assignment completed'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
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
        title: const Text('Bulk Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Station', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Station>(
                            value: _selectedStation,
                            decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.train)),
                            items: _stations.map((s) => DropdownMenuItem(value: s, child: Text('${s.stationCode} - ${s.stationName}'))).toList(),
                            onChanged: (v) {
                              setState(() => _selectedStation = v);
                              _loadAreas();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Areas (${_selectedAreaIds.length} selected)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          if (_isLoadingAreas)
                            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                          else if (_areas.isEmpty)
                            const Text('No areas found', style: TextStyle(color: Colors.grey))
                          else
                            Wrap(
                              spacing: 8, runSpacing: 4,
                              children: _areas.map((a) => FilterChip(
                                label: Text(a.name, style: const TextStyle(fontSize: 12)),
                                selected: _selectedAreaIds.contains(a.uid),
                                onSelected: (v) {
                                  setState(() {
                                    if (v) { _selectedAreaIds.add(a.uid!); }
                                    else { _selectedAreaIds.remove(a.uid); }
                                  });
                                },
                                selectedColor: kRailwayBlue.withOpacity(0.2),
                              )).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Workers (${_selectedWorkerIds.length} selected)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          if (_isLoadingWorkers)
                            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                          else if (_workers.isEmpty)
                            const Text('No workers found', style: TextStyle(color: Colors.grey))
                          else
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                itemCount: _workers.length,
                                itemBuilder: (context, i) {
                                  final w = _workers[i];
                                  final isSelected = _selectedWorkerIds.contains(w['uid']);
                                  return CheckboxListTile(
                                    dense: true,
                                    title: Text(w['fullName'] ?? '', style: const TextStyle(fontSize: 14)),
                                    subtitle: Text(w['designation'] ?? '', style: const TextStyle(fontSize: 11)),
                                    value: isSelected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) { _selectedWorkerIds.add(w['uid']); }
                                        else { _selectedWorkerIds.remove(w['uid']); }
                                      });
                                    },
                                    activeColor: kRailwayBlue,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _shift,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: ['morning', 'afternoon', 'evening', 'night'].map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                            onChanged: (v) { if (v != null) setState(() => _shift = v); },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _bulkAssign,
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.group_add),
                      label: Text(_isSubmitting ? 'Assigning...' : 'Assign ${_selectedWorkerIds.length} Workers to ${_selectedAreaIds.length} Areas'),
                      style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
