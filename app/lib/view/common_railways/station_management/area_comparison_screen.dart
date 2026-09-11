import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

class AreaComparisonScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;
  const AreaComparisonScreen({super.key, this.stationId, this.stationName});

  @override
  State<AreaComparisonScreen> createState() => _AreaComparisonScreenState();
}

class _AreaComparisonScreenState extends State<AreaComparisonScreen> {
  List<Station> _stations = [];
  Station? _selectedStation;
  List<Map<String, dynamic>> _comparisonData = [];
  bool _isLoading = true;
  bool _isLoadingStations = true;
  String? _error;
  String _selectedMetric = 'score';
  String _month = '${DateTime.now().month}';
  String _year = '${DateTime.now().year}';

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
        _loadComparison();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _loadComparison() async {
    if (_selectedStation == null) return;
    setState(() => _isLoading = true);
    try {
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-reports/comparison',
        queryParams: {'division': _selectedStation!.division, 'month': _month, 'year': _year},
        parser: (d) => d,
      );
      _comparisonData = (result['areas'] as List? ?? []).map((a) => a as Map<String, dynamic>).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A': return kSuccessGreen;
      case 'B': return kRailwayBlue;
      case 'C': return kWarningOrange;
      case 'D': return kErrorRed;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Area Comparison', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  child: Column(
                    children: [
                      DropdownButtonFormField<Station>(
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
                          _loadComparison();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Month (1-12)', border: OutlineInputBorder(), isDense: true),
                              controller: TextEditingController(text: _month),
                              keyboardType: TextInputType.number,
                              onChanged: (v) { _month = v; _loadComparison(); },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), isDense: true),
                              controller: TextEditingController(text: _year),
                              keyboardType: TextInputType.number,
                              onChanged: (v) { _year = v; _loadComparison(); },
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedMetric,
                            items: [
                              const DropdownMenuItem(value: 'score', child: Text('Score')),
                              const DropdownMenuItem(value: 'completion', child: Text('Completion')),
                              const DropdownMenuItem(value: 'attendance', child: Text('Attendance')),
                            ],
                            onChanged: (v) { if (v != null) setState(() => _selectedMetric = v); },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
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
                                  ElevatedButton(onPressed: _loadComparison, child: const Text('Retry')),
                                ],
                              ),
                            )
                          : _comparisonData.isEmpty
                              ? const Center(child: Text('No comparison data available'))
                              : RefreshIndicator(
                                  onRefresh: _loadComparison,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _comparisonData.length,
                                    itemBuilder: (context, index) {
                                      final a = _comparisonData[index];
                                      final score = (a['score'] ?? 0).toDouble();
                                      final grade = a['grade'] ?? 'N/A';
                                      final completion = (a['completion'] ?? 0).toDouble();
                                      return Card(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        margin: const EdgeInsets.only(bottom: 10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(a['areaName'] ?? a['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: _gradeColor(grade).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text('Grade: $grade', style: TextStyle(color: _gradeColor(grade), fontWeight: FontWeight.bold, fontSize: 13)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  _compareItem('Score', score, kRailwayBlue),
                                                  _compareItem('Completion', completion, kSuccessGreen),
                                                  _compareItem('Tasks', '${a['totalTasks'] ?? 0}', Colors.teal),
                                                ],
                                              ),
                                              if (score > 0) ...[
                                                const SizedBox(height: 8),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: LinearProgressIndicator(
                                                    value: score / 100,
                                                    backgroundColor: kRailwayBlue.withOpacity(0.1),
                                                    valueColor: AlwaysStoppedAnimation(kRailwayBlue),
                                                    minHeight: 6,
                                                  ),
                                                ),
                                              ],
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
    );
  }

  Widget _compareItem(String label, dynamic value, Color color) {
    final v = (value is num) ? value.toStringAsFixed(1) : value.toString();
    return Expanded(
      child: Column(
        children: [
          Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ],
      ),
    );
  }
}
