import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/model/platform_model.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/platform_repository.dart';
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
  List<StationArea> _allStationAreas = [];
  Station? _selectedStation;
  List<Platform> _platforms = [];
  Platform? _selectedPlatform;
  bool _isLoadingStations = true;
  bool _isLoadingPlatforms = false;
  bool _isLoadingAreas = false;
  String? _error;
  String _assignedPlatformName = '';

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      if (widget.stationId != null) {
        _stations = await ApiService.getStations(active: true);
        _stations = _stations.where((s) => s.uid == widget.stationId).toList();
        _selectedStation = _stations.isNotEmpty ? _stations.first : null;
      } else {
        final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '';
        final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
        _stations = await ApiService.getStations(active: true);
        if (role == 'Station Master' || role == 'Area Master' || role == 'Platform Master') {
          _stations = _stations.where((s) => s.uid == user?.stationId).toList();
        }
      }
      if (_stations.isNotEmpty) {
        _selectedStation ??= _stations.first;
        await _loadPlatforms();
        await _loadAreas();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _loadPlatforms() async {
    if (_selectedStation == null) return;
    setState(() => _isLoadingPlatforms = true);
    try {
      _platforms = await PlatformRepository.getByStation(_selectedStation!.uid ?? '');
    } catch (_) {
      // platforms may not exist yet
    } finally {
      if (mounted) setState(() => _isLoadingPlatforms = false);
    }
  }

  Future<void> _loadAreas() async {
    if (_selectedStation == null) return;
    setState(() => _isLoadingAreas = true);
    try {
      final fetched = await ApiService.getStationAreas(_selectedStation!.uid ?? _selectedStation!.stationCode);
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final role = user?.role ?? '';

      // user.areaId stores the assigned platform document ID for Area Master
      final assignedPlatformId = user?.areaId;

      // Find platform name
      String platformName = '';
      if (assignedPlatformId != null && assignedPlatformId.isNotEmpty) {
        try {
          final platformDoc = await PlatformRepository.getById(assignedPlatformId);
          platformName = platformDoc.displayName;
        } catch (_) {}
      }

      List<StationArea> displayAreas;
      if (role == 'Area Master' || role == 'Platform Master') {
        if (assignedPlatformId != null && assignedPlatformId.isNotEmpty) {
          // Only show areas that belong to this master's platform
          displayAreas = fetched.where((a) => a.platformId == assignedPlatformId).toList();
        } else {
          displayAreas = fetched;
        }
      } else {
        displayAreas = fetched;
      }

      if (mounted) {
        setState(() {
          _allStationAreas = fetched;
          _areas = displayAreas;
          _assignedPlatformName = platformName;
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
            platformId: Provider.of<AuthProvider>(context, listen: false).currentUser?.platformId ?? _selectedPlatform?.uid,
            platformName: _assignedPlatformName.isNotEmpty ? _assignedPlatformName : _selectedPlatform?.displayName,
            platforms: _platforms,
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
      await ApiService.deleteStationArea(area.uid!);
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
        title: const Text('Area Master', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      child: Builder(builder: (ctx) {
                        final isMaster = Provider.of<AuthProvider>(ctx, listen: false).currentUser?.role == 'Area Master' ||
                            Provider.of<AuthProvider>(ctx, listen: false).currentUser?.role == 'Platform Master';
                        return DropdownButtonFormField<Station>(
                          value: _selectedStation,
                          decoration: const InputDecoration(
                            labelText: 'Station',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.train),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _stations.map((s) => DropdownMenuItem(value: s, child: Text('${s.stationCode} - ${s.stationName}'))).toList(),
                          onChanged: isMaster ? null : (v) async {
                            setState(() => _selectedStation = v);
                            await _loadPlatforms();
                            _loadAreas();
                          },
                        );
                      }),
                    ),
                    if (Provider.of<AuthProvider>(context, listen: false).currentUser?.role == 'Area Master' ||
                        Provider.of<AuthProvider>(context, listen: false).currentUser?.role == 'Platform Master')
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: kRailwayBlue.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kRailwayBlue.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.view_quilt, color: kRailwayBlue, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              _assignedPlatformName.isNotEmpty
                                  ? 'Assigned Platform: $_assignedPlatformName'
                                  : 'Loading platform...',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kRailwayBlue),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.lock, color: kRailwayBlue, size: 14),
                          ],
                        ),
                      )
                    else if (_platforms.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        color: Colors.white,
                        child: DropdownButtonFormField<Platform>(
                          value: _selectedPlatform,
                          decoration: const InputDecoration(
                            labelText: 'Platform (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.view_quilt),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Platforms')),
                            ..._platforms.map((p) => DropdownMenuItem(value: p, child: Text(p.displayName))),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedPlatform = v);
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
                                      String? areaPlatformName;
                                      if (a.platformId != null) {
                                        final parentArea = _allStationAreas.where((sa) => sa.uid == a.platformId).firstOrNull;
                                        if (parentArea != null) {
                                          areaPlatformName = parentArea.name;
                                        }
                                        if (areaPlatformName == null && _platforms.isNotEmpty) {
                                          final p = _platforms.where((pl) => pl.uid == a.platformId).firstOrNull;
                                          areaPlatformName = p?.displayName;
                                        }
                                      }
                                      return Card(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: kRailwayBlue.withOpacity(0.1),
                                            child: Text('${a.order}', style: TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold)),
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                              if (areaPlatformName != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: kRailwayBlue.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: kRailwayBlue.withOpacity(0.3)),
                                                  ),
                                                  child: Text(
                                                    areaPlatformName,
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kRailwayBlue),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(a.description.isNotEmpty ? a.description : 'No description'),
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
