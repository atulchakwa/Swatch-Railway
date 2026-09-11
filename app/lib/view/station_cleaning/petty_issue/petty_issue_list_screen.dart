import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/petty_issue_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'petty_issue_form_screen.dart';

class PettyIssueListScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const PettyIssueListScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<PettyIssueListScreen> createState() => _PettyIssueListScreenState();
}

class _PettyIssueListScreenState extends State<PettyIssueListScreen> {
  bool _isLoading = false;
  String _selectedStatus = 'all';
  List<PettyIssue> _issues = [];
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final query = <String, String>{'stationId': widget.stationId};
      if (_selectedStatus != 'all') query['status'] = _selectedStatus;
      _issues = await PettyIssueRepository.list(query);
      _summary = await PettyIssueRepository.summary(widget.stationId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'REPORTED': return kWarningOrange;
      case 'ASSIGNED': return Colors.blue;
      case 'IN_PROGRESS': return Colors.orange;
      case 'RESOLVED': return kSuccessGreen;
      case 'CLOSED': return Colors.grey;
      case 'REJECTED': return kErrorRed;
      default: return Colors.grey;
    }
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return kErrorRed;
      case 'high': return Colors.orange;
      case 'medium': return kWarningOrange;
      case 'low': return Colors.grey;
      default: return Colors.grey;
    }
  }

  bool _canManage() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return false;
    final r = (user.role ?? '').toUpperCase().replaceAll(' ', '_');
    return ['SUPER_ADMIN', 'ADMIN', 'COMPANY_MASTER', 'RAILWAY_ADMIN', 'CONTRACTOR_ADMIN'].contains(r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Petty Issues - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          if (_summary != null)
            Card(
              margin: const EdgeInsets.all(12).copyWith(bottom: 0),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBadge('Total', '${_summary!['total'] ?? 0}', Colors.grey),
                    _statBadge('Open', '${(_summary!['byStatus'] as Map?)?['REPORTED'] ?? 0}', kWarningOrange),
                    _statBadge('Resolved', '${(_summary!['byStatus'] as Map?)?['RESOLVED'] ?? 0}', kSuccessGreen),
                  ],
                ),
              ),
            ),
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'REPORTED', child: Text('Reported')),
                  DropdownMenuItem(value: 'ASSIGNED', child: Text('Assigned')),
                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                  DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                  DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                  DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                ],
                onChanged: (v) { if (v != null) { setState(() => _selectedStatus = v); _load(); } },
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _issues.isEmpty
                    ? const Center(child: Text('No petty issues found'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _issues.length,
                          itemBuilder: (context, idx) {
                            final i = _issues[idx];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                title: Text(i.category.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(i.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _severityColor(i.severity).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: _severityColor(i.severity))), child: Text(i.severity.toUpperCase(), style: TextStyle(color: _severityColor(i.severity), fontSize: 9, fontWeight: FontWeight.bold))),
                                        const SizedBox(width: 6),
                                        Text(i.reportedByName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _statusColor(i.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: _statusColor(i.status))), child: Text(i.status, style: TextStyle(color: _statusColor(i.status), fontSize: 10, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => PettyIssueFormScreen(issue: i, stationId: widget.stationId, stationName: widget.stationName))).then((_) => _load());
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _canManage()
          ? FloatingActionButton(
              backgroundColor: kWarningOrange,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PettyIssueFormScreen(stationId: widget.stationId, stationName: widget.stationName))).then((_) => _load());
              },
            )
          : null,
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
