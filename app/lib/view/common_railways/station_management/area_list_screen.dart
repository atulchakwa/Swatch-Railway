import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'area_form_screen.dart';

class AreaListScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;

  const AreaListScreen({super.key, this.stationId, this.stationName});

  @override
  State<AreaListScreen> createState() => _AreaListScreenState();
}

class _AreaListScreenState extends State<AreaListScreen> {
  List<Station> _stations = [];
  List<StationArea> _areas = [];
  Station? _selectedStation;
  bool _isLoadingStations = true;
  bool _isLoadingAreas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoadingStations = true;
      _error = null;
    });
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final role = user?.role ?? '';
      final fetched = await ApiService.getStations(active: true);
      
      List<Station> allowed = fetched;
      if (widget.stationId != null) {
        allowed = fetched.where((s) => s.uid == widget.stationId).toList();
      } else if (role == 'Contractor Admin' || role == 'Contractor Master') {
        final userStationIds = <String>{};
        if (user?.stationId != null && user!.stationId!.isNotEmpty) {
          userStationIds.add(user.stationId!);
        }
        if (user?.stations != null && user!.stations.isNotEmpty) {
          userStationIds.addAll(user.stations);
        }
        if (userStationIds.isNotEmpty) {
          allowed = fetched.where((s) => s.uid != null && userStationIds.contains(s.uid)).toList();
        }
      }
      
      setState(() {
        _stations = allowed;
      });

      if (_stations.isNotEmpty) {
        if (_selectedStation == null && user?.stationId != null && user!.stationId!.isNotEmpty) {
          final match = _stations.where((s) => s.uid == user!.stationId).firstOrNull;
          if (match != null) _selectedStation = match;
        }
        _selectedStation ??= _stations.first;
        await _loadAreas();
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
      final result = await StationCleaningRepository.listAreas(_selectedStation!.uid ?? _selectedStation!.stationCode);
      final rawList = (result['areas'] as List<dynamic>?) ?? [];
      final fetched = rawList.map((a) => StationArea.fromJson(a is Map<String, dynamic> ? a : {})).toList();

      if (mounted) {
        setState(() {
          _areas = fetched;
        });
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AreaFormScreen(
            stationId: _selectedStation!.uid ?? _selectedStation!.stationCode,
            existingArea: existing,
          ),
      ),
    );
    if (result == true) _loadAreas();
  }

  Future<void> _deleteArea(StationArea area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Area'),
        content: Text('Delete "${area.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: kErrorRed), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await StationCleaningRepository.deleteArea(area.uid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Area deleted'), backgroundColor: kSuccessGreen));
        _loadAreas();
      }
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
        title: const Text('Area List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingStations
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
                      ElevatedButton(onPressed: _loadStations, child: const Text('Retry')),
                    ],
                  ),
                )
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
                        onChanged: (v) async {
                          setState(() {
                            _selectedStation = v;
                          });
                          _loadAreas();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isLoadingAreas
                          ? const Center(child: CircularProgressIndicator())
                          : _areas.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.map_outlined, size: 80, color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      const Text('No areas configured', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                      const SizedBox(height: 8),
                                      Text('Add areas for ${_selectedStation?.stationName ?? "this station"}', style: TextStyle(color: Colors.grey[400])),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadAreas,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _areas.length,
                                    itemBuilder: (context, index) {
                                      final a = _areas[index];
                                      return Card(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: kRailwayBlue.withOpacity(0.1),
                                            child: Text('${a.order}', style: TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold)),
                                          ),
                                          title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (a.mainArea != null && a.mainArea!.isNotEmpty)
                                                Text('Main: ${a.mainArea}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                              if (a.basicAreaSqFt != null && a.basicAreaSqFt! > 0)
                                                Text('Basic: ${a.basicAreaSqFt!.toStringAsFixed(a.basicAreaSqFt == a.basicAreaSqFt!.roundToDouble() ? 0 : 1)} sq.ft.'),
                                              if (a.frequencyType != null)
                                                Text('Freq: ${a.frequencyType} ${a.boqTimesPerPeriod ?? 1}x'),
                                              if (a.tenderedAreaPerDay != null && a.tenderedAreaPerDay! > 0)
                                                Text('Tendered/day: ${a.tenderedAreaPerDay!.toStringAsFixed(a.tenderedAreaPerDay == a.tenderedAreaPerDay!.roundToDouble() ? 0 : 1)} sq.ft.',
                                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                              if (a.description.isNotEmpty && a.mainArea == null)
                                                Text(a.description),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(a.active ? Icons.check_circle : Icons.cancel, color: a.active ? kSuccessGreen : Colors.grey, size: 20),
                                              IconButton(
                                                icon: const Icon(Icons.edit, size: 18, color: kRailwayBlue),
                                                onPressed: () => _openForm(existing: a.toJson()),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 18, color: kErrorRed),
                                                onPressed: () => _deleteArea(a),
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
                ),
      floatingActionButton: _selectedStation != null
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              backgroundColor: kRailwayBlue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
