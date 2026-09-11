import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../model/station_models.dart';
import '../../model/platform_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/platform_repository.dart';
import '../../model/railway_worker_model.dart';
import '../../model/station_run_model.dart';
import '../../repositories/station_run_repository.dart';
import '../../repositories/obhs_repository.dart';
import '../../services/api_services.dart';
import '../../utills/app_colors.dart';

class LocalAssignment {
  final String platformNumber;
  final String? platformId;
  final StationArea? area; // Null means Entire Platform
  List<RailwayWorkerModel> workers;

  LocalAssignment({
    required this.platformNumber,
    this.platformId,
    this.area,
    List<RailwayWorkerModel>? workers,
  }) : workers = workers ?? [];
}

class StationCleaningCreateRunScreen extends StatefulWidget {
  final StationCleaningRunModel? editInstance;
  const StationCleaningCreateRunScreen({super.key, this.editInstance});

  @override
  State<StationCleaningCreateRunScreen> createState() => _StationCleaningCreateRunScreenState();
}

class _StationCleaningCreateRunScreenState extends State<StationCleaningCreateRunScreen> {
  bool _isLoading = false;
  List<Station> _stations = [];
  List<Platform> _platforms = [];
  List<StationArea> _allAreas = [];
  List<RailwayWorkerModel> _workers = [];

  Station? _selectedStation;
  Platform? _selectedPlatform;
  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'Morning';

  final List<LocalAssignment> _assignments = [];

