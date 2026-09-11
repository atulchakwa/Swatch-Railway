import 'dart:convert';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_train/view/station_cleaning/worker/station_worker_dashboard.dart';

class WorkerDailyTasksScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  const WorkerDailyTasksScreen({super.key, required this.workerId, required this.workerName});

  @override
  State<WorkerDailyTasksScreen> createState() => _WorkerDailyTasksScreenState();
}

class _WorkerDailyTasksScreenState extends State<WorkerDailyTasksScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _runs = [];

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  Future<void> _loadRuns() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      // We assume the worker's contractor is fetched on the backend or we just fetch runs where they can participate
      // For now, let's just fetch all active runs for the current date. The backend should ideally filter by Contractor.
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      final res = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-runs',
        queryParams: {'date': today},
        parser: (data) => data,
      );

      // Depending on how backend returns the list
      final list = res['runs'] ?? res['data'] ?? [];
      
      if (mounted) {
        setState(() {
          _runs = List<Map<String, dynamic>>.from(list);
          // Filter out completed ones maybe, or show status
        });
      }
    } catch (e) {
      debugPrint('Error loading runs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _openRun(Map<String, dynamic> run) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationWorkerDashboard(run: run, workerId: widget.workerId, workerName: widget.workerName)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.workerName}\'s Station Runs', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _runs.isEmpty
              ? const Center(child: Text('No station runs assigned for today'))
              : RefreshIndicator(
                  onRefresh: _loadRuns,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _runs.length,
                    itemBuilder: (context, index) {
                      final run = _runs[index];
                      final stationName = run['stationName'] ?? 'Unknown Station';
                      final shift = run['shiftType'] ?? run['shift'] ?? 'Unknown Shift';
                      final status = run['status'] ?? 'pending';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: kRailwayBlue.withOpacity(0.1),
                            child: const Icon(Icons.cleaning_services, color: kRailwayBlue),
                          ),
                          title: Text('$stationName ($shift Shift)', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'completed' ? kSuccessGreen.withOpacity(0.1) : kWarningOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(status.toUpperCase(), style: TextStyle(
                                    color: status == 'completed' ? kSuccessGreen : kWarningOrange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  )),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _openRun(run),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
