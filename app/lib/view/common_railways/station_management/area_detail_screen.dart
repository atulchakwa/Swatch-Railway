import 'package:flutter/material.dart';
import 'package:crm_train/model/area_cleaning_models.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'area_assignment_screen.dart';
import 'task_generation_screen.dart';
import 'area_performance_dashboard.dart';

class AreaDetailScreen extends StatefulWidget {
  final String areaId;
  final String areaName;
  final String? stationId;
  final String? stationName;

  const AreaDetailScreen({
    super.key,
    required this.areaId,
    required this.areaName,
    this.stationId,
    this.stationName,
  });

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  AreaDashboard? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/dashboard/area/${widget.areaId}',
        parser: (d) => d,
      );
      _dashboard = AreaDashboard.fromJson(result);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _infoRow(String label, String value, {Color? color, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color ?? kRailwayBlue),
            const SizedBox(width: 8),
          ],
          Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Expanded(
            child: Text(value, style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color ?? Colors.black87,
            )),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(double score) {
    final grade = score >= 90 ? 'A' : score >= 80 ? 'B' : score >= 70 ? 'C' : 'D';
    final color = score >= 90 ? kSuccessGreen : score >= 80 ? Colors.teal : score >= 70 ? kWarningOrange : kErrorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text('$score% ($grade)', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'active' || status == 'completed' || status == 'approved'
        ? kSuccessGreen
        : status == 'pending' || status == 'in_progress'
            ? kWarningOrange
            : kErrorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status == 'active' ? Icons.check_circle : Icons.schedule, size: 12, color: color),
          const SizedBox(width: 4),
          Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _dashboard;
    final cleaning = d?.cleaning ?? {};
    final score = (cleaning['score'] as num?)?.toDouble() ?? 0;
    final completed = cleaning['completed'] ?? 0;
    final total = cleaning['total'] ?? 0;
    final approved = cleaning['approved'] ?? 0;
    final rejected = cleaning['rejected'] ?? 0;
    final pending = cleaning['pending'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.areaName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
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
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: kRailwayBlue, size: 20),
                                    const SizedBox(width: 8),
                                    const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const Spacer(),
                                    _statusBadge(d?.cleaningFrequency ?? 'daily'),
                                  ],
                                ),
                                const Divider(),
                                _infoRow('Area Code', d?.areaCode ?? '--', icon: Icons.tag),
                                _infoRow('Station', widget.stationName ?? d?.stationId ?? '--', icon: Icons.train),
                if ((d?.platformId ?? '').isNotEmpty)
                  _infoRow('Platform', d!.platformId!, icon: Icons.view_quilt),
                                _infoRow('Frequency', d?.cleaningFrequency.replaceAll('_', ' ') ?? 'daily', icon: Icons.schedule),
                                _infoRow('Priority', '${'⭐' * (d?.priority ?? 3)} (${d?.priority ?? 3})', icon: Icons.flag),
                                _infoRow('Shift', d?.defaultShift ?? 'morning', icon: Icons.wb_twilight),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.analytics, color: kRailwayBlue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Today\'s Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _statBox('Score', score > 0 ? '$score%' : '--', _scoreBadge(score > 0 ? score : 100)),
                                    _statBox('Tasks', '$completed/$total', Container()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _miniStat('Approved', approved.toString(), kSuccessGreen),
                                    _miniStat('Rejected', rejected.toString(), kErrorRed),
                                    _miniStat('Pending', pending.toString(), kWarningOrange),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.people, color: kRailwayBlue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Assigned Workers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                const Divider(),
                                if ((d?.workerCount ?? 0) == 0)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('No workers assigned', style: TextStyle(color: Colors.grey)),
                                  )
                                else ...[
                                  Text('${d!.workerCount} worker(s)', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  ...d.workers.map((w) {
                                    final name = w is Map ? (w['workerName'] ?? w['fullName'] ?? 'Unknown') : '$w';
                                    final score = w is Map ? (w['score'] ?? '--') : '--';
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: kRailwayBlue.withOpacity(0.1),
                                        child: Text(name.toString()[0].toUpperCase(), style: TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      title: Text('$name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      trailing: score != '--' ? _scoreBadge((score is num) ? score.toDouble() : double.tryParse('$score') ?? 0) : null,
                                    );
                                  }),
                                ],
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.person_add, size: 18),
                                    label: const Text('Manage Assignments'),
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AreaAssignmentScreen())),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.task_alt, color: kRailwayBlue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Today\'s Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                const Divider(),
                                if ((d?.scheduledTasks ?? []).isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('No tasks scheduled', style: TextStyle(color: Colors.grey)),
                                  )
                                else
                                  ...d!.scheduledTasks.map((t) => Card(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(
                                        t.status == 'completed' || t.status == 'approved'
                                            ? Icons.check_circle : t.status == 'in_progress'
                                                ? Icons.play_circle : Icons.pending,
                                        color: t.status == 'completed' || t.status == 'approved'
                                            ? kSuccessGreen : t.status == 'in_progress'
                                                ? kRailwayBlue : Colors.grey,
                                      ),
                                      title: Text('${t.scheduledTime} - ${t.activityType ?? 'Cleaning'}', style: const TextStyle(fontSize: 13)),
                                      subtitle: Text(t.workerName ?? '', style: const TextStyle(fontSize: 11)),
                                      trailing: _statusBadge(t.status),
                                    ),
                                  )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.auto_awesome, size: 18),
                                label: const Text('Generate Tasks'),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskGenerationScreen(stationId: widget.stationId, stationName: widget.stationName))),
                                style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.speed, size: 18),
                                label: const Text('View Performance'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AreaPerformanceDashboard(areaId: widget.areaId, areaName: widget.areaName),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _statBox(String label, String value, Widget badge) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: kRailwayBlue)),
        const SizedBox(height: 4),
        badge,
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
