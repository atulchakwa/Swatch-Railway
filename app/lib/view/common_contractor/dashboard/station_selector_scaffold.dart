import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class StationSelectorScaffold extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String>? allowedStationIds;
  final String? initialStationId;
  final Widget Function(BuildContext context, String stationId, String stationName) builder;

  const StationSelectorScaffold({
    super.key,
    required this.title,
    this.icon = Icons.location_city,
    this.allowedStationIds,
    this.initialStationId,
    required this.builder,
  });

  @override
  State<StationSelectorScaffold> createState() => _StationSelectorScaffoldState();
}

class _StationSelectorScaffoldState extends State<StationSelectorScaffold> {
  List<Station> _stations = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var stations = await ApiService.getStations(active: true);
      final allowed = widget.allowedStationIds?.where((e) => e.isNotEmpty).toList();
      if (allowed != null && allowed.isNotEmpty) {
        stations = stations.where((s) => s.uid != null && allowed.contains(s.uid)).toList();
      }
      stations.sort((a, b) => a.stationName.compareTo(b.stationName));
      String? selected;
      if (widget.initialStationId != null && stations.any((s) => s.uid == widget.initialStationId)) {
        selected = widget.initialStationId;
      } else if (stations.isNotEmpty) {
        selected = stations.first.uid;
      }
      if (mounted) {
        setState(() {
          _stations = stations;
          _selectedId = selected;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String get _selectedName {
    final match = _stations.firstWhere((s) => s.uid == _selectedId, orElse: () => _stations.isNotEmpty ? _stations.first : Station(uid: '', stationCode: '', stationName: _selectedId ?? '', zone: '', division: ''));
    return match.stationName;
  }

  @override
  Widget build(BuildContext context) {
    final hasStations = _stations.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(widget.icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildStationBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
                            const SizedBox(height: 12),
                            Text(_error ?? 'Failed to load stations', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: () { setState(() { _loading = true; _error = null; }); _load(); }, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : !hasStations
                        ? const Center(child: Text('No stations assigned to your account'))
                        : KeyedSubtree(
                            key: ValueKey(_selectedId),
                            child: widget.builder(context, _selectedId ?? '', _selectedName),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationBar() {
    return Material(
      color: kRailwayBlue.withOpacity(0.08),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: kRailwayBlue, size: 18),
              const SizedBox(width: 6),
              const Text('Station:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kRailwayBlue)),
              const SizedBox(width: 8),
              Expanded(
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : _stations.isEmpty
                        ? const Text('None', style: TextStyle(color: Colors.grey))
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedId,
                              isExpanded: true,
                              isDense: true,
                              borderRadius: BorderRadius.circular(12),
                              items: _stations.map((s) => DropdownMenuItem<String>(
                                value: s.uid,
                                child: Text(s.stationName, style: const TextStyle(fontSize: 14, color: Colors.black87), overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (v) {
                                if (v != null && v != _selectedId) setState(() => _selectedId = v);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}