import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/repositories/worker_repo.dart';
import 'package:crm_train/utills/app_colors.dart';

class ShiftSummaryScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String supervisorId;
  final String supervisorName;
  final String shift;
  final String date;
  final List<Map<String, dynamic>> areas;

  const ShiftSummaryScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.supervisorId,
    required this.supervisorName,
    required this.shift,
    required this.date,
    required this.areas,
  });

  @override
  State<ShiftSummaryScreen> createState() => _ShiftSummaryScreenState();
}

class _AreaEntry {
  final String key;
  final String areaId;
  String areaName;
  String mainArea;
  double basicAreaSqFt;
  int boqTimesPerPeriod;
  double tenderedAreaPerDay;
  String cleaningFrequency;
  final String scheduledTime;
  final String? taskId;
  XFile? photo;
  final TextEditingController remarkCtrl;

  double get workDone => basicAreaSqFt * boqTimesPerPeriod;

  _AreaEntry({
    required this.key,
    required this.areaId,
    this.areaName = '',
    this.mainArea = '',
    this.basicAreaSqFt = 0,
    this.boqTimesPerPeriod = 1,
    this.tenderedAreaPerDay = 0,
    this.cleaningFrequency = 'daily',
    this.scheduledTime = '',
    this.taskId,
    required String remark,
  }) : remarkCtrl = TextEditingController(text: remark);

  void dispose() => remarkCtrl.dispose();
}

class _ShiftSummaryScreenState extends State<ShiftSummaryScreen> {
  final _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _loadingAreas = false;
  List<StationArea> _masterAreas = [];
  late final List<_AreaEntry> _entries;

  static const int _minAreas = 5;

