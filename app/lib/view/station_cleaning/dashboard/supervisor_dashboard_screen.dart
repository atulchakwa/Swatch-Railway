import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:crm_train/providers/station_cleaning_provider.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/view/station_cleaning/supervisor_task_screen.dart';
import 'package:crm_train/view/station_cleaning/workers/worker_management_screen.dart';
import 'package:crm_train/view/station_cleaning/schedule/station_schedule_screen.dart';
import 'package:crm_train/view/station_cleaning/reporting/report_list_screen.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String? platformId;
  const SupervisorDashboardScreen({super.key, required this.stationId, required this.stationName, this.platformId});

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  String? _supervisorId;
  String? _supervisorName;
  Map<String, dynamic>? _dashboardData;
  DateTime? _selectedDate;
  String _stationName = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _supervisorId = prefs.getString('userId');
      _supervisorName = prefs.getString('userName') ?? '';
      if (widget.stationName.isNotEmpty) {
        _stationName = widget.stationName;
      } else if (widget.stationId.isNotEmpty) {
        try {
          final stations = await ApiService.getStations(active: true);
          final match = stations.where((s) => s.uid == widget.stationId).firstOrNull;
          if (match != null) _stationName = match.stationName;
        } catch (_) {}
      }
      await _fetchDashboard();
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _fetchDashboard() async {
    if (_supervisorId == null) return;
    final date = _selectedDate?.toIso8601String().split('T')[0];
    final provider = context.read<StationCleaningProvider>();
    final data = await provider.fetchSupervisorDashboard(_supervisorId!, date: date);
    if (mounted) setState(() { _dashboardData = data; _isLoading = false; _error = data == null ? 'Failed to load' : null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_stationName.isNotEmpty ? _stationName : 'Supervisor Dashboard',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickDate),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _init),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12), Text(_error!), const SizedBox(height: 8),
                  ElevatedButton(onPressed: _fetchDashboard, child: const Text('Retry')),
                ]))
              : RefreshIndicator(onRefresh: _fetchDashboard, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    final d = _dashboardData;
    final total = d?['totalTasks'] ?? 0;
    final completed = d?['completedTasks'] ?? 0;
    final inProgress = d?['inProgressTasks'] ?? 0;
    final pending = d?['pendingTasks'] ?? 0;
    final approved = d?['approvedTasks'] ?? 0;
    final rejected = d?['rejectedTasks'] ?? 0;
    final overdue = d?['overdueTasks'] ?? 0;
    final done = completed + approved;
    final fraction = total > 0 ? done / total : 0.0;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildShiftCard(),
        const SizedBox(height: 12),
        _buildProgressSection(total, done, fraction),
        const SizedBox(height: 12),
        _buildTaskSummaryRow(pending, inProgress, done, overdue, rejected),
        const SizedBox(height: 12),
        _buildWorkerCount(d),
        const SizedBox(height: 12),
        _buildQuickActions(),
        const SizedBox(height: 12),
        if (d != null && d['areaPerformance'] != null)
          _buildAreaPerformance(d['areaPerformance'] as List),
      ],
    );
  }

  Widget _buildShiftCard() {
    final today = DateFormat('EEE, dd MMM yyyy').format(_selectedDate ?? DateTime.now());
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: [kRailwayBlue, Colors.lightBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(today, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Station Cleaning', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_stationName.isNotEmpty ? _stationName : 'Assigned Station',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            Column(
              children: [
                Icon(Icons.cleaning_services, color: Colors.white.withOpacity(0.3), size: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(int total, int done, double fraction) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shift Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('$done/$total tasks',
                    style: TextStyle(color: fraction >= 0.8 ? kSuccessGreen : kWarningOrange, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(fraction >= 0.8 ? kSuccessGreen : kWarningOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSummaryRow(int pending, int inProgress, int completed, int missed, int rejected) {
    return Row(
      children: [
        _statCard('Pending', pending, kWarningOrange, Icons.schedule),
        const SizedBox(width: 6),
        _statCard('Active', inProgress, kRailwayBlue, Icons.cleaning_services),
        const SizedBox(width: 6),
        _statCard('Done', completed, kSuccessGreen, Icons.check_circle),
        const SizedBox(width: 6),
        _statCard('Overdue', missed, kErrorRed, Icons.cancel),
      ],
    );
  }

  Widget _statCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerCount(Map<String, dynamic>? d) {
    final workerPerformance = d?['workerPerformance'] as List? ?? [];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kRailwayBlue.withOpacity(0.1),
          child: Icon(Icons.people, color: kRailwayBlue),
        ),
        title: Text('${workerPerformance.length} Workers', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Registered under your supervision'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerManagementScreen(
          stationId: widget.stationId, stationName: _stationName,
        ))),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _actionChip(Icons.assignment, 'My Tasks', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupervisorTaskScreen(
                  stationId: widget.stationId, stationName: _stationName,
                  supervisorId: _supervisorId ?? '', supervisorName: _supervisorName ?? '',
                ))))),
                const SizedBox(width: 8),
                Expanded(child: _actionChip(Icons.people, 'Workers', () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerManagementScreen(
                  stationId: widget.stationId, stationName: _stationName,
                ))))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _actionChip(Icons.calendar_today, 'Schedule', () => Navigator.push(context, MaterialPageRoute(builder: (_) => StationScheduleScreen(
                  stationId: widget.stationId, stationName: _stationName,
                ))))),
                const SizedBox(width: 8),
                Expanded(child: _actionChip(Icons.bar_chart, 'Reports', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportListScreen(
                  stationId: widget.stationId, stationName: _stationName,
                ))))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: kRailwayBlue, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaPerformance(List areas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Area Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...areas.map((a) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${a['total'] ?? 0}')),
            title: Text(a['areaName'] ?? 'Unknown Area'),
            subtitle: LinearProgressIndicator(
              value: (a['total'] ?? 0) > 0 ? (a['completed'] ?? 0) / a['total'] : 0,
              backgroundColor: Colors.grey.withOpacity(0.5),
            ),
            trailing: Text('${a['score'] ?? 0}', style: TextStyle(color: _scoreColor(a['score']), fontWeight: FontWeight.bold)),
          ),
        )),
      ],
    );
  }

  Color _scoreColor(dynamic score) {
    final s = (score is int ? score : int.tryParse(score.toString())) ?? 0;
    return s >= 80 ? kSuccessGreen : s >= 60 ? kWarningOrange : kErrorRed;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) { setState(() => _selectedDate = picked); _fetchDashboard(); }
  }
}
