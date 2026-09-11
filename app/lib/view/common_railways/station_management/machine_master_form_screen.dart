import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

class MachineMasterFormScreen extends StatefulWidget {
  final Map<String, dynamic>? machine;
  const MachineMasterFormScreen({super.key, this.machine});

  @override
  State<MachineMasterFormScreen> createState() => _MachineMasterFormScreenState();
}

class _MachineMasterFormScreenState extends State<MachineMasterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  List<Station> _stations = [];

  late TextEditingController _nameCtrl;
  late TextEditingController _serialCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _downtimeDateCtrl;
  late TextEditingController _downtimeReasonCtrl;
  late TextEditingController _estRepairDateCtrl;
  late TextEditingController _actualRepairDateCtrl;

  String _type = 'scrubber';
  String _workingStatus = 'working';
  String _replacementStatus = 'none';
  String? _stationId;

  bool get _isEdit => widget.machine != null;

  final _types = ['scrubber', 'sweeper', 'vacuum', 'pressure_washer', 'generator', 'blower', 'other'];
  final _statuses = ['working', 'under_maintenance', 'broken', 'retired'];
  final _replacementStatuses = ['none', 'requested', 'approved', 'replaced'];

  @override
  void initState() {
    super.initState();
    final m = widget.machine;
    _nameCtrl = TextEditingController(text: m?['machineName'] ?? '');
    _serialCtrl = TextEditingController(text: m?['serialNumber'] ?? '');
    _locationCtrl = TextEditingController(text: m?['location'] ?? '');
    _remarksCtrl = TextEditingController(text: m?['remarks'] ?? '');
    _downtimeReasonCtrl = TextEditingController(text: m?['downtimeEntry']?['downtimeReason'] ?? '');
    _downtimeDateCtrl = TextEditingController(text: m?['downtimeEntry']?['downtimeDate'] ?? '');
    _estRepairDateCtrl = TextEditingController(text: m?['downtimeEntry']?['estimatedRepairDate'] ?? '');
    _actualRepairDateCtrl = TextEditingController(text: m?['downtimeEntry']?['actualRepairDate'] ?? '');
    if (m != null) {
      final t = (m['machineType'] as String? ?? 'scrubber').trim().toLowerCase();
      _type = _types.contains(t) ? t : 'other';
      _workingStatus = m['workingStatus'] ?? 'working';
      _replacementStatus = m['replacementStatus'] ?? 'none';
      _stationId = m['stationId'];
    }
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      _stations = await ApiService.getStations(active: true);
      if (_stations.isNotEmpty && !_isEdit) {
        if (_stationId == null) {
          final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
          if (user?.stationId != null && user!.stationId!.isNotEmpty) {
            final match = _stations.where((s) => s.uid == user!.stationId).firstOrNull;
            if (match != null) _stationId = match.uid ?? match.stationCode;
          }
        }
        _stationId ??= _stations.first.uid ?? _stations.first.stationCode;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serialCtrl.dispose();
    _locationCtrl.dispose();
    _remarksCtrl.dispose();
    _downtimeDateCtrl.dispose();
    _downtimeReasonCtrl.dispose();
    _estRepairDateCtrl.dispose();
    _actualRepairDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      ctrl.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> body = {
        'machineName': _nameCtrl.text.trim(),
        'machineType': _type,
        'serialNumber': _serialCtrl.text.trim(),
        'stationId': _stationId ?? '',
        'location': _locationCtrl.text.trim(),
        'workingStatus': _workingStatus,
        'replacementStatus': _replacementStatus,
        'remarks': _remarksCtrl.text.trim(),
      };
      final dtEntry = <String, dynamic>{};
      if (_downtimeDateCtrl.text.isNotEmpty) dtEntry['downtimeDate'] = _downtimeDateCtrl.text;
      if (_downtimeReasonCtrl.text.isNotEmpty) dtEntry['downtimeReason'] = _downtimeReasonCtrl.text;
      if (_estRepairDateCtrl.text.isNotEmpty) dtEntry['estimatedRepairDate'] = _estRepairDateCtrl.text;
      if (_actualRepairDateCtrl.text.isNotEmpty) dtEntry['actualRepairDate'] = _actualRepairDateCtrl.text;
      if (dtEntry.isNotEmpty) body['downtimeEntry'] = dtEntry;

      if (_isEdit) {
        await ApiService.updateMachine(widget.machine!['uid'], body);
      } else {
        await ApiService.createMachine(body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Machine updated' : 'Machine created'), backgroundColor: kSuccessGreen),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_isEdit ? 'Edit' : 'Add'} Machine', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Machine Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.precision_manufacturing)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Machine Type *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ').toUpperCase()))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialCtrl,
                decoration: const InputDecoration(labelText: 'Serial Number *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _stationId,
                decoration: const InputDecoration(labelText: 'Station *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.train)),
                items: _stations.map((s) => DropdownMenuItem(value: s.uid ?? s.stationCode, child: Text('${s.stationCode} - ${s.stationName}'))).toList(),
                onChanged: (v) => setState(() => _stationId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Location / Area', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _workingStatus,
                decoration: const InputDecoration(labelText: 'Working Status', border: OutlineInputBorder(), prefixIcon: Icon(Icons.check_circle)),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase()))).toList(),
                onChanged: (v) => setState(() => _workingStatus = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _replacementStatus,
                decoration: const InputDecoration(labelText: 'Replacement / Repair Status', border: OutlineInputBorder(), prefixIcon: Icon(Icons.build)),
                items: _replacementStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                onChanged: (v) => setState(() => _replacementStatus = v!),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kWarningOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kWarningOrange.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.download, size: 18, color: kWarningOrange),
                      const SizedBox(width: 8),
                      const Text('Downtime Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _downtimeDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Downtime Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today, size: 20),
                        suffixIcon: Icon(Icons.date_range),
                      ),
                      readOnly: true,
                      onTap: () => _pickDate(_downtimeDateCtrl),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _downtimeReasonCtrl,
                      decoration: const InputDecoration(labelText: 'Downtime Reason', border: OutlineInputBorder(), prefixIcon: Icon(Icons.report_problem, size: 20)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _estRepairDateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Est. Repair Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.schedule, size: 20),
                              suffixIcon: Icon(Icons.date_range, size: 18),
                            ),
                            readOnly: true,
                            onTap: () => _pickDate(_estRepairDateCtrl),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _actualRepairDateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Actual Repair Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.check_circle, size: 20),
                              suffixIcon: Icon(Icons.date_range, size: 18),
                            ),
                            readOnly: true,
                            onTap: () => _pickDate(_actualRepairDateCtrl),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEdit ? 'Update Machine' : 'Create Machine'),
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