  @override
  void initState() {
    super.initState();
    _entries = widget.areas.map((a) {
      final key = (a['uid'] ?? a['areaId'] ?? a['areaName'] ?? '').toString();
      final master = _findMaster(key, (a['areaName'] ?? '').toString());
      return _AreaEntry(
        key: key.isEmpty ? 'area_${a['areaName']}' : key,
        areaId: (a['areaId'] ?? a['uid'] ?? '').toString(),
        areaName: (a['areaName'] ?? master?.name ?? '').toString(),
        mainArea: (a['mainArea'] ?? master?.mainArea ?? '').toString(),
        basicAreaSqFt: (a['basicAreaSqFt'] ?? master?.basicAreaSqFt ?? 0).toDouble(),
        boqTimesPerPeriod: (a['boqTimesPerPeriod'] ?? master?.boqTimesPerPeriod ?? 1).toInt(),
        tenderedAreaPerDay: (a['tenderedAreaPerDay'] ?? master?.tenderedAreaPerDay ?? 0).toDouble(),
        cleaningFrequency: (a['cleaningFrequency'] ?? master?.cleaningFrequency ?? 'daily').toString(),
        scheduledTime: (a['scheduledTime'] ?? '').toString(),
        taskId: a['uid']?.toString() ?? a['taskId']?.toString(),
        remark: (a['remark'] ?? '').toString(),
      );
    }).toList();
    _loadMasterAreas();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  StationArea? _findMaster(String id, String name) {
    if (id.isEmpty && name.isEmpty) return null;
    final byId = _masterAreas.where((m) => m.uid == id).toList();
    if (byId.isNotEmpty) return byId.first;
    return _masterAreas.where((m) => m.name.toLowerCase() == name.toLowerCase()).toList().firstOrNull;
  }

  Future<void> _loadMasterAreas() async {
    setState(() => _loadingAreas = true);
    try {
      final areas = await ApiService.getStationAreas(widget.stationId);
      if (!mounted) return;
      setState(() {
        _masterAreas = areas;
        for (final e in _entries) {
          final m = _findMaster(e.areaId.isNotEmpty ? e.areaId : e.key, e.areaName);
          if (m != null) {
            e
              ..areaName = m.name
              ..mainArea = m.mainArea ?? e.mainArea
              ..basicAreaSqFt = e.basicAreaSqFt > 0 ? e.basicAreaSqFt : (m.basicAreaSqFt ?? 0)
              ..boqTimesPerPeriod = e.boqTimesPerPeriod > 0 ? e.boqTimesPerPeriod : (m.boqTimesPerPeriod ?? 1)
              ..tenderedAreaPerDay = e.tenderedAreaPerDay > 0 ? e.tenderedAreaPerDay : (m.tenderedAreaPerDay ?? 0)
              ..cleaningFrequency = e.cleaningFrequency != 'daily' ? e.cleaningFrequency : (m.cleaningFrequency ?? 'daily');
          }
        }
      });
    } catch (_) {
      // Master areas are optional enrichment; proceed with provided values.
    } finally {
      if (mounted) setState(() => _loadingAreas = false);
    }
  }

  List<StationArea> get _availableMasterAreas {
    final selectedKeys = _entries.map((e) => e.areaId.isNotEmpty ? e.areaId : e.key).toSet();
    return _masterAreas.where((m) => !selectedKeys.contains(m.uid)).toList();
  }

  int get _takenCount => _entries.where((e) => e.photo != null).length;
  int get _remarkCount => _entries.where((e) => e.remarkCtrl.text.trim().isNotEmpty).length;
  double get _totalWorkDone => _entries.fold(0, (sum, e) => sum + e.workDone);

  bool get _canSubmit => _entries.length >= _minAreas && _takenCount == _entries.length && _remarkCount == _entries.length;

  Future<void> _takePhoto(_AreaEntry entry) async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1280);
    if (photo != null) {
      setState(() => entry.photo = photo);
    }
  }

  Future<void> _addArea() async {
    final available = _availableMasterAreas;
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No additional areas available'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    final selected = await showModalBottomSheet<StationArea>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select an area', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          ...available.map((m) => ListTile(
            leading: const Icon(Icons.cleaning_services, color: kRailwayBlue),
            title: Text(m.name),
            subtitle: m.mainArea != null && m.mainArea!.isNotEmpty ? Text(m.mainArea!) : null,
            trailing: m.basicAreaSqFt != null
                ? Text('${m.basicAreaSqFt!.round()} sqft', style: TextStyle(color: Colors.grey[600]))
                : null,
            onTap: () => Navigator.pop(ctx, m),
          )),
        ],
      ),
    );
    if (selected == null) return;
    setState(() {
      _entries.add(_AreaEntry(
        key: selected.uid ?? selected.name,
        areaId: selected.uid ?? '',
        areaName: selected.name,
        mainArea: selected.mainArea ?? '',
        basicAreaSqFt: selected.basicAreaSqFt ?? 0,
        boqTimesPerPeriod: selected.boqTimesPerPeriod ?? 1,
        tenderedAreaPerDay: selected.tenderedAreaPerDay ?? 0,
        cleaningFrequency: selected.cleaningFrequency ?? 'daily',
        remark: '',
      ));
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      final areasPayload = <Map<String, dynamic>>[];
      for (final e in _entries) {
        final photoUrl = await WorkerRepository.uploadMedia(e.photo!.path);
        areasPayload.add({
          'areaId': e.areaId.isNotEmpty ? e.areaId : e.key,
          'areaName': e.areaName,
          'mainArea': e.mainArea,
          'basicAreaSqFt': e.basicAreaSqFt,
          'boqTimesPerPeriod': e.boqTimesPerPeriod,
          'cleaningFrequency': e.cleaningFrequency,
          'tenderedAreaPerDay': e.tenderedAreaPerDay,
          'photoUrl': photoUrl,
          'remark': e.remarkCtrl.text.trim(),
          'scheduledTime': e.scheduledTime,
          'taskId': e.taskId,
        });
      }

      await ApiService.submitShiftSummary({
        'supervisorId': widget.supervisorId,
        'supervisorName': widget.supervisorName,
        'stationId': widget.stationId,
        'stationName': widget.stationName,
        'date': widget.date,
        'shift': widget.shift,
        'areas': areasPayload,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift summary submitted for approval!'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shift Summary — ${widget.stationName}'),
        backgroundColor: kRailwayBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: kRailwayBlue.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.shift} Shift — ${widget.date}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${_entries.length} area(s) selected (min $_minAreas) — $_takenCount photos, $_remarkCount remarks',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('Total Work Done: ${_totalWorkDone.toStringAsFixed(0)} sqft',
                    style: TextStyle(color: const Color(0xFF1B5E20), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: _loadingAreas
                        ? const CircularProgressIndicator()
                        : const Text('No areas selected'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    itemBuilder: (ctx, i) => _buildAreaCard(_entries[i]),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_availableMasterAreas.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Area'),
                        onPressed: _isSubmitting ? null : _addArea,
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle),
                      label: Text(_isSubmitting
                          ? 'Submitting...'
                          : _entries.length < _minAreas
                              ? 'Select ${_minAreas - _entries.length} more area(s)'
                              : (_takenCount < _entries.length || _remarkCount < _entries.length)
                                  ? 'Add ${(_entries.length - _takenCount) + (_entries.length - _remarkCount)} missing photo/remark(s)'
                                  : 'Submit Summary ($_takenCount areas)'),
                      onPressed: (_canSubmit && !_isSubmitting) ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSuccessGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(_AreaEntry entry) {
    final photo = entry.photo;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cleaning_services, size: 20, color: kRailwayBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.areaName.isEmpty ? 'Unnamed Area' : entry.areaName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (entry.scheduledTime.isNotEmpty)
                  Text(entry.scheduledTime, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            if (entry.mainArea.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(entry.mainArea, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Work: ${entry.basicAreaSqFt.toStringAsFixed(0)} sqft × ${entry.boqTimesPerPeriod}x (${entry.cleaningFrequency}) = ${entry.workDone.toStringAsFixed(0)} sqft',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            if (photo != null)
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(image: FileImage(File(photo.path)), fit: BoxFit.cover),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, size: 36, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Photo required — tap to take', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(photo != null ? Icons.refresh : Icons.camera_alt, size: 16),
                    label: Text(photo != null ? 'Retake' : 'Take Photo'),
                    onPressed: () => _takePhoto(entry),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: photo != null ? Colors.green[800] : kRailwayBlue,
                      backgroundColor: photo != null ? Colors.green[50] : null,
                    ),
                  ),
                ),
                if (_entries.length > _minAreas) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => setState(() {
                      entry.dispose();
                      _entries.remove(entry);
                    }),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: entry.remarkCtrl,
              minLines: 2,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Remark (required)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
