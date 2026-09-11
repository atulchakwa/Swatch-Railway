import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/repositories/worker_repo.dart';
import 'package:crm_train/helper/api_error_handler.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'workers/worker_management_screen.dart';
import 'shift_summary_screen.dart';

class SupervisorTaskScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String supervisorId;
  final String supervisorName;

  const SupervisorTaskScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SupervisorTaskScreen> createState() => _SupervisorTaskScreenState();
}

class _SupervisorTaskScreenState extends State<SupervisorTaskScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;

  // Attendance (3-step: start/mid/end)
  bool _startMarked = false;
  bool _midMarked = false;
  bool _endMarked = false;
  bool _attendanceLoading = false;

  // Tasks
  List<Map<String, dynamic>> _tasks = [];
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  String _taskFilter = 'all';

  // Workers
  List<Map<String, dynamic>> _workers = [];

  // Photos
  static const _statusChips = ['all', 'overdue', 'pending', 'assigned', 'in_progress', 'completed', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadAttendanceStatus(), _loadTasks(), _loadWorkers()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadAttendanceStatus() async {
    try {
      final result = await StationCleaningRepository.getStationAttendanceStatus(
        workerId: widget.supervisorId,
      );
      if (result['exists'] == true) {
        setState(() {
          _startMarked = result['isStartMarked'] == true;
          _midMarked = result['isMidMarked'] == true;
          _endMarked = result['isEndMarked'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final uri = Uri.parse('${ApiService.baseUrl}/api/tasks-v2/supervisor/${widget.supervisorId}')
          .replace(queryParameters: {'date': _selectedDate});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['tasks'] as List<dynamic>? ?? [];
        setState(() => _tasks = list.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadWorkers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final uri = Uri.parse('${ApiService.baseUrl}/api/station-cleaning/workers/list')
          .replace(queryParameters: {'stationId': widget.stationId});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['workers'] as List<dynamic>? ?? body['data'] as List<dynamic>? ?? [];
        setState(() => _workers = list.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredTasks {
    var list = _tasks;
    if (_taskFilter == 'overdue') {
      list = list.where((t) => t['isOverdue'] == true).toList();
    } else if (_taskFilter != 'all') {
      list = list.where((t) => t['status'] == _taskFilter).toList();
    }
    list.sort((a, b) => ((a['scheduledTime'] ?? '00:00') as String).compareTo(b['scheduledTime'] ?? '00:00'));
    return list;
  }

  List<Map<String, dynamic>> get _unassignedTasks =>
      _tasks.where((t) => t['workerId'] == null || t['workerId'] == '').toList()
        ..sort((a, b) => ((a['scheduledTime'] ?? '00:00') as String).compareTo(b['scheduledTime'] ?? '00:00'));

  int get _pendingCount => _tasks.where((t) => t['status'] == 'pending').length;
  int get _overdueCount => _tasks.where((t) => t['isOverdue'] == true).length;
  int get _inProgressCount => _tasks.where((t) => t['status'] == 'in_progress').length;
  int get _completedCount => _tasks.where((t) => t['status'] == 'completed' || t['status'] == 'approved').length;

  // ─── Attendance ──────────────────────────────────────────────────────────

  final _picker = ImagePicker();

  String _generateLivenessChallenge() {
    return 'SMILE';
  }

  String _livenessChallengeText(String challenge) {
    return 'wide Smile';
  }

  Future<Position?> _captureGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _markAttendance(String type) async {
    final challenge = _generateLivenessChallenge();
    final challengeText = _livenessChallengeText(challenge);

    bool proceed = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Liveness Check'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_front, size: 50, color: kRailwayBlue),
            const SizedBox(height: 10),
            Text(
              'Please take a selfie showing a:\n\n$challengeText\n\n(Keep your face clearly visible!)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              proceed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Open Camera'),
          ),
        ],
      ),
    );

    if (!proceed) return;

    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (photo == null) return;

    setState(() => _attendanceLoading = true);
    try {
      final photoUrl = await WorkerRepository.uploadMedia(photo.path);

      final pos = await _captureGps();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get GPS. Check location permissions.'), backgroundColor: kWarningOrange),
          );
        }
        return;
      }

      await StationCleaningRepository.markStationAttendance(
        type: type,
        runInstanceId: widget.supervisorId,
        stationId: widget.stationId,
        imageUrl: photoUrl,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        livenessChallenge: challenge,
      );

      setState(() {
        if (type == 'start') _startMarked = true;
        if (type == 'mid') _midMarked = true;
        if (type == 'end') _endMarked = true;
      });

      if (mounted) {
        if (type == 'end') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Shift ended — submit your photos for critical areas now'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'SUBMIT',
                textColor: Colors.white,
                onPressed: _promptShiftSummary,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${type.toUpperCase()} attendance marked'), backgroundColor: kSuccessGreen),
          );
        }
      }

      if (type == 'end' && mounted) {
        _promptShiftSummary();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance error: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _attendanceLoading = false);
    }
  }

  void _promptShiftSummary() {
    if (_tasks.isEmpty) return;
    final areaMap = <String, Map<String, dynamic>>{};
    for (final t in _tasks) {
      final areaId = (t['areaId'] ?? t['areaName'] ?? '') as String;
      if (areaId.isEmpty) continue;
      final key = areaId;
      if (!areaMap.containsKey(key)) {
        areaMap[key] = {
          'uid': t['uid'],
          'areaId': t['areaId'],
          'areaName': t['areaName'],
          'scheduledTime': t['scheduledTime'],
          'taskId': t['uid'],
        };
      }
    }
    final areas = areaMap.values.toList();
    if (areas.isEmpty) return;

    final primaryShift = _tasks.isNotEmpty
        ? (_tasks.first['shift']?.toString() ?? 'Morning')
        : 'Morning';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          icon: const Icon(Icons.camera_alt, size: 48, color: Colors.orange),
          title: const Text('Shift Summary Required'),
          content: const Text(
            'You must photograph at least 5 critical areas and submit your shift summary to complete your shift.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShiftSummaryScreen(
                      stationId: widget.stationId,
                      stationName: widget.stationName,
                      supervisorId: widget.supervisorId,
                      supervisorName: widget.supervisorName,
                      shift: primaryShift,
                      date: _selectedDate,
                      areas: areas,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kRailwayBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Submit Photos'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Task Assignment ─────────────────────────────────────────────────────

  Future<void> _showAssignWorker(String taskId) async {
    if (_workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workers registered. Add workers first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _WorkerPicker(workers: _workers),
    );

    if (selected == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/tasks/${taskId}/assign'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'workerId': selected['uid'], 'workerName': selected['name'] ?? selected['fullName'] ?? ''}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Task assigned to ${selected['name'] ?? selected['fullName']}'), backgroundColor: kSuccessGreen),
          );
        }
        _loadTasks();
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignment error: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  // ─── Task Execution ──────────────────────────────────────────────────────

  Future<void> _startTask(String taskId) async {
    if (!_startMarked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mark start attendance first'), backgroundColor: kWarningOrange),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      double? lat, lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final body = <String, dynamic>{};
      if (lat != null) { body['gpsLat'] = lat; body['gpsLng'] = lng; }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/tasks-v2/$taskId/start'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task started'), backgroundColor: kSuccessGreen));
        _loadTasks();
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
      }
    }
  }

  void _showCompleteSheet(String taskId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupervisorTaskExecutionSheet(
        taskId: taskId,
        mode: 'complete',
        onDone: () async {
          await _loadTasks();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showResubmitSheet(String taskId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupervisorTaskExecutionSheet(
        taskId: taskId,
        mode: 'resubmit',
        onDone: () async {
          await _loadTasks();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stationName} Tasks', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.fingerprint), text: 'Attendance'),
            Tab(icon: const Icon(Icons.cleaning_services), text: 'Tasks ($_pendingCount)'),
            Tab(icon: const Icon(Icons.assignment), text: 'Assign (${_unassignedTasks.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildTasksTab(),
          _buildAssignTab(),
        ],
      ),
    );
  }

  // ─── Attendance Tab ──────────────────────────────────────────────────────

  Widget _buildAttendanceTab() {
    return RefreshIndicator(
      onRefresh: () => _loadAttendanceStatus(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.fingerprint, size: 64, color: kRailwayBlue.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text('Mark Your Attendance', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(widget.supervisorName, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _attendanceCard(
            step: 'Start (1/3)',
            icon: Icons.login,
            marked: _startMarked,
            onMark: () => _markAttendance('start'),
            description: 'Mark shift start — take a selfie',
            unlocked: !_startMarked,
          ),
          const SizedBox(height: 12),
          _attendanceCard(
            step: 'Mid (2/3)',
            icon: Icons.pause_circle,
            marked: _midMarked,
            onMark: () => _markAttendance('mid'),
            description: 'Mark mid-shift check',
            unlocked: _startMarked && !_midMarked,
          ),
          const SizedBox(height: 12),
          _attendanceCard(
            step: 'End (3/3)',
            icon: Icons.logout,
            marked: _endMarked,
            onMark: () => _markAttendance('end'),
            description: 'Mark shift end',
            unlocked: _midMarked && !_endMarked,
          ),
          const SizedBox(height: 24),
          if (_endMarked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Submit Shift Summary Photos'),
                onPressed: () => _promptShiftSummary(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _attendanceCard({
    required String step,
    required IconData icon,
    required bool marked,
    required VoidCallback onMark,
    required String description,
    required bool unlocked,
  }) {
    return Card(
      elevation: marked ? 1 : 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: marked ? kSuccessGreen : (unlocked ? kRailwayBlue : Colors.grey[300]),
          child: Icon(marked ? Icons.check : icon, color: Colors.white),
        ),
        title: Text('$step Attendance', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(marked ? 'Completed' : description),
        trailing: _attendanceTrailing(marked, unlocked, onMark),
      ),
    );
  }

  Widget _attendanceTrailing(bool marked, bool unlocked, VoidCallback onMark) {
    if (_attendanceLoading) {
      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (marked) {
      return const Icon(Icons.check_circle, color: kSuccessGreen);
    }
    if (unlocked) {
      return ElevatedButton(
        onPressed: onMark,
        style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
        child: const Text('Mark'),
      );
    }
    return const Text('');
  }

  // ─── Tasks Tab ───────────────────────────────────────────────────────────

  Widget _buildTasksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.parse(_selectedDate),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked.toIso8601String().split('T')[0]);
                      _loadTasks();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today)),
                    child: Text(_selectedDate),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTasks),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text('Pending: $_pendingCount  |  In Progress: $_inProgressCount  |  Overdue: $_overdueCount  |  Done: $_completedCount',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: _statusChips.map((s) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(s.replaceAll('_', ' ')),
                selected: _taskFilter == s,
                onSelected: (v) => setState(() => _taskFilter = s),
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : _filteredTasks.isEmpty
                      ? const Center(child: Text('No tasks for this date'))
                      : RefreshIndicator(
                          onRefresh: _loadTasks,
                          child: ListView.builder(
                            itemCount: _filteredTasks.length,
                            itemBuilder: (ctx, i) {
                              final t = _filteredTasks[i];
                              return _buildTaskCard(t);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> t) {
    final status = t['status'] ?? 'pending';
    final isOverdue = t['isOverdue'] == true;
    final areaName = t['areaName'] ?? '';
    final activityName = t['activityType'] ?? t['taskTypeName'] ?? 'Cleaning';
    final time = t['scheduledTime'] ?? '--:--';
    final workerName = t['workerName'] ?? '';
    final taskId = t['uid'] ?? t['id'];
    final rejectionReason = t['rejectionReason'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: isOverdue
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: kErrorRed, width: 1.5),
            )
          : null,
      child: ExpansionTile(
        leading: Icon(isOverdue ? Icons.error : _statusIcon(status), color: isOverdue ? kErrorRed : _statusColor(status), size: 28),
        title: Text('$time - $activityName',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(
          '${areaName.isNotEmpty ? areaName : 'Area'}'
          '${isOverdue ? ' | Overdue' : ''}'
          '${workerName.isNotEmpty ? ' | $workerName' : ''}',
          style: TextStyle(fontSize: 12, color: isOverdue ? kErrorRed : _statusColor(status)),
        ),
        children: [
          if (isOverdue)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kErrorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: kErrorRed, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Overdue — you missed the time of cleaning',
                      style: TextStyle(color: kErrorRed, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (rejectionReason != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Rejection: $rejectionReason', style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (status == 'pending' && (t['workerId'] == null || t['workerId'] == ''))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Assign'),
                    onPressed: () => _showAssignWorker(taskId),
                  ),
                if (status == 'pending' && t['workerId'] != null && t['workerId'] != '')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Start'),
                    onPressed: () => _startTask(taskId),
                  ),
                if (status == 'in_progress')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Complete'),
                    onPressed: () => _showCompleteSheet(taskId),
                  ),
                if (status == 'rejected')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Resubmit'),
                    onPressed: () => _showResubmitSheet(taskId),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Assign Tab ──────────────────────────────────────────────────────────

  Widget _buildAssignTab() {
    if (_unassignedTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: kSuccessGreen.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('All tasks assigned!', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.people),
              label: const Text('Manage Workers'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerManagementScreen(
                    stationId: widget.stationId,
                    stationName: widget.stationName,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('${_unassignedTasks.length} unassigned task(s)',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.people, size: 18),
                label: const Text('Workers'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerManagementScreen(
                      stationId: widget.stationId,
                      stationName: widget.stationName,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTasks,
            child: ListView.builder(
              itemCount: _unassignedTasks.length,
              itemBuilder: (ctx, i) {
                final t = _unassignedTasks[i];
                final areaName = t['areaName'] ?? '';
                final activityName = t['activityType'] ?? t['taskTypeName'] ?? 'Cleaning';
                final time = t['scheduledTime'] ?? '--:--';
                final taskId = t['uid'] ?? t['id'];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.15),
                      child: const Icon(Icons.schedule, color: Colors.orange),
                    ),
                    title: Text('$time - $activityName'),
                    subtitle: Text('${areaName.isNotEmpty ? areaName : 'Area'} | ${t['frequency'] ?? ''} | ${t['shift'] ?? ''}'),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Assign'),
                      onPressed: () => _showAssignWorker(taskId),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'assigned': return Colors.blue;
      case 'in_progress': return Colors.amber.shade700;
      case 'completed': return Colors.green;
      case 'approved': return Colors.teal;
      case 'rejected': return Colors.red;
      case 'resubmitted': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.schedule;
      case 'in_progress': return Icons.cleaning_services;
      case 'completed': return Icons.check_circle_outline;
      case 'approved': return Icons.verified;
      case 'rejected': return Icons.cancel;
      case 'resubmitted': return Icons.replay;
      default: return Icons.circle;
    }
  }
}

// ─── Worker Picker Bottom Sheet ────────────────────────────────────────────

class _WorkerPicker extends StatelessWidget {
  final List<Map<String, dynamic>> workers;
  const _WorkerPicker({required this.workers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Select Worker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ListView.separated(
              itemCount: workers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final w = workers[i];
                final name = w['name'] ?? w['fullName'] ?? 'Unknown';
                final phone = w['phone'] ?? w['mobileNumber'] ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kRailwayBlue.withOpacity(0.15),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(name),
                  subtitle: Text(phone.isNotEmpty ? phone : 'No phone'),
                  onTap: () => Navigator.pop(context, w),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Supervisor Task Execution Sheet ───────────────────────────────────────

class _SupervisorTaskExecutionSheet extends StatefulWidget {
  final String taskId;
  final String mode;
  final VoidCallback onDone;

  const _SupervisorTaskExecutionSheet({
    required this.taskId,
    required this.mode,
    required this.onDone,
  });

  @override
  State<_SupervisorTaskExecutionSheet> createState() => _SupervisorTaskExecutionSheetState();
}

class _SupervisorTaskExecutionSheetState extends State<_SupervisorTaskExecutionSheet> {
  int currentStep = 0;
  XFile? beforePhoto;
  XFile? afterPhoto;
  final TextEditingController _commentCtrl = TextEditingController();
  bool isSubmitting = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.mode == 'complete' ? 'Complete Task' : 'Resubmit Task',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Step ${currentStep + 1} of 4', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Row(
                children: List.generate(4, (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: i <= currentStep ? kRailwayBlue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 20),
              if (currentStep == 0) _photoStep('Before Photo', beforePhoto, true)
              else if (currentStep == 1) _commentStep()
              else if (currentStep == 2) _photoStep('After Photo', afterPhoto, false)
              else _summaryStep(),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => currentStep--),
                        child: const Text('Back'),
                      ),
                    ),
                  if (currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canProceed() && !isSubmitting ? () {
                        if (currentStep < 3) {
                          setState(() => currentStep++);
                        } else {
                          _submit();
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                      child: Text(isSubmitting ? 'Submitting...' : currentStep == 3 ? 'Submit' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoStep(String label, XFile? photo, bool isBefore) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 12),
        if (photo != null)
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: FileImage(File(photo.path)), fit: BoxFit.cover),
            ),
          )
        else
          GestureDetector(
            onTap: () => _capturePhoto(isBefore: isBefore),
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  Text('Tap to take photo', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _commentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add Comments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 12),
        TextField(
          controller: _commentCtrl,
          minLines: 3,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter remarks...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _summaryStep() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: kSuccessGreen, size: 20),
              SizedBox(width: 8),
              Text('Review & Submit', style: TextStyle(fontWeight: FontWeight.w600, color: kSuccessGreen)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Before Photo: ${beforePhoto != null ? 'Captured' : 'Not captured'}'),
          Text('Comments: ${_commentCtrl.text.isEmpty ? 'None' : _commentCtrl.text}'),
          Text('After Photo: ${afterPhoto != null ? 'Captured' : 'Not captured'}'),
        ],
      ),
    );
  }

  bool _canProceed() {
    if (currentStep == 0) return true;
    if (currentStep == 1) return _commentCtrl.text.isNotEmpty;
    if (currentStep == 2) return true;
    return true;
  }

  Future<void> _capturePhoto({required bool isBefore}) async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1280);
    if (photo == null) return;
    setState(() {
      if (isBefore) beforePhoto = photo;
      else afterPhoto = photo;
    });
  }

  Future<void> _submit() async {
    setState(() => isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('AUTH_ERROR');

      String? beforeUrl;
      String? afterUrl;
      if (beforePhoto != null) {
        beforeUrl = await WorkerRepository.uploadMedia(beforePhoto!.path);
      }
      if (afterPhoto != null) {
        afterUrl = await WorkerRepository.uploadMedia(afterPhoto!.path);
      }

      double? lat, lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final body = <String, dynamic>{
        'remarks': _commentCtrl.text.trim(),
      };
      if (beforeUrl != null) { body['beforePhoto'] = beforeUrl; }
      if (afterUrl != null) { body['afterPhoto'] = afterUrl; }
      if (lat != null) { body['gpsLat'] = lat; body['gpsLng'] = lng; }

      final endpoint = widget.mode == 'complete' ? 'complete' : 'resubmit';
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/tasks-v2/${widget.taskId}/$endpoint'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mode == 'complete' ? 'Task completed!' : 'Task resubmitted'),
            backgroundColor: kSuccessGreen,
          ),
        );
        widget.onDone();
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: kErrorRed),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}