  bool get isEdit => widget.editInstance != null;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final stData = await ApiService.getStations();
      final wkData = await OBHSRepository.getWorkers();
      if (mounted) {
        // Deduplicate workers by uid to prevent DropdownButton assertion errors
        final seen = <String>{};
        final uniqueWorkers = wkData.where((w) => seen.add(w.uid)).toList();
        setState(() {
          _stations = stData;
          _workers = uniqueWorkers;
        });

        if (isEdit) {
          final inst = widget.editInstance!;
          _selectedStation = _stations.any((s) => s.uid == inst.stationId)
              ? _stations.firstWhere((s) => s.uid == inst.stationId)
              : (_stations.isNotEmpty ? _stations.first : null);
          
          String rawShift = inst.shift.trim();
          if (rawShift.isNotEmpty) {
            rawShift = rawShift[0].toUpperCase() + rawShift.substring(1).toLowerCase();
          }
          if (['Morning', 'Evening', 'Night'].contains(rawShift)) {
            _selectedShift = rawShift;
          } else {
            _selectedShift = 'Morning';
          }
          try { _selectedDate = DateFormat('yyyy-MM-dd').parse(inst.date); } catch(_) {}
          
          if (_selectedStation != null) {
            await _loadPlatforms(_selectedStation!.uid!);
          }

          // Build local assignments from inst.platforms
          // Group them by platform number and area ID to combine multiple workers
          _assignments.clear();
          for (final plat in inst.platforms) {
            final existingIndex = _assignments.indexWhere((a) =>
                a.platformNumber == plat.platformNumber &&
                a.area?.uid == plat.areaId);
            final worker = _workers.where((w) => w.uid == plat.janitorId).firstOrNull;
            if (existingIndex != -1) {
              if (worker != null && !_assignments[existingIndex].workers.any((w) => w.uid == worker.uid)) {
                _assignments[existingIndex].workers.add(worker);
              }
            } else {
              StationArea? matchedArea = _allAreas.where((a) => a.uid == plat.areaId).firstOrNull;
              _assignments.add(LocalAssignment(
                platformNumber: plat.platformNumber,
                platformId: _platforms.where((p) => p.platformNumber == plat.platformNumber).firstOrNull?.uid,
                area: matchedArea,
                workers: worker != null ? [worker] : [],
              ));
            }
          }
        } else {
          if (_stations.isNotEmpty) {
            final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
            if (user?.stationId != null && user!.stationId!.isNotEmpty) {
              final match = _stations.where((s) => s.uid == user!.stationId).firstOrNull;
              if (match != null) _selectedStation = match;
            }
            _selectedStation ??= _stations.first;
            await _loadPlatforms(_selectedStation!.uid!);
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e'), backgroundColor: kErrorRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlatforms(String stationId) async {
    try {
      final platforms = await PlatformRepository.getByStation(stationId);
      final areas = await ApiService.getStationAreas(stationId);
      if (mounted) {
        setState(() {
          _platforms = platforms;
          _allAreas = areas;
          if (_platforms.isEmpty) {
            _platforms = [
              Platform(uid: 'fallback_p1_${stationId}', platformNumber: '1', stationId: stationId, platformName: 'Platform 1'),
              Platform(uid: 'fallback_p2_${stationId}', platformNumber: '2', stationId: stationId, platformName: 'Platform 2'),
            ];
          }
          _selectedPlatform = _platforms.first;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _platforms = [
            Platform(uid: 'fallback_p1_${stationId}', platformNumber: '1', stationId: stationId, platformName: 'Platform 1'),
            Platform(uid: 'fallback_p2_${stationId}', platformNumber: '2', stationId: stationId, platformName: 'Platform 2'),
          ];
          _selectedPlatform = _platforms.first;
        });
      }
    }
  }



  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _showWorkerSelectionDialog(int assignmentIndex) async {
    final assignment = _assignments[assignmentIndex];
    final selectedWorkers = List<RailwayWorkerModel>.from(assignment.workers);

    final stationWorkers = _selectedStation == null
        ? _workers
        : _workers.where((w) {
            if (w.stationId == _selectedStation!.uid) return true;
            if (w.depot != null && w.depot!.isNotEmpty) {
              final sName = _selectedStation!.stationName.toLowerCase();
              final wDepot = w.depot!.toLowerCase();
              if (sName.contains(wDepot) || wDepot.contains(sName)) return true;
            }
            return false;
          }).toList();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Workers', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select one or more workers to assign to this platform/area.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: stationWorkers.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No workers registered at this station.',
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: stationWorkers.length,
                              itemBuilder: (context, index) {
                                final worker = stationWorkers[index];
                                final isSelected = selectedWorkers.any((w) => w.uid == worker.uid);
                                return CheckboxListTile(
                                  title: Text(worker.fullName),
                                  subtitle: Text(worker.role),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        if (!selectedWorkers.any((w) => w.uid == worker.uid)) {
                                          selectedWorkers.add(worker);
                                        }
                                      } else {
                                        selectedWorkers.removeWhere((w) => w.uid == worker.uid);
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
                      _assignments[assignmentIndex].workers = selectedWorkers;
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

  void _saveRun() async {
    if (_selectedStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a station')));
      return;
    }
    if (_assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please assign at least one platform/area')));
      return;
    }

    final List<StationPlatformAssignment> apiAssignments = [];
    for (final assign in _assignments) {
      if (assign.workers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please assign at least one worker for ${assign.area != null ? assign.area!.name : "Platform " + assign.platformNumber}',
            ),
          ),
        );
        return;
      }
      for (final worker in assign.workers) {
        apiAssignments.add(StationPlatformAssignment(
          platformNumber: assign.platformNumber,
          areaId: assign.area?.uid,
          areaName: assign.area?.name,
          janitorId: worker.uid,
          janitorName: worker.fullName,
        ));
      }
    }

    setState(() => _isLoading = true);
    try {
      final runId = isEdit ? widget.editInstance!.runInstanceId : 'SCR-TEMP';
      final run = StationCleaningRunModel(
        id: widget.editInstance?.id,
        runInstanceId: runId,
        stationId: _selectedStation!.uid ?? '',
        stationName: _selectedStation!.stationName,
        shift: _selectedShift,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        status: isEdit ? widget.editInstance!.status : 'Pending',
        platforms: apiAssignments,
      );

      if (isEdit) {
        await StationRunRepository.updateStationRun(widget.editInstance!.id ?? widget.editInstance!.runInstanceId, run);
      } else {
        await StationRunRepository.createStationRun(run);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully'), backgroundColor: kSuccessGreen));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${isEdit ? 'Edit' : 'Create'} Station Run', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Run Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Station>(
                    value: _selectedStation,
                    decoration: const InputDecoration(labelText: 'Select Station', border: OutlineInputBorder()),
                    items: _stations.map((s) => DropdownMenuItem(value: s, child: Text(s.stationName))).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedStation = v;
                        _assignments.clear();
                      });
                      if (v != null) _loadPlatforms(v.uid!);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                            child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedShift,
                          decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder()),
                          items: ['Morning', 'Evening', 'Night'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => _selectedShift = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Select Platform & Areas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_selectedStation != null) ...[
                    DropdownButtonFormField<Platform>(
                      key: ValueKey('platform_dropdown_${_selectedStation!.uid}'),
                      decoration: const InputDecoration(labelText: 'Select Platform', border: OutlineInputBorder(), prefixIcon: Icon(Icons.view_quilt)),
                      value: _selectedPlatform,
                      items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p.displayName))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedPlatform = v;
                        });
                      },
                    ),
                    if (_selectedPlatform != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Select Areas to Assign:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final platformAreas = _allAreas.where((a) => a.platformId == _selectedPlatform!.uid).toList();
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('Entire Platform / All Areas'),
                                selected: _assignments.any((a) => a.platformId == _selectedPlatform!.uid && a.area == null),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      if (!_assignments.any((a) => a.platformId == _selectedPlatform!.uid && a.area == null)) {
                                        _assignments.add(LocalAssignment(
                                          platformNumber: _selectedPlatform!.platformNumber,
                                          platformId: _selectedPlatform!.uid,
                                          area: null,
                                        ));
                                      }
                                    } else {
                                      _assignments.removeWhere((a) => a.platformId == _selectedPlatform!.uid && a.area == null);
                                    }
                                  });
                                },
                                selectedColor: kRailwayBlue.withOpacity(0.2),
                                checkmarkColor: kRailwayBlue,
                              ),
                              ...platformAreas.map((area) {
                                final isSelected = _assignments.any((a) => a.platformId == _selectedPlatform!.uid && a.area?.uid == area.uid);
                                return FilterChip(
                                  label: Text(area.name),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        if (!isSelected) {
                                          _assignments.add(LocalAssignment(
                                            platformNumber: _selectedPlatform!.platformNumber,
                                            platformId: _selectedPlatform!.uid,
                                            area: area,
                                          ));
                                        }
                                      } else {
                                        _assignments.removeWhere((a) => a.platformId == _selectedPlatform!.uid && a.area?.uid == area.uid);
                                      }
                                    });
                                  },
                                  selectedColor: kRailwayBlue.withOpacity(0.2),
                                  checkmarkColor: kRailwayBlue,
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  const Text('Platform & Worker Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ..._assignments.asMap().entries.map((entry) {
                    int idx = entry.key;
                    LocalAssignment a = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Platform: Platform ${a.platformNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text(
                                        a.area != null ? 'Area: ${a.area!.name}' : 'Area: Entire Platform',
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _assignments.removeAt(idx))),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 4),
                            const Text('Assigned Workers:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 8),
                            if (a.workers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  'No workers assigned yet.',
                                  style: TextStyle(color: kErrorRed.withOpacity(0.8), fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: a.workers.map((w) {
                                  return Chip(
                                    label: Text(w.fullName, style: const TextStyle(fontSize: 11)),
                                    deleteIcon: const Icon(Icons.cancel, size: 14),
                                    onDeleted: () {
                                      setState(() {
                                        a.workers.remove(w);
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.blue.shade50,
                                    side: BorderSide(color: Colors.blue.shade100),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showWorkerSelectionDialog(idx),
                              icon: const Icon(Icons.person_add_alt_1, size: 16),
                              label: const Text('Manage Workers'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kRailwayBlue,
                                side: BorderSide(color: kRailwayBlue.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  if (_assignments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.assignment_ind_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('No platforms or areas added yet.', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveRun,
                      style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Save Run Instance', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
