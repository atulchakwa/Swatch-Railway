import 'package:crm_train/model/station_models.dart';
import 'package:flutter/material.dart';

import '../../../services/api_services.dart';

class StationAssignmentField extends StatefulWidget {
  final List<String> selectedStationIds;
  final Function(List<String> selectedIds) onChanged;
  final List<String>? allowedStationIds;
  final String? division;

  const StationAssignmentField({
    super.key,
    required this.selectedStationIds,
    required this.onChanged,
    this.allowedStationIds,
    this.division,
  });

  @override
  State<StationAssignmentField> createState() => _StationAssignmentFieldState();
}

class _StationAssignmentFieldState extends State<StationAssignmentField> {
  List<Station> _allStations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final stations = await ApiService.getStations(
        division: widget.division,
        active: true,
      );
      setState(() {
        _allStations = stations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading stations: $e');
    }
  }

  List<Station> get _filteredStations {
    if (widget.allowedStationIds == null || widget.allowedStationIds!.isEmpty) {
      return _allStations;
    }
    return _allStations.where((s) => s.uid != null && widget.allowedStationIds!.contains(s.uid)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final stations = _filteredStations;
    if (stations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('No stations available', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assigned Stations *', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: stations.map((station) {
              final isSelected = widget.selectedStationIds.contains(station.uid);
              return CheckboxListTile(
                dense: true,
                title: Text(station.stationName),
                value: isSelected,
                onChanged: (val) {
                  final updated = List<String>.from(widget.selectedStationIds);
                  if (val == true) {
                    if (station.uid != null) updated.add(station.uid!);
                  } else {
                    updated.remove(station.uid);
                  }
                  widget.onChanged(updated);
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
