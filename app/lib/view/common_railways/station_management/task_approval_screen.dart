import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/utills/app_colors.dart';

class TaskApprovalScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;

  const TaskApprovalScreen({super.key, this.stationId, this.stationName});

  @override
  State<TaskApprovalScreen> createState() => _TaskApprovalScreenState();
}

class _TaskApprovalScreenState extends State<TaskApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingTasks = [];
  bool _tasksLoading = true;
  String? _tasksError;

  List<Map<String, dynamic>> _garbageRecords = [];
  bool _garbageLoading = true;
  String? _garbageError;

  List<Map<String, dynamic>> _pestRecords = [];
  bool _pestLoading = true;
  String? _pestError;

  String _userRole = '';
  String? _userStationId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final user = context.read<AuthProvider>().currentUser;
    _userRole = user?.role ?? '';
    _userStationId = widget.stationId ?? user?.stationId;
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadPendingTasks(),
      _loadGarbageRecords(),
      _loadPestRecords(),
    ]);
  }

  String get _effectiveStationId => _userStationId ?? '';

  Future<void> _loadPendingTasks() async {
    setState(() => _tasksLoading = true);
    try {
      final queryParams = <String, String>{};
      if (_effectiveStationId.isNotEmpty) {
        queryParams['stationId'] = _effectiveStationId;
      }
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/tasks-v2/pending-review',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
        parser: (d) => d,
      );
      final raw = result['tasks'] as List? ?? [];
      _pendingTasks = List<Map<String, dynamic>>.from(raw);
      _tasksError = null;
    } catch (e) {
      _tasksError = e.toString();
    } finally {
      if (mounted) setState(() => _tasksLoading = false);
    }
  }

  Future<void> _loadGarbageRecords() async {
    setState(() => _garbageLoading = true);
    try {
      final queryParams = <String, String>{'status': 'recorded'};
      if (_effectiveStationId.isNotEmpty) {
        queryParams['stationId'] = _effectiveStationId;
      }
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-garbage/records',
        queryParams: queryParams,
        parser: (d) => d,
      );
      final raw = result['data'] as List? ?? [];
      _garbageRecords = List<Map<String, dynamic>>.from(raw);
      _garbageError = null;
    } catch (e) {
      _garbageError = e.toString();
    } finally {
      if (mounted) setState(() => _garbageLoading = false);
    }
  }

  Future<void> _loadPestRecords() async {
    setState(() => _pestLoading = true);
    try {
      final queryParams = <String, String>{'status': 'pending'};
      if (_effectiveStationId.isNotEmpty) {
        queryParams['stationId'] = _effectiveStationId;
      }
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-pest-control/records',
        queryParams: queryParams,
        parser: (d) => d,
      );
      final raw = result['data'] as List? ?? [];
      _pestRecords = List<Map<String, dynamic>>.from(raw);
      _pestError = null;
    } catch (e) {
      _pestError = e.toString();
    } finally {
      if (mounted) setState(() => _pestLoading = false);
    }
  }

  // ─── Hierarchy ──────────────────────────────────────────────────────────

  List<String> _hierarchyParts(Map<String, dynamic> item) {
    final parts = <String>[];
    final role = _userRole;

    final showStation = !role.contains('Platform') && !role.contains('Area');
    final showPlatform = role.contains('Station') || (!role.contains('Platform') && !role.contains('Area'));

    if (showStation) {
      parts.add(item['stationName']?.toString() ?? 'Station');
    }
    if (showPlatform) {
      final pId = item['platformId']?.toString() ?? item['platformNumber']?.toString() ?? '';
      if (pId.isNotEmpty) parts.add('Platform $pId');
    }
    parts.add(item['areaName']?.toString() ?? 'Area');
    return parts;
  }

  // ─── Due / Overdue ──────────────────────────────────────────────────────

  bool _isOverdue(Map<String, dynamic> task) {
    final date = task['scheduledDate']?.toString() ?? '';
    final time = task['scheduledTime']?.toString() ?? '23:59';
    if (date.isEmpty) return false;
    final taskDt = DateTime.tryParse('${date}T${time}:00');
    if (taskDt == null) return false;
    return taskDt.isBefore(DateTime.now());
  }

  bool _isNearDue(Map<String, dynamic> task) {
    final date = task['scheduledDate']?.toString() ?? '';
    final time = task['scheduledTime']?.toString() ?? '23:59';
    if (date.isEmpty) return false;
    final taskDt = DateTime.tryParse('${date}T${time}:00');
    if (taskDt == null) return false;
    final diff = taskDt.difference(DateTime.now());
    return diff.inMinutes > 0 && diff.inMinutes <= 120;
  }

  // ─── Task Actions ───────────────────────────────────────────────────────

  Future<void> _approveTask(Map<String, dynamic> task) async {
    final notesCtrl = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Task'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Supervisor Notes (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, notesCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (notes == null) return;
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/tasks/${task['uid'] ?? task['id']}/approve',
        body: {'remarks': notes.isNotEmpty ? notes : 'Approved'},
        parser: (d) => d,
      );
      _loadPendingTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task approved'), backgroundColor: kSuccessGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  Future<void> _rejectTask(Map<String, dynamic> task) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Task'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason *',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorRed),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/tasks/${task['uid'] ?? task['id']}/reject',
        body: {'reason': reason},
        parser: (d) => d,
      );
      _loadPendingTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task rejected'), backgroundColor: kWarningOrange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  // ─── Garbage Actions ────────────────────────────────────────────────────

  Future<void> _approveGarbage(Map<String, dynamic> record) async {
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/station-garbage/${record['uid'] ?? record['id']}/approve',
        parser: (d) => d,
      );
      _loadGarbageRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Garbage record approved'), backgroundColor: kSuccessGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  Future<void> _rejectGarbage(Map<String, dynamic> record) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Garbage Record'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason *',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorRed),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/station-garbage/${record['uid'] ?? record['id']}/reject',
        body: {'reason': reason},
        parser: (d) => d,
      );
      _loadGarbageRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Garbage record rejected'), backgroundColor: kWarningOrange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  // ─── Pest Control Actions ───────────────────────────────────────────────

  Future<void> _reviewPestControl(Map<String, dynamic> record, String decision) async {
    final notesCtrl = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(decision == 'approved' ? 'Approve Pest Control' : 'Reject Pest Control'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Review Notes (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, notesCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: decision == 'approved' ? kSuccessGreen : kErrorRed,
            ),
            child: Text(
              decision == 'approved' ? 'Approve' : 'Reject',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (notes == null) return;
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/station-pest-control/${record['uid'] ?? record['id']}/review',
        body: {'status': decision, 'notes': notes},
        parser: (d) => d,
      );
      _loadPestRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pest control record ${decision}'),
            backgroundColor: decision == 'approved' ? kSuccessGreen : kWarningOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  // ─── Photo Helpers ──────────────────────────────────────────────────────

  @Deprecated('Use _extractBeforeAfterUrls instead')
  String _extractPhotoUrl(Map<String, dynamic> record) {
    return _extractBeforeAfterUrls(record).values.firstWhere((u) => u.isNotEmpty, orElse: () => '');
  }

  Map<String, String> _extractBeforeAfterUrls(Map<String, dynamic> record) {
    final before = record['beforePhoto']?.toString() ?? '';
    final after = record['afterPhoto']?.toString() ?? '';
    final evidence = record['evidence'];
    if (evidence is List && evidence.isNotEmpty) {
      final first = evidence.isNotEmpty && evidence[0] is String ? evidence[0].toString() : '';
      final last = evidence.length > 1 && evidence[1] is String ? evidence[1].toString() : '';
      return {
        'before': before.isNotEmpty ? before : first,
        'after': after.isNotEmpty ? after : last,
      };
    }
    return {'before': before, 'after': after};
  }



  // ─── Photo Preview ──────────────────────────────────────────────────────

  void _showPhotoPreview(String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: url.startsWith('http')
              ? Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white))))
              : Image.file(File(url), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white)))),
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Task Approval', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.cleaning_services, size: 18), text: 'Tasks'),
            Tab(icon: Icon(Icons.delete_outline, size: 18), text: 'Garbage'),
            Tab(icon: Icon(Icons.bug_report, size: 18), text: 'Pest Control'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildGarbageTab(),
          _buildPestControlTab(),
        ],
      ),
    );
  }

  // ─── Tasks Tab ──────────────────────────────────────────────────────────

  Widget _buildTasksTab() {
    if (_tasksLoading) return const Center(child: CircularProgressIndicator());
    if (_tasksError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: kErrorRed),
            const SizedBox(height: 12),
            Text(_tasksError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadPendingTasks, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_pendingTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No pending tasks', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPendingTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pendingTasks.length,
        itemBuilder: (_, i) => _buildTaskCard(_pendingTasks[i]),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final hierarchy = _hierarchyParts(task);
    final overdue = _isOverdue(task);
    final nearDue = _isNearDue(task);
    final status = task['status'] ?? '';
    final beforePhoto = task['beforePhoto']?.toString() ?? task['beforePhotoUrl']?.toString() ?? '';
    final afterPhoto = task['afterPhoto']?.toString() ?? task['afterPhotoUrl']?.toString() ?? '';
    final workerName = task['workerName']?.toString() ?? '';
    final date = task['scheduledDate']?.toString() ?? '';
    final time = task['scheduledTime']?.toString() ?? '';
    final rejectionReason = task['rejectionReason']?.toString() ?? '';

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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kRailwayBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cleaning_services, color: kRailwayBlue, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hierarchy.join(' > '),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (date.isNotEmpty)
                        Text('$date $time', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                    ],
                  ),
                ),
                if (overdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kErrorRed.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('OVERDUE', style: TextStyle(fontSize: 10, color: kErrorRed, fontWeight: FontWeight.bold)),
                  )
                else if (nearDue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kWarningOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('DUE SOON', style: TextStyle(fontSize: 10, color: kWarningOrange, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            if (workerName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: kTextSecondary),
                    const SizedBox(width: 4),
                    Text(workerName, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'resubmitted' ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'resubmitted' ? 'Resubmitted' : 'Completed',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: status == 'resubmitted' ? Colors.purple : Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            if (rejectionReason.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kErrorRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kErrorRed.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: kErrorRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Previous rejection: $rejectionReason',
                        style: const TextStyle(fontSize: 11, color: kErrorRed),
                      ),
                    ),
                  ],
                ),
              ),
            if (beforePhoto.isNotEmpty || afterPhoto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    if (beforePhoto.isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showPhotoPreview(beforePhoto),
                          child: Container(
                            height: 80,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: NetworkImage(beforePhoto),
                                fit: BoxFit.cover,
                                onError: (_, __) => const SizedBox(),
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('BEFORE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (afterPhoto.isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showPhotoPreview(afterPhoto),
                          child: Container(
                            height: 80,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: NetworkImage(afterPhoto),
                                fit: BoxFit.cover,
                                onError: (_, __) => const SizedBox(),
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('AFTER', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _rejectTask(task),
                  icon: const Icon(Icons.close, color: kErrorRed, size: 18),
                  label: const Text('Reject', style: TextStyle(color: kErrorRed)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approveTask(task),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Garbage Tab ────────────────────────────────────────────────────────

  Widget _buildGarbageTab() {
    if (_garbageLoading) return const Center(child: CircularProgressIndicator());
    if (_garbageError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: kErrorRed),
            const SizedBox(height: 12),
            Text(_garbageError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadGarbageRecords, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_garbageRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No pending garbage records', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGarbageRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _garbageRecords.length,
        itemBuilder: (_, i) => _buildGarbageCard(_garbageRecords[i]),
      ),
    );
  }

  Widget _buildGarbageCard(Map<String, dynamic> record) {
    final photos = _extractBeforeAfterUrls(record);
    final qty = record['quantityKg']?.toString() ?? '0';
    final type = record['garbageType']?.toString() ?? record['wasteType']?.toString() ?? 'General';
    final date = record['disposalDate']?.toString() ?? record['createdAt']?.toString() ?? '';

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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kSuccessGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: kSuccessGreen, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$type ($qty kg)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (date.isNotEmpty)
                        Text(date, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            if ((photos['before'] ?? '').isNotEmpty || (photos['after'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    if ((photos['before'] ?? '').isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showPhotoPreview(photos['before']!),
                          child: Container(
                            height: 80,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: NetworkImage(photos['before']!),
                                fit: BoxFit.cover,
                                onError: (_, __) => const SizedBox(),
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('BEFORE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if ((photos['after'] ?? '').isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showPhotoPreview(photos['after']!),
                          child: Container(
                            height: 80,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: NetworkImage(photos['after']!),
                                fit: BoxFit.cover,
                                onError: (_, __) => const SizedBox(),
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('AFTER', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _rejectGarbage(record),
                  icon: const Icon(Icons.close, color: kErrorRed, size: 18),
                  label: const Text('Reject', style: TextStyle(color: kErrorRed)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approveGarbage(record),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pest Control Tab ───────────────────────────────────────────────────

  Widget _buildPestControlTab() {
    if (_pestLoading) return const Center(child: CircularProgressIndicator());
    if (_pestError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: kErrorRed),
            const SizedBox(height: 12),
            Text(_pestError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadPestRecords, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_pestRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bug_report, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No pending pest control records', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPestRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pestRecords.length,
        itemBuilder: (_, i) => _buildPestCard(_pestRecords[i]),
      ),
    );
  }

  Widget _buildPestCard(Map<String, dynamic> record) {
    final photos = _extractBeforeAfterUrls(record);
    final pestType = record['pestType']?.toString() ?? 'General';
    final date = record['conductedDate']?.toString() ?? record['createdAt']?.toString() ?? '';
    final remarks = record['remarks']?.toString() ?? '';

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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kWarningOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bug_report, color: kWarningOrange, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pestType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (date.isNotEmpty)
                        Text(date, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            if ((photos['before'] ?? '').isNotEmpty || (photos['after'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    if ((photos['before'] ?? '').isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showPhotoPreview(photos['before']!),
                          child: Container(
                            height: 80,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: NetworkImage(photos['before']!),
                                fit: BoxFit.cover,
                                onError: (_, __) => const SizedBox(),
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('BEFORE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if ((photos['after'] ?? '').isNotEmpty)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showPhotoPreview(photos['after']!),
                          child: Container(
                            height: 80,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                              image: DecorationImage(
                                image: NetworkImage(photos['after']!),
                                fit: BoxFit.cover,
                                onError: (_, __) => const SizedBox(),
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('AFTER', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (remarks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(remarks, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
              ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _reviewPestControl(record, 'rejected'),
                  icon: const Icon(Icons.close, color: kErrorRed, size: 18),
                  label: const Text('Reject', style: TextStyle(color: kErrorRed)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _reviewPestControl(record, 'approved'),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
