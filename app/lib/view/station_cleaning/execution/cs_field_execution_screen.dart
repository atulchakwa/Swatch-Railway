import 'package:crm_train/model/station_run_model.dart';
import 'package:crm_train/repositories/station_run_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

import 'package:crm_train/view/common_workers/worker_station_cleaning_screen.dart';
import 'package:crm_train/view/station_cleaning/supervisor_log/supervisor_daily_log_screen.dart';

class CSFieldExecutionScreen extends StatefulWidget {
  const CSFieldExecutionScreen({super.key});

  @override
  State<CSFieldExecutionScreen> createState() => _CSFieldExecutionScreenState();
}

class _CSFieldExecutionScreenState extends State<CSFieldExecutionScreen> {
  List<StationCleaningRunModel> _runs = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMyRuns();
  }

  Future<void> _loadMyRuns() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final runs = await StationRunRepository.getMyStationRuns();
      if (mounted) {
        setState(() {
          _runs = runs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Scheduled Runs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMyRuns),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupervisorDailyLogScreen()),
          );
        },
        backgroundColor: kRailwayBlue,
        icon: const Icon(Icons.edit_document, color: Colors.white),
        label: const Text('Daily Log', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: kErrorRed)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMyRuns, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_runs.isEmpty) {
      return const Center(child: Text('No runs assigned to you.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _runs.length,
      itemBuilder: (context, index) {
        final run = _runs[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text('${run.stationName} - ${run.shift.toUpperCase()}'),
            subtitle: Text('Date: ${run.date} | Status: ${run.status}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerStationRunDetailScreen(
                    run: run,
                    onRefresh: _loadMyRuns,
                  ),
                ),
              ).then((_) => _loadMyRuns());
            },
          ),
        );
      },
    );
  }
}
