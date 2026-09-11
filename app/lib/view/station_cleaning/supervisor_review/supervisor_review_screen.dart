import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/helper/api_error_handler.dart';

class SupervisorReviewScreen extends StatefulWidget {
  final String? supervisorId;
  final String stationId;

  const SupervisorReviewScreen({
    super.key,
    this.supervisorId,
    required this.stationId,
  });

  @override
  State<SupervisorReviewScreen> createState() => _SupervisorReviewScreenState();
}

class _SupervisorReviewScreenState extends State<SupervisorReviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _completedTasks = [];
  List<Map<String, dynamic>> _resubmittedTasks = [];
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingReview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingReview() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('AUTH_ERROR');

      final uri = Uri.parse('${ApiService.baseUrl}/api/tasks-v2/pending-review')
          .replace(queryParameters: {
        if (widget.supervisorId != null) 'supervisorId': widget.supervisorId!,
        'stationId': widget.stationId,
      });

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final tasks = (body['tasks'] as List<dynamic>? ?? []);
        setState(() {
          _completedTasks = tasks.where((t) => t['status'] == 'completed').cast<Map<String, dynamic>>().toList();
          _resubmittedTasks = tasks.where((t) => t['status'] == 'resubmitted').cast<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      setState(() {
        _error = e.toString().contains('AUTH_ERROR') ? 'Session expired' : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _approveTask(String taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('AUTH_ERROR');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/tasks-v2/$taskId/approve'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task approved')));
        _loadPendingReview();
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectTask(String taskId) async {
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Task'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Rejection Reason', hintText: 'Required'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejection reason is required')));
                return;
              }
              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token');
                if (token == null) throw Exception('AUTH_ERROR');

                final response = await http.post(
                  Uri.parse('${ApiService.baseUrl}/api/tasks-v2/$taskId/reject'),
                  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                  body: jsonEncode({'reason': reasonCtrl.text.trim()}),
                ).timeout(const Duration(seconds: 30));

                if (response.statusCode == 200) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task rejected')));
                  _loadPendingReview();
                } else {
                  throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final areaName = task['areaName'] ?? '';
    final activityName = task['activityType'] ?? task['taskTypeName'] ?? 'Cleaning';
    final workerName = task['workerName'] ?? 'Unknown';
    final time = task['scheduledTime'] ?? '--:--';
    final status = task['status'] ?? '';
    final beforePhoto = task['beforePhoto'];
    final afterPhoto = task['afterPhoto'];
    final taskId = task['uid'] ?? task['id'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          status == 'resubmitted' ? Icons.replay : Icons.check_circle_outline,
          color: status == 'resubmitted' ? Colors.purple : Colors.green,
          size: 28,
        ),
        title: Text('$time - $activityName',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${areaName.isNotEmpty ? areaName : 'Area'} | Worker: $workerName | ${status.replaceAll('_', ' ')}'),
        children: [
          if (beforePhoto != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Before: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(beforePhoto, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          if (afterPhoto != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('After: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(afterPhoto, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          if (task['rejectionReason'] != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Prev. Rejection: ${task['rejectionReason']}',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _approveTask(taskId),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _rejectTask(taskId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Tasks'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Completed (${_completedTasks.length})'),
            Tab(text: 'Resubmitted (${_resubmittedTasks.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _completedTasks.isEmpty
                        ? const Center(child: Text('No completed tasks pending review'))
                        : RefreshIndicator(
                            onRefresh: _loadPendingReview,
                            child: ListView.builder(
                              itemCount: _completedTasks.length,
                              itemBuilder: (ctx, i) => _buildTaskCard(_completedTasks[i]),
                            ),
                          ),
                    _resubmittedTasks.isEmpty
                        ? const Center(child: Text('No resubmitted tasks'))
                        : RefreshIndicator(
                            onRefresh: _loadPendingReview,
                            child: ListView.builder(
                              itemCount: _resubmittedTasks.length,
                              itemBuilder: (ctx, i) => _buildTaskCard(_resubmittedTasks[i]),
                            ),
                          ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh),
        onPressed: _loadPendingReview,
      ),
    );
  }
}
