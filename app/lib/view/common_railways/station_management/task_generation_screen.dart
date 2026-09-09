import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/model/station_run_model.dart';
import 'package:crm_train/repositories/station_run_repository.dart';
import 'package:crm_train/repositories/obhs_repository.dart';
import 'package:crm_train/repositories/area_cleaning_repository.dart';
import 'package:crm_train/model/railway_worker_model.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/model/task_type_model.dart';
import 'package:crm_train/repositories/task_type_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:intl/intl.dart';

// Fallback cleaning activities used when the backend task-types endpoint is
// unavailable or returns nothing. Kept in sync with the seeded task types.
const List<Map<String, String>> _defaultCleaningActivities = [
  {'name': 'sweeping', 'label': 'Sweeping'},
  {'name': 'mopping', 'label': 'Mopping'},
  {'name': 'washing', 'label': 'Washing'},
  {'name': 'rag_picking', 'label': 'Rag Picking'},
  {'name': 'garbage_collection', 'label': 'Garbage Collection'},
  {'name': 'garbage_disposal', 'label': 'Garbage Disposal'},
  {'name': 'drain_cleaning', 'label': 'Drain Cleaning'},
  {'name': 'consumable_refill', 'label': 'Consumable Refill'},
  {'name': 'cobweb_removal', 'label': 'Cobweb Removal'},
  {'name': 'deep_cleaning', 'label': 'Deep Cleaning'},
];

List<TaskType> _defaultActivities() => _defaultCleaningActivities
    .map((a) => TaskType(
          uid: a['name']!,
          name: a['name']!,
          label: a['label']!,
          createdAt: '',
          updatedAt: '',
        ))
    .toList();

class TaskGenerationScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;
  const TaskGenerationScreen({super.key, this.stationId, this.stationName});

  @override
  State<TaskGenerationScreen> createState() => _TaskGenerationScreenState();
}

