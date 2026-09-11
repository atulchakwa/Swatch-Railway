import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/view/station_cleaning/station_cleaning_hub_screen.dart';

class StationCleaningMainScreen extends StatefulWidget {
  const StationCleaningMainScreen({super.key});

  @override
  State<StationCleaningMainScreen> createState() => _StationCleaningMainScreenState();
}

class _StationCleaningMainScreenState extends State<StationCleaningMainScreen> {
  List<Station> _stations = [];
  bool _stationsLoading = true;
  String? _selectedStationId;
  String _selectedStationName = '';

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _stationsLoading = true);
    try {
      final rawStations = await ApiService.getStations();
      final seenIds = <String>{};
      _stations = rawStations.where((s) {
        if (s.uid == null || s.uid!.isEmpty) return false;
        return seenIds.add(s.uid!);
      }).toList();

      final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '';
      final lockedRoles = {'CONTRACTOR_ADMIN', 'CONTRACTOR_SUPERVISOR'};
      if (lockedRoles.contains(role.toUpperCase())) {
        final userStationId = Provider.of<AuthProvider>(context, listen: false).currentUser?.stationId;
        if (userStationId != null && userStationId.isNotEmpty && _stations.any((s) => s.uid == userStationId)) {
          final station = _stations.firstWhere((s) => s.uid == userStationId);
          _selectedStationId = userStationId;
          _selectedStationName = station.stationName;
          if (mounted) {
            setState(() => _stationsLoading = false);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => StationCleaningHubScreen(stationId: userStationId, stationName: _selectedStationName),
            ));
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _stationsLoading = false);
  }

  void _openHub() {
    if (_selectedStationId == null || _selectedStationId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a station first'), backgroundColor: kWarningOrange),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => StationCleaningHubScreen(
        stationId: _selectedStationId!, stationName: _selectedStationName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context).currentUser?.role ?? '';
    final lockedRoles = {'CONTRACTOR_ADMIN', 'CONTRACTOR_SUPERVISOR'};
    final isLocked = lockedRoles.contains(role.toUpperCase());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Cleaning Module', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedStationId != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              tooltip: 'Open Hub',
              onPressed: _openHub,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Station', style: TextStyle(fontWeight: FontWeight.bold, color: kRailwayBlue, fontSize: 14)),
                  const SizedBox(height: 8),
                  _stationsLoading
                      ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : isLocked
                          ? InputDecorator(
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              child: Text(_selectedStationName.isNotEmpty ? _selectedStationName : 'No station assigned', style: const TextStyle(fontSize: 14)),
                            )
                          : DropdownButtonFormField<String>(
                              value: (_selectedStationId != null && _stations.any((s) => s.uid == _selectedStationId)) ? _selectedStationId : null,
                              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Choose a station...'),
                              items: _stations.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                                value: s.uid,
                                child: Text(s.stationName),
                              )).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedStationId = v;
                                  _selectedStationName = _stations.firstWhere((s) => s.uid == v, orElse: () => Station(stationCode: v ?? '', stationName: v ?? '', zone: '', division: '')).stationName;
                                });
                                if (v != null && v.isNotEmpty) {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => StationCleaningHubScreen(stationId: v, stationName: _selectedStationName),
                                  ));
                                }
                              },
                            ),
                ],
              ),
            ),
          ),
          if (_selectedStationId != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openHub,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Hub'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRailwayBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
