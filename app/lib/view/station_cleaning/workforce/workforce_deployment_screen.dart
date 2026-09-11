import 'package:flutter/material.dart';
import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/repositories/workforce_deployment_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/repositories/obhs_repository.dart';

class WorkforceDeploymentScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const WorkforceDeploymentScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<WorkforceDeploymentScreen> createState() => _WorkforceDeploymentScreenState();
}

class _WorkforceDeploymentScreenState extends State<WorkforceDeploymentScreen> {
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  List<WorkforceDeployment> _deployments = [];
  List<Map<String, dynamic>> _shifts = [];
  Map<String, dynamic> _shiftWiseManpower = {};
  String? _selectedShiftId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final formattedDate = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final results = await Future.wait([
        WorkforceDeploymentRepository.list({'stationId': widget.stationId, 'status': 'active'}),
        WorkforceDeploymentRepository.getShifts(widget.stationId),
        WorkforceDeploymentRepository.getShiftWiseManpower(widget.stationId, formattedDate),
      ]);
      if (mounted) {
        setState(() {
          _deployments = results[0] as List<WorkforceDeployment>;
          _shifts = results[1] as List<Map<String, dynamic>>;
          _shiftWiseManpower = results[2] as Map<String, dynamic>;
          if (_shifts.isNotEmpty && _selectedShiftId == null) {
            _selectedShiftId = _shifts.first['uid'] ?? _shifts.first['shiftType'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e'), backgroundColor: kErrorRed));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkforceDeployment> _deploymentsForShift(String? shiftId) {
    if (shiftId == null) return [];
    return _deployments.where((d) => d.shiftId == shiftId).toList();
  }

  Map<String, dynamic>? _manpowerForShift(String? shiftId) {
    if (shiftId == null || _shiftWiseManpower['shifts'] == null) return null;
    final shifts = _shiftWiseManpower['shifts'] as List;
    for (final s in shifts) {
      if (s['shiftId'] == shiftId) return s;
    }
    return null;
  }

  Future<void> _showAddDeploymentSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AddDeploymentSheet(
        stationId: widget.stationId,
        shifts: _shifts,
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deactivateDeployment(WorkforceDeployment dep) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Deployment'),
        content: Text('Remove ${dep.workerName} from this shift?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate', style: TextStyle(color: kErrorRed))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await WorkforceDeploymentRepository.delete(dep.uid);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deployment deactivated'), backgroundColor: kSuccessGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kErrorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workforce - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _shifts.isEmpty
                  ? const Center(child: Text('No shifts configured for this station.\nCreate shifts first.'))
                  : Column(
                      children: [
                        _buildDateSelector(),
                        _buildManpowerSummary(),
                        _buildShiftTabs(),
                        Expanded(child: _buildDeploymentList()),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kRailwayBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _showAddDeploymentSheet,
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: kRailwayBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadData();
                }
              },
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManpowerSummary() {
    final totalPlanned = _shiftWiseManpower['totalPlanned'] ?? 0;
    final totalActual = _shiftWiseManpower['totalActual'] ?? 0;
    final variance = totalPlanned - totalActual;
    final pct = totalPlanned > 0 ? ((variance / totalPlanned) * 100).toStringAsFixed(1) : '0';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _summaryItem('Planned', '$totalPlanned', kRailwayBlue),
            _summaryItem('Actual', '$totalActual', kSuccessGreen),
            _summaryItem('Variance', '$variance ($pct%)', variance == 0 ? kSuccessGreen : kErrorRed),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildShiftTabs() {
    final shifts = _shiftWiseManpower['shifts'] as List? ?? [];
    if (shifts.isEmpty && _shifts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _shifts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final s = _shifts[i];
              final sid = s['uid'] ?? s['shiftType'];
              final selected = sid == _selectedShiftId;
              return FilterChip(
                label: Text(s['shiftType']?.toString().toUpperCase() ?? 'SHIFT'),
                selected: selected,
                onSelected: (_) => setState(() => _selectedShiftId = sid),
              );
            },
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: shifts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final s = shifts[i];
            final sid = s['shiftId'];
            final selected = sid == _selectedShiftId;
            final pct = s['planned'] > 0 ? ((s['variance'] / s['planned']) * 100).toStringAsFixed(1) : '0';
            return FilterChip(
              label: Text('${s['shiftId'].toString().toUpperCase()} (${s['planned']}/${s['actual']} /$pct%)'),
              selected: selected,
              onSelected: (_) => setState(() => _selectedShiftId = sid),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeploymentList() {
    final filtered = _deploymentsForShift(_selectedShiftId);
    if (filtered.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('No deployments for this shift', style: TextStyle(color: Colors.grey))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final d = filtered[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: kRailwayBlue.withValues(alpha: 0.15),
              child: Text(d.workerName.isNotEmpty ? d.workerName[0].toUpperCase() : '?', style: const TextStyle(color: kRailwayBlue, fontWeight: FontWeight.bold)),
            ),
            title: Text(d.workerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.areaId != null) Text('Area: ${d.areaId}'),
                if (d.supervisorName != null) Text('Supervisor: ${d.supervisorName}'),
                Text('${d.startDate}${d.endDate != null ? ' - ${d.endDate}' : ''}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: kErrorRed),
              onPressed: () => _deactivateDeployment(d),
            ),
          ),
        );
      },
    );
  }
}

class _AddDeploymentSheet extends StatefulWidget {
  final String stationId;
  final List<Map<String, dynamic>> shifts;
  const _AddDeploymentSheet({required this.stationId, required this.shifts});

  @override
  State<_AddDeploymentSheet> createState() => _AddDeploymentSheetState();
}

class _AddDeploymentSheetState extends State<_AddDeploymentSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  String? _selectedShiftId;
  String? _selectedWorkerId;
  String? _selectedWorkerName;
  String? _selectedTaskId;
  String? _selectedAreaId;
  String? _selectedSupervisorId;
  String? _selectedSupervisorName;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _taskTypes = [];
  List<StationArea> _areas = [];
  List<Map<String, dynamic>> _supervisors = [];

  @override
  void initState() {
    super.initState();
    if (widget.shifts.isNotEmpty) {
      _selectedShiftId = widget.shifts.first['uid'] ?? widget.shifts.first['shiftType'];
    }
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final results = await Future.wait([
        WorkforceDeploymentRepository.getTaskTypes(),
        ApiService.getStationAreas(widget.stationId),
      ]);
      final workersList = await OBHSRepository.getWorkers();
      final supervisorsList = await ApiService.getSupervisors(module: 'station_cleaning');

      if (mounted) {
        setState(() {
          _taskTypes = results[0] as List<Map<String, dynamic>>;
          _areas = results[1] as List<StationArea>;
          _workers = workersList.map((w) => {'uid': w.uid, 'fullName': w.fullName}).toList();
          _supervisors = supervisorsList;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a worker'), backgroundColor: kErrorRed));
      return;
    }
    setState(() => _saving = true);
    try {
      final formattedDate = "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}";
      String? endDateStr;
      if (_endDate != null) {
        endDateStr = "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}";
      }
      await WorkforceDeploymentRepository.create({
        'workerId': _selectedWorkerId,
        'stationId': widget.stationId,
        'shiftId': _selectedShiftId ?? '',
        'taskId': _selectedTaskId ?? '',
        'areaId': _selectedAreaId,
        'supervisorId': _selectedSupervisorId,
        'startDate': formattedDate,
        'endDate': endDateStr,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worker deployed'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kErrorRed));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Add Deployment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedShiftId,
                  decoration: const InputDecoration(labelText: 'Shift *', border: OutlineInputBorder()),
                  items: widget.shifts.map<DropdownMenuItem<String>>((s) {
                    final id = s['uid'] ?? s['shiftType'];
                    return DropdownMenuItem(value: id, child: Text(s['shiftType']?.toString().toUpperCase() ?? id));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedShiftId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedWorkerId,
                  decoration: const InputDecoration(labelText: 'Worker *', border: OutlineInputBorder()),
                  items: _workers.map<DropdownMenuItem<String>>((w) => DropdownMenuItem(
                    value: w['uid'],
                    child: Text(w['fullName'] ?? 'Unknown'),
                  )).toList(),
                  onChanged: (v) {
                    final w = _workers.firstWhere((w) => w['uid'] == v, orElse: () => {});
                    setState(() {
                      _selectedWorkerId = v;
                      _selectedWorkerName = w['fullName'];
                    });
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedTaskId,
                  decoration: const InputDecoration(labelText: 'Task Type', border: OutlineInputBorder()),
                  items: _taskTypes.map<DropdownMenuItem<String>>((t) {
                    final id = t['uid'] ?? t['id'] ?? '';
                    return DropdownMenuItem(value: id, child: Text(t['taskName'] ?? t['name'] ?? id));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedTaskId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedAreaId,
                  decoration: const InputDecoration(labelText: 'Area', border: OutlineInputBorder()),
                  items: _areas.map<DropdownMenuItem<String>>((a) => DropdownMenuItem(value: a.uid, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _selectedAreaId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedSupervisorId,
                  decoration: const InputDecoration(labelText: 'Supervisor', border: OutlineInputBorder()),
                  items: _supervisors.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                    value: s['uid'],
                    child: Text(s['fullName'] ?? s['name'] ?? 'Unknown'),
                  )).toList(),
                  onChanged: (v) {
                    final s = _supervisors.firstWhere((s) => s['uid'] == v, orElse: () => {});
                    setState(() {
                      _selectedSupervisorId = v;
                      _selectedSupervisorName = s['fullName'] ?? s['name'];
                    });
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 7)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Start Date *', border: OutlineInputBorder()),
                    child: Text("${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}"),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                      firstDate: _startDate,
                      lastDate: _startDate.add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'End Date (optional)',
                      border: const OutlineInputBorder(),
                      suffixIcon: _endDate != null
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _endDate = null))
                          : null,
                    ),
                    child: Text(_endDate != null
                        ? "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}"
                        : 'No end date'),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Deploy Worker'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