class _TaskGenerationScreenState extends State<TaskGenerationScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Station> _stations = [];
  List<StationArea> _allAreas = [];
  List<RailwayWorkerModel> _supervisors = [];
  List<TaskType> _taskTypes = [];

  Station? _selectedStation;
  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'Morning';
  RailwayWorkerModel? _selectedSupervisor;

  bool _isStationLocked = false;

  // Generation mode: occurrences (per-area count control) vs "By Frequency"
  // (derive slots directly from each area's configured frequency/times).
  bool _byFrequency = false;

  // Selected areas and per-area activities
  final Set<String> _selectedAreaIds = {};
  final Map<String, List<TaskType>> _areaActivities = {};
  // Per-area "how many occurrences to schedule today" (1..area daily total)
  final Map<String, int> _areaTodayCount = {};

  // Per-area frequency progress (total/used/remaining occurrences for the date)
  final Map<String, Map<String, dynamic>> _areaFrequencyStatus = {};
  bool _frequencyStatusLoading = false;

  String? _loadError;
  bool _areaLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final role = user?.role ?? '';

      final userStationIds = <String>{};
      if (user?.stationId != null && user!.stationId!.isNotEmpty) {
        userStationIds.add(user.stationId!);
      }
      if (user?.stations != null && user!.stations.isNotEmpty) {
        userStationIds.addAll(user.stations);
      }

      final contractorRole = role == 'Contractor Admin' || role == 'Contractor Master';
      final lockedStationId = widget.stationId ?? (contractorRole && userStationIds.length == 1 ? userStationIds.first : null);

      final results = await Future.wait<Object>([
        _loadStations(lockedStationId, contractorRole, userStationIds),
        _loadSupervisors(lockedStationId),
        _loadTaskTypes(),
      ]);

      final stations = results[0] as List<Station>;
      final supervisors = results[1] as List<RailwayWorkerModel>;
      final taskTypes = results[2] as List<TaskType>;

      if (mounted) {
        setState(() {
          _stations = stations;
          _supervisors = supervisors;
          _taskTypes = taskTypes;
          _isStationLocked = lockedStationId != null;
          if (_stations.isNotEmpty) {
            if (widget.stationId != null) {
              _selectedStation = _stations.where((s) => s.uid == widget.stationId).firstOrNull ?? _stations.first;
            } else if (user?.stationId != null && user!.stationId!.isNotEmpty) {
              _selectedStation = _stations.where((s) => s.uid == user.stationId).firstOrNull;
            }
            _selectedStation ??= _stations.first;
          }
        });
        if (_selectedStation != null) {
          await _loadAreas(_selectedStation!.uid!);
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fetch only the assigned station(s) instead of pulling every station in the system.
  Future<List<Station>> _loadStations(String? lockedStationId, bool contractorRole, Set<String> userStationIds) async {
    try {
      if (lockedStationId != null) {
        return [await ApiService.getStationById(lockedStationId)];
      }
      // Multi-station contractor: fetch their assigned stations individually.
      if (contractorRole && userStationIds.isNotEmpty) {
        final stations = <Station>[];
        for (final id in userStationIds) {
          try {
            stations.add(await ApiService.getStationById(id));
          } catch (_) {
            // Skip stations that cannot be resolved individually.
          }
        }
        if (stations.isNotEmpty) return stations;
      }
      final stData = await ApiService.getStations(active: true);
      if (contractorRole && userStationIds.isNotEmpty) {
        return stData.where((s) => s.uid != null && userStationIds.contains(s.uid)).toList();
      }
      return stData;
    } catch (e) {
      debugPrint('Error loading stations: $e');
      if (mounted) {
        setState(() => _loadError = 'Failed to load stations. Check your connection and try again.');
      }
      return <Station>[];
    }
  }

  // Contractor supervisors scoped server-side to the requester's entity (and station when locked).
  Future<List<RailwayWorkerModel>> _loadSupervisors(String? lockedStationId) async {
    try {
      final supList = await OBHSRepository.getContractorSupervisors(stationId: lockedStationId);
      final seen = <String>{};
      return supList.where((w) => seen.add(w.uid)).toList();
    } catch (e) {
      debugPrint('Error loading contractor supervisors: $e');
      try {
        final wkData = await OBHSRepository.getWorkers();
        final seen = <String>{};
        final uniqueWorkers = wkData.where((w) => seen.add(w.uid)).toList();
        return uniqueWorkers.where((w) {
          final role = w.role.toLowerCase().replaceAll('_', ' ');
          return role.contains('contractor supervisor') && w.status == 'APPROVED';
        }).toList();
      } catch (e2) {
        debugPrint('Error loading workers fallback: $e2');
        return <RailwayWorkerModel>[];
      }
    }
  }

  Future<List<TaskType>> _loadTaskTypes() async {
    try {
      final taskTypes = await TaskTypeRepository.list(category: 'cleaning', isActive: true);
      return taskTypes.isNotEmpty ? taskTypes : _defaultActivities();
    } catch (e) {
      debugPrint('Error loading task types: $e');
      return _defaultActivities();
    }
  }

  Future<void> _loadAreas(String stationId) async {
    try {
      final areas = await ApiService.getStationAreas(stationId);
      if (mounted) {
        setState(() {
          _allAreas = areas;
          _areaLoadFailed = false;
          _selectedAreaIds.clear();
          _areaActivities.clear();
          _areaTodayCount.clear();
        });
        await _loadFrequencyStatus();
      }
    } catch (e) {
      debugPrint('Error loading areas: $e');
      if (mounted) {
        setState(() {
          _allAreas = [];
          _areaLoadFailed = true;
          _selectedAreaIds.clear();
          _areaActivities.clear();
          _areaTodayCount.clear();
        });
      }
    }
  }

  Future<void> _loadFrequencyStatus() async {
    final station = _selectedStation;
    if (station == null || station.uid == null) return;
    final areaIds = _allAreas
        .where((a) => a.uid != null && a.uid!.isNotEmpty)
        .map((a) => a.uid!)
        .toList();
    if (areaIds.isEmpty) return;
    setState(() => _frequencyStatusLoading = true);
    try {
      final status = await AreaCleaningRepository.getFrequencyStatus(
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        areaIds: areaIds,
      );
      if (mounted) {
        setState(() {
          final casted = status.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
          final seeded = <String, Map<String, dynamic>>{};
          for (final a in _allAreas) {
            final id = a.uid;
            if (id == null || id.isEmpty) continue;
            final existing = casted[id];
            if (existing != null) {
              seeded[id] = existing;
            } else {
              final def = _defaultFrequencyForArea(a);
              seeded[id] = {
                'areaId': id,
                'frequency': a.cleaningFrequency ?? 'daily',
                'totalTimes': def,
                'usedTimes': 0,
                'remainingTimes': def,
                'frequencyTimes': <String>[],
                'scheduledTimes': <String>[],
              };
            }
          }
          _areaFrequencyStatus
            ..clear()
            ..addAll(seeded);
        });
      }
    } catch (e) {
      debugPrint('Error loading frequency status: $e');
    } finally {
      if (mounted) setState(() => _frequencyStatusLoading = false);
    }
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'daily': return 'Daily (1x)';
      case 'twice_daily': return 'Twice Daily (2x)';
      case 'shift_wise': return 'Shift Wise (3x)';
      case 'four_times_daily': return 'Four Times (4x)';
      case '4hrs': return 'Every 4 Hours (5x)';
      case 'hourly': return 'Hourly (17x)';
      case '2hrs': return 'Every 2 Hours';
      case 'weekly': return 'Weekly';
      case 'fortnightly': return 'Fortnightly';
      case 'monthly': return 'Monthly';
      default: return f;
    }
  }

int _defaultFrequencyForArea(StationArea area) {
    final boq = area.boqTimesPerPeriod;
    if (boq != null && boq > 0) return boq;
    switch ((area.cleaningFrequency ?? 'daily').toLowerCase()) {
      case 'twice_daily':
      case 'twice_daily_shift':
      case 'two_times_daily':
        return 2;
      case 'shift_wise':
      case 'three_times_daily':
        return 3;
      case 'four_times_daily':
        return 4;
      case '4hrs':
      case 'once_every_4h':
        return 5;
      case 'hourly':
        return 12;
      default:
        return 1;
    }
  }

  List<String> _usedSlotsFor(String areaId) {
    final status = _areaFrequencyStatus[areaId];
    final times = status?['scheduledTimes'];
    if (times is List) return times.map((t) => t.toString()).toList();
    return const [];
  }

  int _todayCountForArea(StationArea area) {
    final areaId = area.uid ?? area.name;
    final stored = _areaTodayCount[areaId];
    if (stored != null) return stored;
    final status = _areaFrequencyStatus[areaId];
    final used = (status?['usedTimes'] as int?) ?? 0;
    final def = _defaultFrequencyForArea(area);
    return (used > 0 ? used : 1).clamp(1, def);
  }

  Widget _buildFrequencyAssignRow(StationArea area) {
    final areaId = area.uid ?? area.name;
    final status = _areaFrequencyStatus[areaId];
    final total = (status?['totalTimes'] as int?) ?? 0;
    final effectiveTotal = total > 0 ? total : _defaultFrequencyForArea(area);
    final used = (status?['usedTimes'] as int?) ?? 0;
    final remaining = status == null
        ? effectiveTotal
        : ((status['remainingTimes'] as int?) ?? (effectiveTotal - used));
    final hasSupervisor = _selectedSupervisor != null;
    final todayCount = _todayCountForArea(area);

    if (_byFrequency) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kRailwayBlue.withOpacity(0.04),
          border: Border.all(color: kRailwayBlue.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: kRailwayBlue),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto \u00b7 ${_frequencyLabel(area.cleaningFrequency ?? 'daily')} \u00b7 $effectiveTotal time(s)/day',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasSupervisor ? 'Assigned to: ${_selectedSupervisor!.fullName}' : 'Select a supervisor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: hasSupervisor ? FontWeight.w400 : FontWeight.w600,
                      color: hasSupervisor ? Colors.black54 : kRailwayBlue,
                    ),
                  ),
                ],
              ),
            ),
            if (_frequencyStatusLoading)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kRailwayBlue.withOpacity(0.04),
        border: Border.all(color: kRailwayBlue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.repeat, size: 16, color: kRailwayBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Total/day: $effectiveTotal · Used: $used · Remaining: $remaining',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
              if (_frequencyStatusLoading)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 6),
          if (used > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Used slots: ${_usedSlotsFor(areaId).join(' · ')}',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Icon(Icons.event, size: 16, color: kRailwayBlue),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Occurrences today',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
                color: kRailwayBlue,
                onPressed: todayCount > 1
                    ? () => setState(() => _areaTodayCount[areaId] = todayCount - 1)
                    : null,
              ),
              Text('$todayCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
                color: kRailwayBlue,
                onPressed: todayCount < effectiveTotal
                    ? () => setState(() => _areaTodayCount[areaId] = todayCount + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.supervisor_account, size: 16, color: hasSupervisor ? kRailwayBlue : Colors.grey[400]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasSupervisor
                      ? 'Generate will set $todayCount of $effectiveTotal for ${_selectedSupervisor!.fullName} today'
                      : 'Select a supervisor',
                  style: TextStyle(fontSize: 12, color: hasSupervisor ? Colors.grey[700] : Colors.grey[500]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _areaTodayCount.clear();
      });
      await _loadFrequencyStatus();
    }
  }

  void _toggleAreaSelection(StationArea area) {
    final areaId = area.uid ?? area.name;
    if (_selectedAreaIds.contains(areaId)) {
      setState(() {
        _selectedAreaIds.remove(areaId);
        _areaActivities.remove(areaId);
        _areaTodayCount.remove(areaId);
      });
      return;
    }
    setState(() {
      _selectedAreaIds.add(areaId);
      _areaActivities[areaId] = [];
    });
    _loadFrequencyStatus();
  }

  Future<void> _showActivitySelectionForArea(StationArea area) async {
    final areaId = area.uid ?? area.name;
    final selected = List<TaskType>.from(_areaActivities[areaId] ?? []);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select Activities: ${area.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tick one or more activities to do in this area.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: _taskTypes.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No activities available.',
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _taskTypes.length,
                              itemBuilder: (context, index) {
                                final tt = _taskTypes[index];
                                final isChecked = selected.any((t) => t.uid == tt.uid || t.name == tt.name);
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(tt.label),
                                  value: isChecked,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        if (!selected.any((t) => t.uid == tt.uid || t.name == tt.name)) {
                                          selected.add(tt);
                                        }
                                      } else {
                                        selected.removeWhere((t) => t.uid == tt.uid || t.name == tt.name);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _areaActivities[areaId] = List<TaskType>.from(selected);
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateTasks() async {
    if (_selectedStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a station')));
      return;
    }
    if (_selectedAreaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one area')));
      return;
    }
    if (_selectedSupervisor == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a supervisor. Generated tasks are assigned to the contractor supervisor who completes them.'),
            backgroundColor: kWarningOrange,
          ),
        );
      }
      return;
    }

    final missingActivities = _selectedAreaIds.where((a) {
      final acts = _areaActivities[a] ?? const <TaskType>[];
      return acts.isEmpty;
    }).map((a) {
      final area = _allAreas.where((x) => (x.uid ?? x.name) == a).firstOrNull;
      return area?.name ?? a;
    }).toList();
    if (!_byFrequency && missingActivities.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Select at least one activity for: ${missingActivities.join(', ')}. Tasks cannot be generated without an activity.'),
            backgroundColor: kWarningOrange,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Preserve the existing per-shift run-instance record for the
      // occurrences flow (used by attendance); skipped in "By Frequency" mode.
      if (!_byFrequency) {
        final runInstanceId = '${_selectedStation!.uid}_${_selectedShift.toLowerCase()}_$todayStr';
        final run = StationCleaningRunModel(
          runInstanceId: runInstanceId,
          stationId: _selectedStation!.uid ?? '',
          stationName: _selectedStation!.stationName,
          shift: _selectedShift,
          date: todayStr,
          status: 'Pending',
          platforms: const [],
        );
        await StationRunRepository.createStationRun(run);
      }

      // Per-area activities: each selected area -> list of chosen activities.
      // Skipped in "By Frequency" mode — slots come from the area's frequency.
      final areaActivities = <String, List<Map<String, dynamic>>>{};
      if (!_byFrequency) {
        for (final entry in _areaActivities.entries) {
          if (entry.value.isEmpty) continue;
          areaActivities[entry.key] = entry.value
              .map((t) => {'uid': t.uid, 'name': t.name, 'label': t.label})
              .toList();
        }
      }

      // Per-area "Occurrences today" count is authoritative: the backend
      // normalizes today's tasks to exactly this many occurrences.
      final areaTimes = <String, int>{};
      if (!_byFrequency && _selectedSupervisor != null) {
        for (final areaId in _selectedAreaIds) {
          final area = _allAreas.where((a) => (a.uid ?? a.name) == areaId).firstOrNull;
          if (area == null) continue;
          final desired = _todayCountForArea(area);
          if (desired > 0) areaTimes[areaId] = desired;
        }
        if (!_byFrequency && areaTimes.isEmpty) {
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Set the occurrences for at least one selected area.'),
                backgroundColor: kWarningOrange,
              ),
            );
          }
          return;
        }
      }

      final result = await AreaCleaningRepository.generateTasks(
        areaIds: _selectedAreaIds.toList(),
        date: todayStr,
        supervisorId: _selectedSupervisor?.uid,
        areaActivities: areaActivities.isNotEmpty ? areaActivities : null,
        areaTimes: areaTimes.isNotEmpty ? areaTimes : null,
        normalize: true,
      );

      if (mounted) {
        final created = ((result['count'] as num?) ?? 0).toInt();
        final cancelled = ((result['cancelled'] as num?) ?? 0).toInt();
        final msg = created > 0
            ? 'Tasks generated successfully! $created created'
            : (cancelled > 0 ? 'Frequency adjusted: $cancelled extra task(s) cancelled' : 'Already up to date');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: kSuccessGreen,
          ),
        );
        await _loadFrequencyStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating tasks: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = _allAreas;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Generate Tasks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_stations.isEmpty)
              ? _LoadFailureView(
                  message: _loadError ?? 'No stations available for your account.',
                  onRetry: () {
                    _loadInitialData();
                  },
                )
              : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Location & Schedule Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.map, color: kRailwayBlue, size: 20),
                              const SizedBox(width: 8),
                              const Text('Location & Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Station Dropdown
                          DropdownButtonFormField<Station>(
                            value: _selectedStation,
                            decoration: InputDecoration(
                              labelText: 'Station',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.business),
                              hintText: _isStationLocked ? 'Assigned Station (locked)' : null,
                            ),
                            items: _stations.map((s) => DropdownMenuItem(value: s, child: Text(s.stationName))).toList(),
                            onChanged: _isStationLocked ? null : (v) async {
                              if (v != null) {
                                setState(() {
                                  _selectedStation = v;
                                  _selectedAreaIds.clear();
                                  _areaActivities.clear();
          _areaTodayCount.clear();
                                });
                                await _loadAreas(v.uid!);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Date & Shift side by side
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                                    child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedShift,
                                  decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder(), prefixIcon: Icon(Icons.schedule)),
                                  items: ['Morning', 'Evening', 'Night'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedShift = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Cleaning Setup Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cleaning_services, color: kRailwayBlue, size: 20),
                              const SizedBox(width: 8),
                              const Text('Cleaning Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Supervisor Assignment
                          DropdownButtonFormField<RailwayWorkerModel>(
                            value: _selectedSupervisor,
                            decoration: const InputDecoration(
                              labelText: 'Assign to Supervisor',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.supervisor_account),
                            ),
                            items: [
                              const DropdownMenuItem<RailwayWorkerModel>(
                                value: null,
                                child: Text('None'),
                              ),
                              ..._supervisors.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.fullName),
                              )),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedSupervisor = v);
                            },
                          ),
                          const SizedBox(height: 12),

                          // Generation Mode
                          Row(
                            children: [
                              const Icon(Icons.tune, color: kRailwayBlue, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Generation Mode',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Occurrences'),
                                icon: Icon(Icons.repeat, size: 18),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('By Frequency'),
                                icon: Icon(Icons.auto_awesome, size: 18),
                              ),
                            ],
                            selected: {_byFrequency},
                            onSelectionChanged: (v) => setState(() => _byFrequency = v.first),
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: kRailwayBlue,
                              selectedForegroundColor: Colors.white,
                            ),
                          ),
                          if (_byFrequency)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Tasks will use each area\u2019s configured cleaning frequency and times automatically.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.dashboard_outlined, color: kRailwayBlue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Select Areas (${_selectedAreaIds.length} selected)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap an area to select it, then tick the activities for that area.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          if (areas.isEmpty)
                            _areaLoadFailed
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 24),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Failed to load areas. Please retry.',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton.icon(
                                            onPressed: () => _loadAreas(_selectedStation?.uid ?? ''),
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: Text('No areas configured for this selection', style: TextStyle(color: Colors.grey)),
                                    ),
                                  )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: areas.length,
                              itemBuilder: (context, index) {
                                final area = areas[index];
                                final areaId = area.uid ?? area.name;
                                final isSelected = _selectedAreaIds.contains(areaId);
                                final List<TaskType> areaActivities = _areaActivities[areaId] ?? [];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isSelected ? kRailwayBlue : Colors.grey.shade300, width: isSelected ? 1.5 : 1),
                                    borderRadius: BorderRadius.circular(10),
                                    color: isSelected ? kRailwayBlue.withOpacity(0.04) : Colors.white,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () => _toggleAreaSelection(area),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Icon(
                                                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                                  color: isSelected ? kRailwayBlue : Colors.grey.shade400,
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (area.mainArea != null && area.mainArea!.isNotEmpty)
                                                      Text(
                                                        area.mainArea!,
                                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                                      ),
                                                    if (area.mainArea != null && area.mainArea!.isNotEmpty)
                                                      const SizedBox(height: 2),
                                                    Text(
                                                      area.name,
                                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          _frequencyLabel(area.cleaningFrequency ?? 'daily'),
                                                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const Divider(height: 1),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              _buildFrequencyAssignRow(area),
                                              if (!_byFrequency) ...[
                                                const SizedBox(height: 12),
                                                InkWell(
                                                  onTap: () => _showActivitySelectionForArea(area),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: kRailwayBlue.withOpacity(0.4)),
                                                      borderRadius: BorderRadius.circular(8),
                                                      color: kRailwayBlue.withOpacity(0.05),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.cleaning_services, size: 16, color: kRailwayBlue),
                                                            const SizedBox(width: 6),
                                                            Expanded(
                                                              child: Text(
                                                                'Select Activities',
                                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                                              ),
                                                            ),
                                                            Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          areaActivities.isEmpty
                                                              ? 'Tap to choose the activities for this area'
                                                              : areaActivities.map((t) => t.label).join(' · '),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: areaActivities.isEmpty ? Colors.grey[600] : Colors.black87,
                                                            fontStyle: areaActivities.isEmpty ? FontStyle.italic : FontStyle.normal,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Generate Tasks Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _generateTasks,
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isSubmitting ? 'Generating...' : '+ Generate Tasks (${_selectedAreaIds.length} areas)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRailwayBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LoadFailureView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadFailureView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
