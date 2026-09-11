import 'dart:convert';
import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/model/railway_worker_model.dart';
import 'package:crm_train/repositories/station_attendance_repository.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/repositories/obhs_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StationAttendanceScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const StationAttendanceScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<StationAttendanceScreen> createState() => _StationAttendanceScreenState();
}

class _StationAttendanceScreenState extends State<StationAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();
  String _selectedShift = 'morning';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<RailwayWorkerModel> _workers = [];
  final Map<String, AttendanceStatus> _attendanceStates = {};
  final Map<String, String> _reasons = {};
  final Map<String, String> _photoUrls = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadWorkers();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? prefs.getString('token');
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final workersList = await OBHSRepository.getWorkers();
      setState(() {
        _workers = workersList;
        for (var w in _workers) {
          final uid = w.uid;
          if (uid.isNotEmpty) {
            _attendanceStates[uid] = AttendanceStatus.present;
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load workers: $e'), backgroundColor: kErrorRed),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _captureWorkerPhoto(String workerId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return _photoUrls[workerId];
    try {
      final bytes = await picked.readAsBytes();
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/evidence/upload/base64'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'image': base64Encode(bytes),
          'fileName': 'attendance_${workerId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] ?? data['imageUrl'] ?? '';
      }
    } catch (_) {}
    return null;
  }

  Future<void> _submitAttendance() async {
    setState(() => _isLoading = true);
    try {
      final formattedDate = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final payload = {
        'stationId': widget.stationId,
        'date': formattedDate,
        'shift': _selectedShift,
        'workers': _workers.map((w) {
          final uid = w.uid;
          return {
            'workerId': uid,
            'workerName': w.fullName,
            'status': _attendanceStates[uid]?.name ?? 'present',
            'captureMode': _photoUrls[uid] != null ? 'photo' : 'manual',
            'photoUrl': _photoUrls[uid] ?? '',
            'reason': _reasons[uid] ?? '',
          };
        }).toList(),
      };
      await StationAttendanceRepository.bulkMark(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance submitted successfully!'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Mark Attendance'),
            Tab(text: 'Attendance List'),
            Tab(text: 'Exceptions'),
          ],
        ),
      ),
      body: _isLoading && _workers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildMarkAttendanceTab(),
                _buildAttendanceListTab(),
                _buildExceptionsTab(),
              ],
            ),
    );
  }

  Widget _buildMarkAttendanceTab() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedShift,
                      decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'morning', child: Text('Morning', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'afternoon', child: Text('Afternoon', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'night', child: Text('Night', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedShift = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: kRailwayBlue, size: 18),
                          const SizedBox(width: 6),
                          Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _workers.length,
              itemBuilder: (context, idx) {
                final w = _workers[idx];
                final uid = w.uid;
                final name = w.fullName;
                final designation = w.designation ?? 'Field Staff';
                final hasPhoto = _photoUrls[uid] != null && _photoUrls[uid]!.isNotEmpty;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final url = await _captureWorkerPhoto(uid);
                                if (url != null) setState(() => _photoUrls[uid] = url);
                              },
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: kRailwayBlue.withOpacity(0.1),
                                    backgroundImage: hasPhoto ? NetworkImage(_photoUrls[uid]!) : null,
                                    child: hasPhoto ? null : const Icon(Icons.person, color: kRailwayBlue),
                                  ),
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(color: hasPhoto ? kSuccessGreen : Colors.grey, shape: BoxShape.circle),
                                      child: Icon(hasPhoto ? Icons.check : Icons.camera_alt, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(designation, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            DropdownButton<AttendanceStatus>(
                              value: _attendanceStates[uid],
                              items: AttendanceStatus.values.map((status) {
                                return DropdownMenuItem(value: status, child: Text(status.name.toUpperCase(), style: const TextStyle(fontSize: 13)));
                              }).toList(),
                              onChanged: (status) {
                                if (status != null) setState(() => _attendanceStates[uid] = status);
                              },
                            ),
                          ],
                        ),
                        if (_attendanceStates[uid] != AttendanceStatus.present)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Reason for absence/late',
                                border: UnderlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (val) => _reasons[uid] = val,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: kRailwayBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceListTab() {
    return _AttendanceListView(stationId: widget.stationId);
  }

  Widget _buildExceptionsTab() {
    return _AttendanceExceptionsView(stationId: widget.stationId);
  }
}

// ─── Attendance List (OBHS-style: workers with start/mid/end chips) ──────────────

class _AttendanceListView extends StatefulWidget {
  final String stationId;
  const _AttendanceListView({required this.stationId});

  @override
  State<_AttendanceListView> createState() => _AttendanceListViewState();
}

