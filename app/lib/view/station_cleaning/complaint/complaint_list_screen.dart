import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/repositories/complaint_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'complaint_form_screen.dart';

class ComplaintListScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const ComplaintListScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  bool _isLoading = false;
  String _selectedStatus = 'all';
  String _selectedCategory = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _filtersVisible = false;
  List<Complaint> _complaints = [];

  static const _categories = ['all', 'Broken Fittings', 'Damaged Dustbin', 'Leakage', 'Blocked Drain', 'Damaged Tiles', 'Lighting Issue', 'Signage Issue', 'Damaged Fixture', 'Plumbing', 'Electrical', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final query = <String, String>{
        'stationId': widget.stationId,
      };
      if (_selectedStatus != 'all') query['status'] = _selectedStatus;
      if (_selectedCategory != 'all') query['category'] = _selectedCategory;
      if (_startDate != null) query['startDate'] = _startDate!.toIso8601String().split('T')[0];
      if (_endDate != null) query['endDate'] = _endDate!.toIso8601String().split('T')[0];
      final list = await ComplaintRepository.list(query);
      setState(() => _complaints = list);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load complaints: $e'), backgroundColor: kErrorRed),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (ComplaintStatus.values.firstWhere((e) => e.name == status, orElse: () => ComplaintStatus.reported)) {
      case ComplaintStatus.reported:
        return kErrorRed;
      case ComplaintStatus.assigned:
        return kWarningOrange;
      case ComplaintStatus.inProgress:
        return Colors.blue;
      case ComplaintStatus.resolved:
        return Colors.teal;
      case ComplaintStatus.closed:
        return kSuccessGreen;
      case ComplaintStatus.reopened:
        return Colors.purple;
      case ComplaintStatus.rejected:
        return Colors.grey;
      case ComplaintStatus.escalated:
        return const Color(0xFFB71C1C);
      case ComplaintStatus.railwayVerified:
        return kSuccessGreen;
      case ComplaintStatus.resubmitted:
        return kWarningOrange;
    }
  }

  Future<void> _quickAction(String action, Complaint comp) async {
    try {
      switch (action) {
        case 'start':
          await ComplaintRepository.startProgress(comp.uid);
          break;
        case 'close':
          await ComplaintRepository.close(comp.uid);
          break;
        case 'assign':
          final idCtrl = TextEditingController();
          final id = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Assign To'),
              content: TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'Assignee ID', border: OutlineInputBorder())),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, idCtrl.text.trim()), child: const Text('Assign')),
              ],
            ),
          );
          if (id != null && id.isNotEmpty) await ComplaintRepository.assign(comp.uid, id);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complaint ${action}ed'), backgroundColor: kSuccessGreen),
        );
        _loadComplaints();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complaints - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_filtersVisible ? Icons.filter_alt_off : Icons.filter_alt),
            onPressed: () => setState(() => _filtersVisible = !_filtersVisible),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadComplaints),
        ],
      ),
      body: Column(
        children: [
          if (_filtersVisible)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'reported', child: Text('Reported', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'assigned', child: Text('Assigned', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'inProgress', child: Text('In Progress', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'resolved', child: Text('Resolved', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'closed', child: Text('Closed', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'reopened', child: Text('Reopened', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'rejected', child: Text('Rejected', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'escalated', child: Text('Escalated', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'railway_verified', child: Text('Railway Verified', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) { if (val != null) setState(() => _selectedStatus = val); },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c == 'all' ? 'All' : c, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) { if (val != null) setState(() => _selectedCategory = val); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)), firstDate: DateTime(2020), lastDate: DateTime.now());
                              if (picked != null) setState(() => _startDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              child: Text(_startDate != null ? _startDate!.toIso8601String().split('T')[0] : 'Select', style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                              if (picked != null) setState(() => _endDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              child: Text(_endDate != null ? _endDate!.toIso8601String().split('T')[0] : 'Select', style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _loadComplaints,
                          style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16)),
                          child: const Text('Apply'),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = 'all';
                              _selectedCategory = 'all';
                              _startDate = null;
                              _endDate = null;
                            });
                            _loadComplaints();
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'reported', child: Text('Reported')),
                  DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                  DropdownMenuItem(value: 'inProgress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  DropdownMenuItem(value: 'reopened', child: Text('Reopened')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(value: 'escalated', child: Text('Escalated')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedStatus = val);
                    _loadComplaints();
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _complaints.isEmpty
                    ? const Center(child: Text('No complaints found'))
                    : RefreshIndicator(
                        onRefresh: _loadComplaints,
                        child: ListView.builder(
                          itemCount: _complaints.length,
                          itemBuilder: (context, idx) {
                            final comp = _complaints[idx];
                            final statusEnum = ComplaintStatus.values.firstWhere(
                              (e) => e.name == comp.status,
                              orElse: () => ComplaintStatus.reported,
                            );
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: comp.slaBreached
                                  ? RoundedRectangleBorder(
                                      side: BorderSide(color: kErrorRed, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(comp.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(comp.description.length > 80
                                            ? '${comp.description.substring(0, 80)}...'
                                            : comp.description),
                                        if (comp.slaDeadline != null)
                                          Text('SLA: ${comp.slaDeadline}', style: TextStyle(
                                            color: comp.slaBreached ? kErrorRed : Colors.grey,
                                            fontSize: 11,
                                          )),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(comp.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: _statusColor(comp.status)),
                                      ),
                                      child: Text(
                                        statusEnum.name.toUpperCase(),
                                        style: TextStyle(color: _statusColor(comp.status), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ComplaintFormScreen(
                                            complaint: comp,
                                            stationId: widget.stationId,
                                            stationName: widget.stationName,
                                          ),
                                        ),
                                      ).then((_) => _loadComplaints());
                                    },
                                  ),
                                  if (comp.status == 'reported')
                                    ButtonBar(
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.person_add, size: 16),
                                          label: const Text('Assign', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _quickAction('assign', comp),
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.play_arrow, size: 16),
                                          label: const Text('Start', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _quickAction('start', comp),
                                        ),
                                      ],
                                    ),
                                  if (comp.status == 'resolved' || comp.status == 'railwayVerified')
                                    ButtonBar(
                                      children: [
                                        if (comp.status == 'resolved')
                                          TextButton.icon(
                                            icon: const Icon(Icons.check_circle, size: 16, color: kSuccessGreen),
                                            label: const Text('Close', style: TextStyle(fontSize: 12, color: kSuccessGreen)),
                                            onPressed: () => _quickAction('close', comp),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kRailwayBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplaintFormScreen(
                stationId: widget.stationId,
                stationName: widget.stationName,
              ),
            ),
          ).then((_) => _loadComplaints());
        },
      ),
    );
  }
}
