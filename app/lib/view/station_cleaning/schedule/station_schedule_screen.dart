import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class StationScheduleScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const StationScheduleScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<StationScheduleScreen> createState() => _StationScheduleScreenState();
}

class _StationScheduleScreenState extends State<StationScheduleScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<StationCleaningSchedule> _schedules = [];
  List<StationArea> _areas = [];
  List<StationZone> _zones = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getStationSchedules(widget.stationId),
        ApiService.getStationAreas(widget.stationId),
      ]);
      setState(() {
        _schedules = results[0] as List<StationCleaningSchedule>;
        _areas = results[1] as List<StationArea>;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e'), backgroundColor: kErrorRed),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedules - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Schedules'),
            Tab(text: 'Create'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListTab(),
          _buildCreateTab(),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_schedules.isEmpty) return const Center(child: Text('No schedules found'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _schedules.length,
        itemBuilder: (context, idx) {
          final s = _schedules[idx];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: kRailwayBlue.withOpacity(0.15),
                child: Icon(Icons.schedule, color: kRailwayBlue),
              ),
              title: Text(s.areaName.isNotEmpty ? s.areaName : 'Area: ${s.areaId}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${s.frequencyLabel} | ${s.shift} | ${s.startTime}-${s.endTime}\nEntity: ${s.entityName.isNotEmpty ? s.entityName : s.entityId}\nDays: ${s.daysOfWeek.isEmpty ? "All" : s.daysOfWeek.join(", ")}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateTab() {
    return _ScheduleForm(
      stationId: widget.stationId,
      stationName: widget.stationName,
      areas: _areas,
      onCreated: () {
        _load();
        _tabController.animateTo(0);
      },
    );
  }
}

class _ScheduleForm extends StatefulWidget {
  final String stationId;
  final String stationName;
  final List<StationArea> areas;
  final VoidCallback onCreated;
  const _ScheduleForm({required this.stationId, required this.stationName, required this.areas, required this.onCreated});

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  String? _selectedAreaId;
  String _selectedAreaName = '';
  String? _selectedZoneId;
  CleaningFrequency _frequency = CleaningFrequency.onceDaily;
  String _shift = 'Morning';
  final _entityNameCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController(text: '06:00');
  final _endTimeCtrl = TextEditingController(text: '14:00');
  final List<String> _selectedDays = [];
  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;
  bool _autoGenerate = true;

  List<Map<String, dynamic>> _supervisors = [];
  Map<String, dynamic>? _selectedSupervisor;

  final List<String> _shifts = ['Morning', 'Afternoon', 'Night'];
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadSupervisors();
  }

  Future<void> _loadSupervisors() async {
    try {
      final list = await ApiService.getContractorSupervisors(stationId: widget.stationId);
      if (mounted) setState(() => _supervisors = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load supervisors: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  @override
  void dispose() {
    _entityNameCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  int _estimatedTaskCount() {
    final startHr = int.tryParse(_startTimeCtrl.text.split(':').first) ?? 6;
    final startMin = int.tryParse(_startTimeCtrl.text.split(':').last) ?? 0;
    final endHr = int.tryParse(_endTimeCtrl.text.split(':').first) ?? 14;
    final endMin = int.tryParse(_endTimeCtrl.text.split(':').last) ?? 0;
    final startTotal = startHr * 60 + startMin;
    final endTotal = endHr * 60 + endMin;
    final duration = endTotal - startTotal;
    if (duration <= 0) return 1;

    switch (_frequency) {
      case CleaningFrequency.every15min: return duration ~/ 15;
      case CleaningFrequency.every30min: return duration ~/ 30;
      case CleaningFrequency.hourly: return duration ~/ 60;
      case CleaningFrequency.every2h: return duration ~/ 120;
      case CleaningFrequency.every4h: return duration ~/ 240;
      case CleaningFrequency.every6h: return duration ~/ 360;
      case CleaningFrequency.twiceDaily: return 2;
      case CleaningFrequency.threeTimesDaily: return 3;
      case CleaningFrequency.fourTimesDaily: return 4;
      case CleaningFrequency.sixTimesDaily:
        return [0, 240, 480, 720, 960, 1200].where((m) => m >= startTotal && m < endTotal).length;
      case CleaningFrequency.onceDaily:
      case CleaningFrequency.daily: return 1;
      case CleaningFrequency.hourlyMopping: return 18; // 05:00-23:00 hourly
      default: return 1;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final startHr = int.tryParse(_startTimeCtrl.text.split(':').first) ?? 6;
      final startMin = int.tryParse(_startTimeCtrl.text.split(':').last) ?? 0;
      final endHr = int.tryParse(_endTimeCtrl.text.split(':').first) ?? 14;
      final endMin = int.tryParse(_endTimeCtrl.text.split(':').last) ?? 0;
      final startDt = DateTime(2000, 1, 1, startHr, startMin);
      final endDt = DateTime(2000, 1, 1, endHr, endMin);
      final diff = endDt.difference(startDt);
      final body = {
        'stationId': widget.stationId,
        'stationName': widget.stationName,
        'areaId': _selectedAreaId ?? '',
        'areaName': _selectedAreaName,
        'zoneId': _selectedZoneId ?? '',
        'frequency': _frequency.name,
        'shift': _shift,
        'entityName': _entityNameCtrl.text.trim(),
        'supervisorId': _selectedSupervisor?['uid'] ?? '',
        'supervisorName': _selectedSupervisor?['fullName'] ?? '',
        'startTime': _startTimeCtrl.text.trim(),
        'endTime': _endTimeCtrl.text.trim(),
        'daysOfWeek': _selectedDays,
        'estimatedHours': diff.inHours,
        if (_effectiveFrom != null) 'effectiveFrom': _effectiveFrom!.toIso8601String(),
        if (_effectiveTo != null) 'effectiveTo': _effectiveTo!.toIso8601String(),
      };
      final result = await ApiService.createStationSchedule(body);
      final scheduleUid = result['uid'] ?? result['data']?['uid'];

      if (_autoGenerate && scheduleUid != null) {
        try {
          await ApiService.generateTasksFromSchedule({
            'scheduleId': scheduleUid,
            'date': DateTime.now().toIso8601String().split('T')[0],
            'generateForDays': 1,
          });
        } catch (genErr) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Schedule saved but task generation failed: $genErr'), backgroundColor: Colors.orange),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule created'), backgroundColor: kSuccessGreen),
        );
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  static const _frequencyOptions = [
    CleaningFrequency.onceDaily, CleaningFrequency.twiceDaily,
    CleaningFrequency.threeTimesDaily, CleaningFrequency.fourTimesDaily,
    CleaningFrequency.sixTimesDaily,
    CleaningFrequency.every15min, CleaningFrequency.every30min, CleaningFrequency.hourly,
    CleaningFrequency.every2h, CleaningFrequency.every4h,
    CleaningFrequency.every6h, CleaningFrequency.hourlyMopping,
    CleaningFrequency.twiceWeekly, CleaningFrequency.onceWeekly,
    CleaningFrequency.twiceMonthly, CleaningFrequency.onceMonthly,
    CleaningFrequency.daily, CleaningFrequency.weekly,
    CleaningFrequency.monthly,
  ];

  String _frequencyName(CleaningFrequency f) {
    switch (f) {
      case CleaningFrequency.daily: return 'Daily';
      case CleaningFrequency.weekly: return 'Weekly';
      case CleaningFrequency.monthly: return 'Monthly';
      case CleaningFrequency.every15min: return 'Every 15 min';
      case CleaningFrequency.every30min: return 'Every 30 min';
      case CleaningFrequency.hourly: return 'Every 1 hour';
      case CleaningFrequency.every2h: return 'Every 2 hours';
      case CleaningFrequency.every4h: return 'Every 4 hours';
      case CleaningFrequency.every6h: return 'Every 6 hours';
      case CleaningFrequency.twiceDaily: return 'Two times (day shift)';
      case CleaningFrequency.threeTimesDaily: return 'Three times daily';
      case CleaningFrequency.fourTimesDaily: return 'Four times daily';
      case CleaningFrequency.sixTimesDaily: return 'Six times daily';
      case CleaningFrequency.onceDaily: return 'Once a day';
      case CleaningFrequency.twiceWeekly: return 'Twice a week';
      case CleaningFrequency.onceWeekly: return 'Once a week';
      case CleaningFrequency.twiceMonthly: return 'Twice a month';
      case CleaningFrequency.onceMonthly: return 'Once a month';
      case CleaningFrequency.hourlyMopping: return 'Hourly Mopping';
      default: return f.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskCount = _estimatedTaskCount();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.schedule, color: kRailwayBlue, size: 20),
                      const SizedBox(width: 8),
                      const Text('Schedule Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedAreaId,
                      decoration: const InputDecoration(labelText: 'Area', border: OutlineInputBorder()),
                      items: widget.areas.map((a) => DropdownMenuItem(value: a.uid ?? a.name, child: Text(a.name))).toList()
                        ..insert(0, const DropdownMenuItem(value: null, child: Text('Select Area'))),
                      onChanged: (val) => setState(() {
                        _selectedAreaId = val;
                        _selectedAreaName = widget.areas.firstWhere(
                          (a) => (a.uid ?? a.name) == val,
                          orElse: () => widget.areas.first,
                        ).name;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CleaningFrequency>(
                      value: _frequencyOptions.contains(_frequency) ? _frequency : CleaningFrequency.onceDaily,
                      decoration: const InputDecoration(labelText: 'Cleaning Frequency', border: OutlineInputBorder()),
                      items: _frequencyOptions.map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(_frequencyName(f)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _frequency = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _shift,
                      decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder()),
                      items: _shifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _shift = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startTimeCtrl,
                            decoration: const InputDecoration(labelText: 'Start Time (HH:mm)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.datetime,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _endTimeCtrl,
                            decoration: const InputDecoration(labelText: 'End Time (HH:mm)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.datetime,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.calendar_today, color: kRailwayBlue, size: 20),
                      const SizedBox(width: 8),
                      const Text('Effective Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _effectiveFrom ?? DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _effectiveFrom = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Effective From', border: OutlineInputBorder()),
                              child: Text(_effectiveFrom != null
                                  ? '${_effectiveFrom!.day}/${_effectiveFrom!.month}/${_effectiveFrom!.year}'
                                  : 'Select date'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _effectiveTo ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _effectiveTo = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Effective To', border: OutlineInputBorder()),
                              child: Text(_effectiveTo != null
                                  ? '${_effectiveTo!.day}/${_effectiveTo!.month}/${_effectiveTo!.year}'
                                  : 'No end date'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.business, color: kRailwayBlue, size: 20),
                      const SizedBox(width: 8),
                      const Text('Contractor & Supervisor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _entityNameCtrl,
                      decoration: const InputDecoration(labelText: 'Entity / Contractor Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedSupervisor,
                      decoration: const InputDecoration(labelText: 'Supervisor', border: OutlineInputBorder()),
                      isExpanded: true,
                      items: _supervisors.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s['fullName'] ?? 'Unknown'),
                      )).toList()
                        ..insert(0, const DropdownMenuItem(value: null, child: Text('Select Supervisor'))),
                      onChanged: (val) => setState(() => _selectedSupervisor = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.event, color: kRailwayBlue, size: 20),
                      const SizedBox(width: 8),
                      const Text('Days of Week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _weekDays.map((day) {
                        final selected = _selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: selected,
                          selectedColor: kRailwayBlue.withOpacity(0.2),
                          checkmarkColor: kRailwayBlue,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_selectedDays.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('(All days selected if none chosen)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: kRailwayBlue.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: kRailwayBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Auto-generate tasks for today', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('~$taskCount task(s) per day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoGenerate,
                      onChanged: (val) => setState(() => _autoGenerate = val),
                      activeColor: kRailwayBlue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_isSubmitting ? 'Saving...' : 'Create Schedule',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
