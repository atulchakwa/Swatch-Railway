import 'dart:convert';
import 'dart:io';
import 'package:crm_train/model/platform_model.dart';
import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/petty_issue_repository.dart';
import 'package:crm_train/repositories/platform_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PettyIssueFormScreen extends StatefulWidget {
  final PettyIssue? issue;
  final String stationId;
  final String stationName;
  const PettyIssueFormScreen({super.key, this.issue, required this.stationId, required this.stationName});

  @override
  State<PettyIssueFormScreen> createState() => _PettyIssueFormScreenState();
}

class _PettyIssueFormScreenState extends State<PettyIssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _descCtrl;
  late TextEditingController _remarksCtrl;

  String _category = 'other';
  String _severity = 'medium';
  String? _selectedArea;
  String? _selectedPlatformId;
  List<StationArea> _areas = [];
  List<Platform> _platforms = [];
  bool _areasLoading = false;
  bool _platformsLoading = false;

  File? _photo;
  bool _uploadingPhoto = false;
  double? _gpsLat;
  double? _gpsLng;

  bool get isEdit => widget.issue != null;
  String get _currentStatus => widget.issue?.status ?? '';

  final _categories = [
    'broken_fittings', 'damaged_dustbin', 'leakage', 'blocked_drain',
    'damaged_tiles', 'lighting_issue', 'signage_issue', 'damaged_fixture', 'other'
  ];
  final _severities = ['low', 'medium', 'high', 'critical'];

  @override
  void initState() {
    super.initState();
    final r = widget.issue;
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _remarksCtrl = TextEditingController(text: r?.remarks ?? '');
    _category = r?.category ?? 'other';
    _severity = r?.severity ?? 'medium';
    _selectedArea = r?.areaId;
    _selectedPlatformId = r?.platformId;
    _gpsLat = r?.gpsLatitude;
    _gpsLng = r?.gpsLongitude;
    _loadAreas();
    _loadPlatforms();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    setState(() => _areasLoading = true);
    try {
      final raw = await ApiService.getStationAreas(widget.stationId);
      final seen = <String>{};
      _areas = [];
      for (final a in raw) {
        final key = a.name.trim();
        if (key.isNotEmpty && seen.add(key)) _areas.add(a);
      }
      if (_selectedArea != null && _areas.where((a) => a.name == _selectedArea).length != 1) {
        _selectedArea = null;
      }
    } catch (_) {}
    if (mounted) setState(() => _areasLoading = false);
  }

  Future<void> _loadPlatforms() async {
    setState(() => _platformsLoading = true);
    try {
      _platforms = await PlatformRepository.getByStation(widget.stationId);
    } catch (_) {}
    if (mounted) setState(() => _platformsLoading = false);
  }

  Future<String?> _uploadPhoto() async {
    if (_photo == null) return null;
    setState(() => _uploadingPhoto = true);
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.baseUrl}/api/media/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', _photo!.path, filename: 'petty_${DateTime.now().millisecondsSinceEpoch}.jpg'));
      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        return data['url'] ?? data['imageUrl'] ?? '';
      }
    } catch (_) {}
    setState(() => _uploadingPhoto = false);
    return null;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String? photoUrl;
      if (_photo != null) photoUrl = await _uploadPhoto();
      final payload = <String, dynamic>{
        'stationId': widget.stationId,
        'category': _category,
        'description': _descCtrl.text.trim(),
        'severity': _severity,
        'areaId': _selectedArea,
        'platformId': _selectedPlatformId,
        'remarks': _remarksCtrl.text.trim(),
      };
      if (photoUrl != null) payload['photo'] = photoUrl;
      if (_gpsLat != null) payload['gpsLatitude'] = _gpsLat;
      if (_gpsLng != null) payload['gpsLongitude'] = _gpsLng;
      await PettyIssueRepository.create(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Petty issue reported'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      await PettyIssueRepository.updateStatus(widget.issue!.uid, {'status': status, 'remarks': _remarksCtrl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $status'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _hasPermission(String permission) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return false;
    final role = (user.role ?? '').toUpperCase().replaceAll(' ', '_');
    const perms = {
      'SUPER_ADMIN': {'MANAGE', 'VIEW', 'RESOLVE'},
      'COMPANY_MASTER': {'MANAGE', 'VIEW', 'RESOLVE'},
      'RAILWAY_MASTER': {'VIEW'},
      'ADMIN': {'MANAGE', 'VIEW', 'RESOLVE'},
      'RAILWAY_ADMIN': {'MANAGE', 'VIEW', 'RESOLVE'},
      'CONTRACTOR_MASTER': {'VIEW'},
      'RAILWAY_SUPERVISOR': {'MANAGE', 'VIEW', 'RESOLVE'},
      'CONTRACTOR_ADMIN': {'MANAGE', 'VIEW', 'RESOLVE'},
      'CONTRACTOR_SUPERVISOR': {'VIEW'},
    };
    return (perms[role] ?? <String>{}).contains(permission);
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return kErrorRed;
      case 'high': return Colors.orange;
      case 'medium': return kWarningOrange;
      default: return Colors.grey;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'REPORTED': return kWarningOrange;
      case 'ASSIGNED': return Colors.blue;
      case 'IN_PROGRESS': return Colors.orange;
      case 'RESOLVED': return kSuccessGreen;
      case 'CLOSED': return Colors.grey;
      case 'REJECTED': return kErrorRed;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.issue;
    final canManage = _hasPermission('MANAGE');
    final canResolve = _hasPermission('RESOLVE');
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Petty Issue Detail' : 'Report Petty Issue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                        items: _categories.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ').toUpperCase()))).toList(),
                        onChanged: isEdit ? null : (v) { if (v != null) setState(() => _category = v); },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _severity,
                        decoration: const InputDecoration(labelText: 'Severity *', border: OutlineInputBorder()),
                        items: _severities.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                        onChanged: isEdit ? null : (v) { if (v != null) setState(() => _severity = v); },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      if (_areasLoading)
                        const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      else
                        DropdownButtonFormField<String>(
                          value: _areas.where((a) => a.name == _selectedArea).length == 1 ? _selectedArea : null,
                          decoration: const InputDecoration(labelText: 'Area', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Select Area')),
                            ..._areas.map<DropdownMenuItem<String>>((a) => DropdownMenuItem(value: a.name, child: Text(a.name))),
                          ],
                          onChanged: isEdit ? null : (v) { if (v != null) setState(() => _selectedArea = v); },
                        ),
                      const SizedBox(height: 12),
                      if (_platformsLoading)
                        const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedPlatformId == null || _platforms.where((p) => p.uid == _selectedPlatformId).length == 1 ? _selectedPlatformId : null,
                          decoration: const InputDecoration(labelText: 'Platform (optional)', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('None')),
                            ..._platforms.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p.uid, child: Text(p.displayName))),
                          ],
                          onChanged: isEdit ? null : (v) { if (v != null) setState(() => _selectedPlatformId = v); },
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarksCtrl,
                        decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploadingPhoto ? null : () async {
                              final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                              if (picked != null) setState(() => _photo = File(picked.path));
                            },
                            icon: _uploadingPhoto
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.camera_alt, size: 18),
                            label: Text(_photo != null ? 'Photo taken' : 'Add Photo'),
                          ),
                          if (_photo != null) ...[
                            const SizedBox(width: 8),
                            ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(_photo!, width: 40, height: 40, fit: BoxFit.cover)),
                          ],
                        ],
                      ),
                      if (r?.photo != null && _photo == null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.image, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text('Photo attached', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                      if (_gpsLat != null || _gpsLng != null) ...[
                        const SizedBox(height: 8),
                        Text('GPS: ${_gpsLat?.toStringAsFixed(4) ?? "?"}, ${_gpsLng?.toStringAsFixed(4) ?? "?"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
              ),
              if (r != null && r.closureHistory.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...r.closureHistory.map((h) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _statusColor(h['fromStatus'] ?? '').withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(h['fromStatus'] ?? '', style: TextStyle(color: _statusColor(h['fromStatus'] ?? ''), fontSize: 10, fontWeight: FontWeight.bold))),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 14)),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _statusColor(h['toStatus'] ?? '').withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(h['toStatus'] ?? '', style: TextStyle(color: _statusColor(h['toStatus'] ?? ''), fontSize: 10, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        if ((h['remarks'] ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(h['remarks'], style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.only(top: 2), child: Text('${h['changedByName'] ?? ''} ${h['timestamp'] != null ? 'at ${h['timestamp']}' : ''}', style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
                      ],
                    ),
                  ),
                )),
              ],
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (!isEdit && canManage)
                  SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: kWarningOrange, foregroundColor: Colors.white), child: const Text('Report Petty Issue'))),
                if (isEdit && _currentStatus == 'REPORTED' && canManage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(child: SizedBox(height: 48, child: ElevatedButton(onPressed: () => _updateStatus('ASSIGNED'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text('Assign')))),
                        const SizedBox(width: 12),
                        Expanded(child: SizedBox(height: 48, child: ElevatedButton(onPressed: () => _updateStatus('REJECTED'), style: ElevatedButton.styleFrom(backgroundColor: kErrorRed, foregroundColor: Colors.white), child: const Text('Reject')))),
                      ],
                    ),
                  ),
                if (isEdit && _currentStatus == 'ASSIGNED' && canResolve)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => _updateStatus('IN_PROGRESS'), style: ElevatedButton.styleFrom(backgroundColor: kWarningOrange, foregroundColor: Colors.white), child: const Text('Start Work')))),
                if (isEdit && _currentStatus == 'IN_PROGRESS' && canResolve)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => _updateStatus('RESOLVED'), style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white), child: const Text('Mark Resolved')))),
                if (isEdit && _currentStatus == 'RESOLVED' && canManage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => _updateStatus('CLOSED'), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white), child: const Text('Close Issue')))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
