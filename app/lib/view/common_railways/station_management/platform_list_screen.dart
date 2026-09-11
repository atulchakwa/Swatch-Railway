import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/model/platform_model.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/platform_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'platform_form_screen.dart';

class PlatformListScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;

  const PlatformListScreen({super.key, this.stationId, this.stationName});

  @override
  State<PlatformListScreen> createState() => _PlatformListScreenState();
}

class _PlatformListScreenState extends State<PlatformListScreen> {
  List<Station> _stations = [];
  List<Platform> _platforms = [];
  Station? _selectedStation;
  bool _isLoadingStations = true;
  bool _isLoadingPlatforms = false;
  String? _error;

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
        if (role == 'Contractor Admin' || role == 'Contractor Master') {
          final userStationIds = <String>{};
          if (user?.stationId != null && user!.stationId!.isNotEmpty) {
            userStationIds.add(user.stationId!);
          }
          if (user?.stations != null && user!.stations.isNotEmpty) {
            userStationIds.addAll(user.stations);
          }
          if (userStationIds.isNotEmpty) {
            _stations = _stations.where((s) => s.uid != null && userStationIds.contains(s.uid)).toList();
          }
        }
      }
      if (_stations.isNotEmpty) {
        if (_selectedStation == null) {
          final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
          if (user?.stationId != null && user!.stationId!.isNotEmpty) {
            final match = _stations.where((s) => s.uid == user!.stationId).firstOrNull;
            if (match != null) _selectedStation = match;
          }
        }
        _selectedStation ??= _stations.first;
        _loadPlatforms();
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
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingPlatforms = false);
    }
  }

  Future<void> _openForm({Platform? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlatformFormScreen(
          stationId: _selectedStation!.uid ?? '',
          existingPlatform: existing,
        ),
      ),
    );
    if (result == true) _loadPlatforms();
  }

  Future<void> _deletePlatform(Platform p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Platform'),
        content: Text('Delete "${p.displayName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kErrorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PlatformRepository.delete(p.uid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Platform deleted'), backgroundColor: kSuccessGreen),
        );
        _loadPlatforms();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Platform List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        onChanged: (v) {
                          setState(() => _selectedStation = v);
                          _loadPlatforms();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isLoadingPlatforms
                          ? const Center(child: CircularProgressIndicator())
                          : _platforms.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.view_quilt_outlined, size: 80, color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      const Text('No platforms configured', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                      const SizedBox(height: 8),
                                      Text('Add platforms for ${_selectedStation?.stationName ?? "this station"}', style: TextStyle(color: Colors.grey[400])),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadPlatforms,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _platforms.length,
                                    itemBuilder: (context, index) {
                                      final p = _platforms[index];
                                      return Card(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        margin: const EdgeInsets.only(bottom: 10),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: kRailwayBlue.withOpacity(0.1),
                                            child: Text(p.platformNumber, style: TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold)),
                                          ),
                                          title: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (p.surfaceType != null) Text('Surface: ${p.surfaceType}'),
                                              if (p.length != null && p.width != null)
                                                Text('${p.length!.toStringAsFixed(1)}m x ${p.width!.toStringAsFixed(1)}m'),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle, color: p.status == 'active' ? kSuccessGreen : Colors.grey, size: 20),
                                              IconButton(
                                                icon: const Icon(Icons.edit, size: 18, color: kRailwayBlue),
                                                onPressed: () => _openForm(existing: p),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 18, color: kErrorRed),
                                                onPressed: () => _deletePlatform(p),
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