class _AttendanceListViewState extends State<_AttendanceListView> {
  String _shift = 'morning';
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = false;
  String? _error;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await StationCleaningRepository.getStationAttendanceList(stationId: widget.stationId);
      final raw = result['records'] as List? ?? [];
      final filtered = raw.where((r) {
        final rDate = (r['createdAt']?.toString() ?? '').substring(0, 10);
        return rDate == "${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}";
      }).toList();
      setState(() { _records = List<Map<String, dynamic>>.from(filtered); _error = null; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _shift,
                    decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'morning', child: Text('Morning', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'afternoon', child: Text('Afternoon', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'night', child: Text('Night', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _shift = v); },
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 7)), lastDate: DateTime.now());
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: kRailwayBlue, size: 18),
                        const SizedBox(width: 6),
                        Text("${_date.day}/${_date.month}/${_date.year}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _load,
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child: const Text('Load'),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        else if (_records.isEmpty)
          const Expanded(child: Center(child: Text('No attendance records found', style: TextStyle(color: Colors.grey, fontSize: 16))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _records.length,
              itemBuilder: (_, i) => _buildWorkerCard(_records[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> record) {
    final name = record['workerName']?.toString() ?? 'Unknown Worker';
    final isStart = record['isStartMarked'] == true;
    final isMid = record['isMidMarked'] == true;
    final isEnd = record['isEndMarked'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: kRailwayBlue.withOpacity(0.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip('Start', isStart ? kSuccessGreen : Colors.grey, isStart),
                      const SizedBox(width: 6),
                      _chip('Mid', isMid ? Colors.orange : Colors.grey, isMid),
                      const SizedBox(width: 6),
                      _chip('End', isEnd ? Colors.red : Colors.grey, isEnd),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color : Colors.grey.shade300),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? color : Colors.grey)),
    );
  }
}

// ─── Attendance Exceptions Tab ─────────────────────────────────────────────────────

class _AttendanceExceptionsView extends StatefulWidget {
  final String stationId;
  const _AttendanceExceptionsView({required this.stationId});

  @override
  State<_AttendanceExceptionsView> createState() => _AttendanceExceptionsViewState();
}

class _AttendanceExceptionsViewState extends State<_AttendanceExceptionsView> {
  List<Map<String, dynamic>> _exceptions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await StationCleaningRepository.getAttendanceExceptions(status: 'PENDING');
      final raw = result['exceptions'] as List? ?? result['data'] as List? ?? [];
      _exceptions = List<Map<String, dynamic>>.from(raw);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _takeAction(String exceptionId, String action) async {
    final remarkCtrl = TextEditingController();
    if (action == 'REJECTED') {
      final remark = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rejection Reason'),
          content: TextField(
            controller: remarkCtrl,
            decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (remarkCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, remarkCtrl.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: kErrorRed),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (remark == null) return;
      remarkCtrl.text = remark;
    }
    try {
      await StationCleaningRepository.takeExceptionAction(
        exceptionId: exceptionId,
        action: action,
        adminRemark: remarkCtrl.text.isNotEmpty ? remarkCtrl.text : null,
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exception ${action == 'APPROVED' ? 'approved' : 'rejected'}'),
            backgroundColor: action == 'APPROVED' ? kSuccessGreen : kWarningOrange,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
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
      );
    }
    if (_exceptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No pending exceptions', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _exceptions.length,
        itemBuilder: (_, i) => _buildExceptionCard(_exceptions[i]),
      ),
    );
  }

  Widget _buildExceptionCard(Map<String, dynamic> ex) {
    final issueType = ex['issueType']?.toString() ?? 'Unknown';
    final remark = ex['remark']?.toString() ?? '';
    final workerName = ex['workerName']?.toString() ?? 'Unknown Worker';
    final attendanceType = ex['attendanceType']?.toString() ?? '';
    final createdAt = ex['createdAt']?.toString() ?? '';
    final id = ex['exceptionId']?.toString() ?? ex['uid']?.toString() ?? '';

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
                  child: const Icon(Icons.warning_amber, color: kWarningOrange, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (createdAt.isNotEmpty)
                        Text(createdAt, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _detailRow('Issue', issueType),
            if (attendanceType.isNotEmpty) _detailRow('Attendance', attendanceType),
            if (remark.isNotEmpty) _detailRow('Remark', remark),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: id.isNotEmpty ? () => _takeAction(id, 'REJECTED') : null,
                  icon: const Icon(Icons.close, color: kErrorRed, size: 18),
                  label: const Text('Reject', style: TextStyle(color: kErrorRed)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: id.isNotEmpty ? () => _takeAction(id, 'APPROVED') : null,
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('$label:', style: const TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}


