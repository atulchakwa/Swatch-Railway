import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_services.dart';
import '../../../utills/app_colors.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _selectedAction;
  int _total = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _actionColors = {
    'PASSWORD_CHANGED': Colors.orange,
    'COMPLAINT_ASSIGNED': Colors.blue,
    'COMPLAINT_ESCALATED': Colors.red,
    'COMPLAINT_AUTO_ROUTED': Colors.teal,
    'APPROVED': Colors.green,
    'REJECTED': Colors.red,
    'CREATED': Colors.blueGrey,
    'SUBMITTED': Colors.indigo,
    'SCORED': Colors.purple,
    'LOCKED': Colors.brown,
    'INVOICE_GENERATED': Colors.amber,
    'GENERATED': Colors.grey,
  };

  static const _actionLabels = {
    'PASSWORD_CHANGED': 'Password Changed',
    'COMPLAINT_ASSIGNED': 'Complaint Assigned',
    'COMPLAINT_ESCALATED': 'Complaint Escalated',
    'COMPLAINT_AUTO_ROUTED': 'Complaint Auto Routed',
    'APPROVED': 'Approved',
    'REJECTED': 'Rejected',
    'CREATED': 'Created',
    'SUBMITTED': 'Submitted',
    'SCORED': 'Scored',
    'LOCKED': 'Bill Locked',
    'INVOICE_GENERATED': 'Invoice Generated',
    'GENERATED': 'Generated',
  };

  String _humanAction(String action) {
    for (final entry in _actionLabels.entries) {
      if (action == entry.key) return entry.value;
      if (action.contains(entry.key)) {
        return action.replaceFirst(entry.key, entry.value).replaceAll('_', ' ');
      }
    }
    return action.replaceAll('_', ' ');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _logs = await ApiService.getAuditLogs(action: _selectedAction, limit: 100);
      try { _stats = await ApiService.getAuditLogStats(); } catch (_) {}
      _total = _stats['total'] as int? ?? _logs.length;
    } catch (e) {
      //
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Color _colorForAction(String action) {
    return _actionColors.entries.firstWhere(
      (e) => action.contains(e.key),
      orElse: () => const MapEntry('', Colors.grey),
    ).value;
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return 'N/A';
    try {
      return DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(ts));
    } catch (_) {
      return '$ts';
    }
  }

  List<Map<String, dynamic>> _filteredLogs() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _logs;
    return _logs.where((log) {
      final haystack = [
        (log['action'] as String? ?? ''),
        _humanAction(log['action'] as String? ?? ''),
        (log['performedByName'] as String? ?? ''),
        (log['entity'] as String? ?? ''),
        (log['targetEntity'] as String? ?? ''),
        (log['details'] as String? ?? ''),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text('Audit Logs'),
        backgroundColor: kRailwayBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              _selectedAction = v;
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All Actions')),
              ..._actionColors.keys.map((a) => PopupMenuItem(value: a, child: Text(a))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('$_total total entries', style: const TextStyle(color: Colors.black54)),
                if (_selectedAction != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(_humanAction(_selectedAction!), style: const TextStyle(fontSize: 11)),
                    onDeleted: () { _selectedAction = null; _load(); },
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by action, user, or details',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('No audit logs found'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredLogs().length,
                          itemBuilder: (_, i) {
                            final log = _filteredLogs()[i];
                            final action = log['action'] as String? ?? 'UNKNOWN';
                            final humanAction = _humanAction(action);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _colorForAction(action).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.circle, size: 12, color: _colorForAction(action)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(humanAction, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _colorForAction(action))),
                                          const SizedBox(height: 4),
                                          Text(log['details'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                          const SizedBox(height: 4),
                                          Text('${log['performedByName'] ?? 'System'} • ${_formatTime(log['timestamp'])}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
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
    );
  }
}