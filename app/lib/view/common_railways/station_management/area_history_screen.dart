import 'package:flutter/material.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/utills/app_colors.dart';

class AreaHistoryScreen extends StatefulWidget {
  final String? areaId;
  final String? areaName;
  final String? stationId;
  final String? stationName;
  const AreaHistoryScreen({super.key, this.areaId, this.areaName, this.stationId, this.stationName});

  @override
  State<AreaHistoryScreen> createState() => _AreaHistoryScreenState();
}

class _AreaHistoryScreenState extends State<AreaHistoryScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final path = widget.areaId != null
          ? '/api/station-reports/audit/user-activity'
          : '/api/station-reports/audit/inspection-history';
      final params = <String, String>{};
      if (widget.stationId != null) params['stationId'] = widget.stationId!;
      if (widget.areaId != null) params['userId'] = widget.areaId!;
      if (_filter != 'all') params['type'] = _filter;

      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: path,
        queryParams: params.isNotEmpty ? params : null,
        parser: (d) => d,
      );
      _events = (result['summary']?['records'] as List? ??
                result['summary']?['inspections'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _eventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'task': return Icons.task_alt;
      case 'checkin': case 'check_in': return Icons.login;
      case 'issue': return Icons.outbox;
      case 'approval': case 'approve': return Icons.thumb_up;
      case 'rejection': case 'reject': return Icons.thumb_down;
      case 'complaint': return Icons.report_problem;
      default: return Icons.circle;
    }
  }

  Color _eventColor(String type) {
    switch (type.toLowerCase()) {
      case 'task': return kRailwayBlue;
      case 'checkin': case 'check_in': return kSuccessGreen;
      case 'issue': return kWarningOrange;
      case 'approval': case 'approve': return Colors.teal;
      case 'rejection': case 'reject': return kErrorRed;
      case 'complaint': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.areaName != null ? 'History: ${widget.areaName}' : 'Area History',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (v) { setState(() => _filter = v); _loadHistory(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'task', child: Text('Tasks')),
              const PopupMenuItem(value: 'check_in', child: Text('Check-ins')),
              const PopupMenuItem(value: 'issue', child: Text('Issues')),
              const PopupMenuItem(value: 'approval', child: Text('Approvals')),
            ],
          ),
        ],
      ),
      body: _isLoading
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
                      ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
                    ],
                  ),
                )
              : _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No history available', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final e = _events[index];
                          final type = (e['type'] ?? 'task') as String;
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _eventColor(type).withOpacity(0.1),
                                child: Icon(_eventIcon(type), color: _eventColor(type), size: 20),
                              ),
                              title: Text(e['title'] ?? e['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (e['details'] != null) Text(e['details'], style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(e['timestamp'] ?? e['createdAt'] ?? '', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                                ],
                              ),
                              trailing: e['status'] != null
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _eventColor(type).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(e['status'], style: TextStyle(fontSize: 10, color: _eventColor(type), fontWeight: FontWeight.bold)),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
