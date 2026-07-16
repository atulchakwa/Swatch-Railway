import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

class StationCleaningFormScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final StationCleaningForm? existing;
  const StationCleaningFormScreen({super.key, required this.stationId, required this.stationName, this.existing});

  @override
  State<StationCleaningFormScreen> createState() => _StationCleaningFormScreenState();
}

class _StationCleaningFormScreenState extends State<StationCleaningFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _areasLoading = false;
  bool _zonesLoading = false;
  List<StationArea> _areas = [];
  List<StationZone> _zones = [];

  // Worker assignment
  String? _workerName;
  String? _workerRole;
  String? _workerAreaId;
  String? _workerPlatformId;

  bool get _isWorkerRole {
    final r = (_workerRole ?? '').toUpperCase().replaceAll(' ', '_');
    return ['WORKER', 'RAILWAY_WORKER', 'JANITOR', 'ATTENDANT'].contains(r);
  }

  late TextEditingController _manpowerCtrl;
  late TextEditingController _machineCtrl;
  late TextEditingController _areaCoveredCtrl;
  late TextEditingController _areaUncleanedCtrl;
  late TextEditingController _garbageCtrl;
  late TextEditingController _remarksCtrl;

  String? _selectedArea;
  String? _selectedZone;
  String _selectedShift = 'morning';
  DateTime _selectedDate = DateTime.now();
  String _startTime = '';
  String _endTime = '';
  final Set<String> _selectedActivities = {};
  final List<String> _beforePhotos = [];
  final List<String> _afterPhotos = [];
  bool _uploadingPhoto = false;

  String? _formUid;

  StationCleaningForm? get _form => widget.existing;

  bool get isEdit => _form != null;
  bool get isEditable => _form == null || _form!.status == StationFormStatus.draft;

  static const List<Map<String, dynamic>> scoringCriteria = [
    {'name': 'Platform & Track Cleaning', 'max': 25},
    {'name': 'Waiting Hall & Amenities', 'max': 20},
    {'name': 'Washroom & Water Booth', 'max': 20},
    {'name': 'Garbage Disposal', 'max': 15},
    {'name': 'Pest Control', 'max': 10},
    {'name': 'Overall Presentation', 'max': 10},
  ];

  final Map<String, double> _scores = {};

  @override
  void initState() {
    super.initState();
    _manpowerCtrl = TextEditingController(text: _form?.manpowerCount.toString() ?? '');
    _machineCtrl = TextEditingController(text: _form?.machineCount.toString() ?? '');
    _areaCoveredCtrl = TextEditingController(text: _form?.areaCovered.toString() ?? '');
    _areaUncleanedCtrl = TextEditingController(text: _form?.areaUncleaned.toString() ?? '');
    _garbageCtrl = TextEditingController(text: _form?.garbageCollected.toString() ?? '');
    _remarksCtrl = TextEditingController(text: _form?.remarks ?? '');
    if (_form != null) {
      _selectedArea = _form!.areaName;
      _selectedZone = _form!.zoneName;
      _selectedShift = _form!.shift;
      if (_form!.cleaningDate.isNotEmpty) _selectedDate = DateTime.tryParse(_form!.cleaningDate) ?? DateTime.now();
      _startTime = _form!.startTime;
      _endTime = _form!.endTime;
      for (final a in _form!.activities) _selectedActivities.add(a);
      _formUid = _form!.uid;
      for (final c in scoringCriteria) _scores[c['name']] = 0;
      if (_form!.scoringData != null) {
        final criteriaList = _form!.scoringData!['criteria'] as List? ?? [];
        for (final c in criteriaList) {
          _scores[c['name']] = (c['score'] ?? 0).toDouble();
        }
      }
    } else {
      for (final c in scoringCriteria) _scores[c['name']] = 0;
    }
    // Read current user info after first frame so context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        setState(() {
          _workerName = user.fullName;
          _workerRole = user.role;
          _workerAreaId = user.areaId;
          _workerPlatformId = user.platformId;
        });
      }
      _loadAreas();
    });
  }

  @override
  void dispose() {
    _manpowerCtrl.dispose();
    _machineCtrl.dispose();
    _areaCoveredCtrl.dispose();
    _areaUncleanedCtrl.dispose();
    _garbageCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    _areas = [];
    _zones = [];
    _selectedArea = null;
    _selectedZone = null;
    _areasLoading = true;
    if (mounted) setState(() {});
    try {
      final allAreas = await ApiService.getStationAreas(widget.stationId);
      if (_isWorkerRole && (_workerAreaId != null || _workerPlatformId != null)) {
        // Filter to only the worker's assigned area/platform
        final assignedId = _workerAreaId ?? _workerPlatformId;
        final assigned = allAreas.where((a) => a.uid == assignedId).toList();
        _areas = assigned.isNotEmpty ? assigned : allAreas;
        // Auto-select their assigned area
        if (_areas.length == 1 && _form == null) {
          _selectedArea = _areas.first.name;
        }
      } else {
        _areas = allAreas;
      }
    } catch (e) {
      debugPrint('_loadAreas error: $e');
    }
    _areasLoading = false;
    if (mounted) setState(() {});
    // If a single area was auto-selected, load its zones
    if (_selectedArea != null && _form == null) {
      await _loadZones();
    }
  }

  Future<void> _loadZones() async {
    _zones = [];
    _selectedZone = null;
    _zonesLoading = true;
    if (mounted) setState(() {});
    try {
      final area = _areas.firstWhere((a) => a.name == _selectedArea, orElse: () => StationArea(stationId: '', name: ''));
      if (area.uid != null && area.uid!.isNotEmpty) {
        _zones = await ApiService.getStationZones(widget.stationId, areaId: area.uid);
      }
    } catch (e) {
      debugPrint('_loadZones error: $e');
    }
    _zonesLoading = false;
    if (mounted) setState(() {});
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? prefs.getString('token');
  }

  Future<String?> _capturePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return null;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/evidence/upload/base64'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'image': base64Encode(bytes), 'fileName': 'cleaning_form_${DateTime.now().millisecondsSinceEpoch}.jpg'}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] ?? data['imageUrl'] ?? '';
      }
    } catch (_) {}
    setState(() => _uploadingPhoto = false);
    return null;
  }

  Future<void> _saveDraft() async {
    if (_formUid != null) return; // backend does not support updating drafts
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final result = await ApiService.createStationCleaningForm(_buildPayload());
      _formUid = result['uid'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      if (_formUid == null) {
        final result = await ApiService.createStationCleaningForm(_buildPayload());
        _formUid = result['uid'];
      }
      await ApiService.submitStationCleaningForm(_formUid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form submitted for review'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _approve() async {
    try {
      await ApiService.approveStationCleaningForm(_formUid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form approved'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
      }
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Form'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()), style: ElevatedButton.styleFrom(backgroundColor: kErrorRed), child: const Text('Reject', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await ApiService.rejectStationCleaningForm(_formUid!, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form rejected'), backgroundColor: kErrorRed));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
      }
    }
  }

  Future<void> _score() async {
    double total = 0;
    for (final c in scoringCriteria) total += _scores[c['name']] ?? 0;
    final grade = total >= 90 ? 'A' : total >= 80 ? 'B' : total >= 70 ? 'C' : 'D';
    final criteriaData = scoringCriteria.map((c) => {'name': c['name'], 'maxScore': c['max'], 'score': _scores[c['name']] ?? 0}).toList();
    try {
      await ApiService.scoreStationCleaningForm(_formUid!, totalScore: total, grade: grade, scoringData: {'criteria': criteriaData, 'totalScore': total, 'maxTotalScore': 100, 'grade': grade});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Score submitted: $total% (Grade: $grade)'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
      }
    }
  }

  Future<void> _lock() async {
    try {
      await ApiService.lockStationCleaningForm(_formUid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form locked'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    return {
      'stationId': widget.stationId,
      'stationName': widget.stationName,
      'areaId': _areas.firstWhere((a) => a.name == _selectedArea, orElse: () => StationArea(stationId: '', name: '')).uid ?? '',
      'areaName': _selectedArea ?? '',
      'zoneId': _zones.firstWhere((z) => z.name == _selectedZone, orElse: () => StationZone(stationId: '', areaId: '', name: '')).uid ?? '',
      'zoneName': _selectedZone ?? '',
      'cleaningDate': dateStr,
      'shift': _selectedShift,
      'startTime': _startTime,
      'endTime': _endTime,
      'manpowerCount': int.tryParse(_manpowerCtrl.text) ?? 0,
      'machineCount': int.tryParse(_machineCtrl.text) ?? 0,
      'areaCovered': double.tryParse(_areaCoveredCtrl.text) ?? 0,
      'areaUncleaned': double.tryParse(_areaUncleanedCtrl.text) ?? 0,
      'garbageCollected': double.tryParse(_garbageCtrl.text) ?? 0,
      'remarks': _remarksCtrl.text.trim(),
      'submittedByName': _workerName ?? '',
      'photos': [
        ..._beforePhotos.map((u) => {'url': u, 'type': 'before'}),
        ..._afterPhotos.map((u) => {'url': u, 'type': 'after'}),
      ],
      'activities': _selectedActivities.toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final r = _form;
    return Scaffold(
      appBar: AppBar(
        title: Text(r != null ? 'Form ${r.formId}' : 'New Cleaning Form', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r != null) _buildStatusBanner(r),
              _buildSection('Area & Schedule', Icons.schedule, _buildScheduleSection()),
              const SizedBox(height: 12),
              _buildSection('Work Details', Icons.work, _buildWorkDetailsSection()),
              const SizedBox(height: 12),
              _buildSection('Cleaning Activities', Icons.checklist, _buildActivitiesSection()),
              const SizedBox(height: 12),
              _buildSection('Photo Evidence', Icons.camera_alt, _buildPhotoSection()),
              const SizedBox(height: 12),
              _buildSection('Remarks', Icons.comment, _buildRemarksSection()),
              if (r != null && r.status == StationFormStatus.approved) ...[
                const SizedBox(height: 12),
                _buildSection('Scoring', Icons.grade, _buildScoringSection()),
              ],
              if (r != null && r.rejectionReason != null && r.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kErrorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error, color: kErrorRed),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Rejection: ${r.rejectionReason}', style: const TextStyle(color: kErrorRed, fontWeight: FontWeight.bold))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              _buildActionButtons(r),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(StationCleaningForm r) {
    final colors = {StationFormStatus.draft: Colors.grey, StationFormStatus.submitted: kWarningOrange, StationFormStatus.approved: kSuccessGreen, StationFormStatus.scored: Colors.purple, StationFormStatus.locked: Colors.blueGrey, StationFormStatus.rejected: kErrorRed};
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: (colors[r.status] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: colors[r.status] ?? Colors.grey)),
      child: Row(children: [
        Icon(Icons.info, color: colors[r.status] ?? Colors.grey, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text('Status: ${r.statusLabel}', style: TextStyle(color: colors[r.status] ?? Colors.grey, fontWeight: FontWeight.bold))),
        if (r.score != null) Text('Score: ${r.score!.toStringAsFixed(0)}%  Grade: ${r.grade ?? '-'}', style: TextStyle(color: colors[r.status] ?? Colors.grey, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: kRailwayBlue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    final submitterName = _form?.submittedByName.isNotEmpty == true
        ? _form!.submittedByName
        : (_workerName ?? '');
    final submitterRole = _form != null ? (_form!.submittedBy.isNotEmpty ? _workerRole ?? '' : '') : (_workerRole ?? '');
    return Column(
      children: [
        // ── Worker Identity Banner ───────────────────────────────────────────
        if (submitterName.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kRailwayBlue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kRailwayBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kRailwayBlue.withOpacity(0.15),
                  child: const Icon(Icons.person, size: 20, color: kRailwayBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submitterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kRailwayBlue,
                        ),
                      ),
                      if (submitterRole.isNotEmpty)
                        Text(
                          submitterRole,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kRailwayBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Submitted By',
                    style: TextStyle(fontSize: 10, color: kRailwayBlue, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        // ────────────────────────────────────────────────────────────────────
        if (isEditable && _areasLoading)
          const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
        if (isEditable && _isWorkerRole && _areas.length == 1)
          // Single assigned area — show as a read-only field
          InputDecorator(
            decoration: InputDecoration(
              labelText: (_selectedArea != null && _selectedArea!.toLowerCase().contains('platform'))
                  ? 'Your Assigned Platform'
                  : 'Your Assigned Area',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey.shade100,
              suffixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
            ),
            child: Text(
              _areas.first.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          )
        else if (isEditable)
          DropdownButtonFormField<String>(
            value: _selectedArea,
            decoration: InputDecoration(
              labelText: (_selectedArea != null && _selectedArea!.toLowerCase().contains('platform'))
                  ? 'Platform *'
                  : 'Area *',
              border: const OutlineInputBorder(),
            ),
            items: _areas.isNotEmpty
                ? _areas.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList()
                : [const DropdownMenuItem(value: '', child: Text('No areas available', style: TextStyle(color: Colors.grey)))],
            onChanged: (v) {
              if (v != null && v.isNotEmpty) {
                setState(() => _selectedArea = v);
                _loadZones();
              }
            },
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          )
        else
          TextFormField(
            initialValue: _selectedArea ?? '',
            decoration: InputDecoration(
              labelText: (_selectedArea != null && _selectedArea!.toLowerCase().contains('platform'))
                  ? 'Platform'
                  : 'Area',
              border: const OutlineInputBorder(),
            ),
            readOnly: true,
          ),
        const SizedBox(height: 12),
        if (isEditable && _selectedArea != null && _selectedArea!.isNotEmpty) ...[
          if (_zonesLoading)
            const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
          DropdownButtonFormField<String>(
            value: _selectedZone,
            decoration: InputDecoration(
              labelText: (_selectedArea != null && _selectedArea!.toLowerCase().contains('platform'))
                  ? 'Area under Platform'
                  : 'Zone',
              border: const OutlineInputBorder(),
            ),
            items: _zones.isNotEmpty
                ? _zones.map((z) => DropdownMenuItem(value: z.name, child: Text(z.name))).toList()
                : [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        (_selectedArea!.toLowerCase().contains('platform'))
                            ? 'No areas configured'
                            : 'No zones configured',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
            onChanged: (v) { if (v != null && v.isNotEmpty) setState(() => _selectedZone = v); },
          ),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: isEditable ? () async {
                final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 7)));
                if (picked != null) setState(() => _selectedDate = picked);
              } : null,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                child: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", style: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedShift,
              decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'morning', child: Text('Morning')),
                DropdownMenuItem(value: 'afternoon', child: Text('Afternoon')),
                DropdownMenuItem(value: 'night', child: Text('Night')),
              ],
              onChanged: isEditable ? (v) { if (v != null) setState(() => _selectedShift = v); } : null,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextFormField(
              initialValue: _startTime,
              decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder(), hintText: '06:00'),
              readOnly: !isEditable,
              onChanged: (v) => _startTime = v,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: _endTime,
              decoration: const InputDecoration(labelText: 'End Time', border: OutlineInputBorder(), hintText: '14:00'),
              readOnly: !isEditable,
              onChanged: (v) => _endTime = v,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildWorkDetailsSection() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _manpowerCtrl, decoration: const InputDecoration(labelText: 'Manpower Count', border: OutlineInputBorder()), keyboardType: TextInputType.number, readOnly: !isEditable)),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: _machineCtrl, decoration: const InputDecoration(labelText: 'Machine Count', border: OutlineInputBorder()), keyboardType: TextInputType.number, readOnly: !isEditable)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextFormField(controller: _areaCoveredCtrl, decoration: const InputDecoration(labelText: 'Area Covered (sqm)', border: OutlineInputBorder()), keyboardType: TextInputType.number, readOnly: !isEditable)),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: _areaUncleanedCtrl, decoration: const InputDecoration(labelText: 'Area Uncleaned', border: OutlineInputBorder()), keyboardType: TextInputType.number, readOnly: !isEditable)),
        ]),
        const SizedBox(height: 12),
        TextFormField(controller: _garbageCtrl, decoration: const InputDecoration(labelText: 'Garbage Collected (kg)', border: OutlineInputBorder()), keyboardType: TextInputType.number, readOnly: !isEditable),
      ],
    );
  }

  Widget _buildActivitiesSection() {
    return Column(
      children: stationCleaningActivities.map((act) => CheckboxListTile(
        value: _selectedActivities.contains(act),
        title: Text(act, style: const TextStyle(fontSize: 13)),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        onChanged: isEditable ? (v) { setState(() { if (v == true) _selectedActivities.add(act); else _selectedActivities.remove(act); }); } : null,
      )).toList(),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _photoColumn('Before Photos', _beforePhotos, true)),
          const SizedBox(width: 12),
          Expanded(child: _photoColumn('After Photos', _afterPhotos, false)),
        ]),
        if (_uploadingPhoto) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      ],
    );
  }

  Widget _photoColumn(String label, List<String> photos, bool isBefore) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          height: 120, width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
          child: photos.isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(photos.last, fit: BoxFit.cover, width: double.infinity, height: 120))
              : const Center(child: Icon(Icons.add_a_photo, size: 36, color: Colors.grey)),
        ),
        if (isEditable) ...[
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton.icon(
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Capture', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final url = await _capturePhoto();
                if (url != null) setState(() { if (isBefore) _beforePhotos.add(url); else _afterPhotos.add(url); });
              },
            ),
          ]),
        ],
      ],
    );
  }

  Widget _buildRemarksSection() {
    return TextFormField(
      controller: _remarksCtrl,
      decoration: const InputDecoration(labelText: 'Remarks / Notes', border: OutlineInputBorder()),
      maxLines: 3,
      readOnly: !isEditable,
    );
  }

  Widget _buildScoringSection() {
    return Column(
      children: [
        ...scoringCriteria.map((c) {
          final name = c['name'] as String;
          final maxScore = c['max'] as int;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(flex: 2, child: Text(name, style: const TextStyle(fontSize: 13))),
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: _scores[name]?.clamp(0, maxScore.toDouble()),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), border: OutlineInputBorder()),
                  items: List.generate(maxScore + 1, (i) => DropdownMenuItem(value: i.toDouble(), child: Text('$i/$maxScore', style: const TextStyle(fontSize: 12)))),
                  onChanged: (v) { if (v != null) setState(() => _scores[name] = v); },
                ),
              ),
            ]),
          );
        }),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('${scoringCriteria.fold(0.0, (sum, c) => sum + (_scores[c['name']] ?? 0)).toStringAsFixed(0)}/100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kRailwayBlue)),
        ]),
      ],
    );
  }

  Widget _buildActionButtons(StationCleaningForm? r) {
    if (_isSaving) return const Center(child: CircularProgressIndicator());

    if (r == null || r.status == StationFormStatus.draft) {
      return Column(children: [
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(onPressed: _saveDraft, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
            child: const Text('Save Draft')),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
            child: const Text('Submit for Review')),
        ),
      ]);
    }

    if (r.status == StationFormStatus.submitted) {
      return Row(children: [
        Expanded(child: SizedBox(height: 48, child: ElevatedButton(onPressed: _approve, style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white), child: const Text('Approve')))),
        const SizedBox(width: 12),
        Expanded(child: SizedBox(height: 48, child: ElevatedButton(onPressed: _reject, style: ElevatedButton.styleFrom(backgroundColor: kErrorRed, foregroundColor: Colors.white), child: const Text('Reject')))),
      ]);
    }

    if (r.status == StationFormStatus.approved) {
      return SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton(onPressed: _score, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
          child: const Text('Submit Score')),
      );
    }

    if (r.status == StationFormStatus.scored) {
      return SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton(onPressed: _lock, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
          child: const Text('Lock Form')),
      );
    }

    return const SizedBox.shrink();
  }
}
