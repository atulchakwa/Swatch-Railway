import 'package:flutter/material.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/utills/app_colors.dart';

// Higher-authority view of station-cleaning SUPERVISOR attendance (OBHS-style).
// Shows start/mid/end marks per supervisor with identity-audit status and lets
// upper authorities browse history by date and inspect photos/GPS per mark.
class StationSupervisorAttendanceScreen extends StatefulWidget {
  final String stationId;
  final String stationName;

  const StationSupervisorAttendanceScreen({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<StationSupervisorAttendanceScreen> createState() =>
      _StationSupervisorAttendanceScreenState();
}

class _StationSupervisorAttendanceScreenState
    extends State<StationSupervisorAttendanceScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String? _error;
  DateTime _date = DateTime.now();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  String get _formattedDate {
    final y = _date.year.toString();
    final m = _date.month.toString().padLeft(2, '0');
    final d = _date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _loadAttendance() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await StationCleaningRepository.getStationAttendanceList(
        stationId: widget.stationId,
        workerType: 'supervisor',
        date: _formattedDate,
      );
      final raw = (result['records'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _records = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    final q = _searchQuery.toLowerCase();
    return _records.where((r) =>
      (r['workerName'] ?? '').toString().toLowerCase().contains(q) ||
      (r['identityAuditStatus'] ?? '').toString().toLowerCase().contains(q) ||
      (r['attendanceStatus'] ?? '').toString().toLowerCase().contains(q)
    ).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'VERIFIED_SUCCESS':
      case 'MID_VERIFIED':
        return kSuccessGreen;
      case 'MID_UNVERIFIED_REVIEW':
      case 'UNVERIFIED_REVIEW':
      case 'PENDING_VERIFICATION':
        return kWarningOrange;
      case 'MISMATCH_ALERT':
        return kErrorRed;
      default:
        return Colors.grey;
    }
  }

  Color _attendanceColor(String status) {
    switch (status) {
      case 'PRESENT':
        return kSuccessGreen;
      case 'LATE':
        return kWarningOrange;
      case 'ON_LEAVE':
        return Colors.grey;
      default:
        return kRailwayBlue;
    }
  }

  String _markTime(Map<String, dynamic>? mark) {
    if (mark == null) return '';
    final t = (mark['deviceTimestamp']?.toString() ?? mark['serverTimestamp']?.toString() ?? '').trim();
    if (t.isEmpty || t.length < 16) return '';
    final datePart = DateTime.tryParse(t);
    if (datePart != null) {
      final ist = datePart.toUtc().add(const Duration(hours: 5, minutes: 30));
      final hh = ist.hour.toString().padLeft(2, '0');
      final mm = ist.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return t.substring(11, 16);
  }

  void _showDetail(Map<String, dynamic> record) {
    final start = record['startAttendance'] as Map<String, dynamic>?;
    final mid = record['midAttendance'] as Map<String, dynamic>?;
    final end = record['endAttendance'] as Map<String, dynamic>?;
    final marks = [
      ('Start', start),
      ('Mid', mid),
      ('End', end),
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record['workerName']?.toString() ?? 'Supervisor',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${record['date'] ?? ''} • stationId: ${widget.stationName}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: marks.map((m) {
                    final label = m.$1;
                    final info = m.$2;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: info == null ? Colors.grey.shade300 : kSuccessGreen, width: info == null ? 1 : 1.5),
                      ),
                      child: info == null
                          ? Text('$label: Not marked', style: TextStyle(color: Colors.grey.shade500))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('$label', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Text(_markTime(info), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    const Spacer(),
                                    if (info['isLate'] == true)
                                      Text('Late by ${info['lateByMinutes'] ?? '?'} min',
                                          style: const TextStyle(color: kWarningOrange, fontSize: 11)),
                                  ],
                                ),
                                if ((info['photoUrl'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      info['photoUrl'].toString(),
                                      height: 120,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (_, child, progress) => progress == null
                                          ? child
                                          : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 120,
                                        color: Colors.grey.shade200,
                                        child: const Center(child: Text('Photo unavailable')),
                                      ),
                                    ),
                                  ),
                                ],
                                if ((info['location'] ?? null) != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'GPS: ${(info['location']['latitude'] ?? '').toString().substring(0, (info['location']['latitude'] ?? '').toString().length > 10 ? 8 : ((info['location']['latitude'] ?? '').toString().isNotEmpty ? 8 : 0))}, ${(info['location']['longitude'] ?? '').toString().substring(0, (info['location']['longitude'] ?? '').toString().length > 10 ? 8 : ((info['location']['longitude'] ?? '').toString().isNotEmpty ? 8 : 0))}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ],
                            ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Audit: ${record['identityAuditStatus'] ?? 'NOT_STARTED'}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kRailwayBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Supervisor Attendance — ${widget.stationName}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAttendance),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search supervisor, status...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _date = picked);
                      _loadAttendance();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.calendar_today, color: kRailwayBlue, size: 18),
                        const SizedBox(height: 2),
                        Text('${_date.day}/${_date.month}/${_date.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text('Date: $_formattedDate', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),
                if (!_isLoading)
                  Text('${_filteredRecords.length} supervisor(s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadAttendance, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filteredRecords.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('No supervisor attendance on $_formattedDate',
                                    style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAttendance,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              itemCount: _filteredRecords.length,
                              itemBuilder: (context, index) {
                                final r = _filteredRecords[index];
                                final audit = r['identityAuditStatus']?.toString() ?? 'NOT_STARTED';
                                final attStatus = r['attendanceStatus']?.toString() ?? '';
                                return Card(
                                  margin: const EdgeInsets.only(top: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 1,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _showDetail(r),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: kRailwayBlue.withOpacity(0.1),
                                                child: Text(
                                                  (r['workerName'] ?? '?').toString().substring(0, 1).toUpperCase(),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: kRailwayBlue),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(r['workerName'] ?? 'Unknown',
                                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                    Text('Supervisor • ${r['date'] ?? ''}',
                                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                  ],
                                                ),
                                              ),
                                              if (attStatus.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _attendanceColor(attStatus).withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(attStatus,
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _attendanceColor(attStatus))),
                                                ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _statusColor(audit).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(audit.replaceAll('_', ' '),
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(audit))),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              _attendanceChip('Start', r['isStartMarked'] == true, _markTime(r['startAttendance'] as Map<String, dynamic>?)),
                                              const SizedBox(width: 8),
                                              _attendanceChip('Mid', r['isMidMarked'] == true, _markTime(r['midAttendance'] as Map<String, dynamic>?)),
                                              const SizedBox(width: 8),
                                              _attendanceChip('End', r['isEndMarked'] == true, _markTime(r['endAttendance'] as Map<String, dynamic>?)),
                                            ],
                                          ),
                                          if (r['lateByMinutes'] != null && int.tryParse(r['lateByMinutes'].toString()) != 0) ...[
                                            const SizedBox(height: 6),
                                            Text('Late by ${r['lateByMinutes']} min',
                                                style: const TextStyle(fontSize: 11, color: kWarningOrange)),
                                          ],
                                        ],
                                      ),
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

  Widget _attendanceChip(String label, bool marked, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: marked ? kSuccessGreen.withOpacity(0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(marked ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: marked ? kSuccessGreen : Colors.grey),
          const SizedBox(width: 4),
          Text('$label${time.isNotEmpty ? ' $time' : ''}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: marked ? kSuccessGreen : Colors.grey.shade600)),
        ],
      ),
    );
  }
}