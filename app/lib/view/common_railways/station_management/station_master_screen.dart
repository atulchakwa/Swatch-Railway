import 'package:crm_train/data/zone_database.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class StationMasterScreen extends StatefulWidget {
  final Station? existingStation;
  const StationMasterScreen({super.key, this.existingStation});

  @override
  State<StationMasterScreen> createState() => _StationMasterScreenState();
}

class _StationMasterScreenState extends State<StationMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;

  String? _zone;
  String? _division;
  List<String> _divisions = [];

  StationCategory _category = StationCategory.b;
  StationType _type = StationType.regular;
  bool _active = true;

  bool get isEdit => widget.existingStation != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingStation;
    _codeCtrl = TextEditingController(text: s?.stationCode ?? '');
    _nameCtrl = TextEditingController(text: s?.stationName ?? '');
    if (s != null) {
      _category = s.category;
      _type = s.stationType;
      _active = s.active;
      _resolveZoneDivision(s);
    }
  }

  void _resolveZoneDivision(Station s) {
    final zones = DepotDatabase.zoneData.keys.toList();
    for (final zKey in zones) {
      if (zKey.toLowerCase() == s.zone.toLowerCase() ||
          zKey.toLowerCase().contains(s.zone.toLowerCase()) ||
          s.zone.toLowerCase().contains(zKey.toLowerCase())) {
        _zone = zKey;
        break;
      }
    }
    if (_zone == null) return;
    _divisions = DepotDatabase.zoneData[_zone]?.keys.toList() ?? [];
    for (final dKey in _divisions) {
      if (dKey.toLowerCase() == s.division.toLowerCase() ||
          dKey.toLowerCase().contains(s.division.toLowerCase()) ||
          s.division.toLowerCase().contains(dKey.toLowerCase())) {
        _division = dKey;
        break;
      }
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);
    try {
      final data = {
        'stationCode': _codeCtrl.text.trim(),
        'stationName': _nameCtrl.text.trim(),
        'zone': _zone ?? '',
        'division': _division ?? '',
        'category': _category.name,
        'stationType': _type.name,
        'active': _active,
      };
      if (isEdit) {
        await ApiService.updateStation(widget.existingStation!.uid!, data);
      } else {
        await ApiService.createStation(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Station updated' : 'Station created'), backgroundColor: kSuccessGreen),
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
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${isEdit ? 'Edit' : 'Add'} Station', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.info, color: kRailwayBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Basic Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
                      const Divider(height: 20),
                      TextFormField(
                        controller: _codeCtrl,
                        decoration: const InputDecoration(labelText: 'Station Code *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.tag)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Station Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.train)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.category, color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Classification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
                      const Divider(height: 20),
                      DropdownButtonFormField<String>(
                        value: (_zone != null && DepotDatabase.zoneData.containsKey(_zone)) ? _zone : null,
                        decoration: const InputDecoration(labelText: 'Zone *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                        items: DepotDatabase.zoneData.keys.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
                        validator: (v) => v == null ? 'Required' : null,
                        onChanged: (v) => setState(() {
                          _zone = v;
                          _division = null;
                          _divisions = v != null ? (DepotDatabase.zoneData[v]?.keys.toList() ?? []) : [];
                        }),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: (_division != null && _divisions.contains(_division)) ? _division : null,
                        decoration: const InputDecoration(labelText: 'Division *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map_outlined)),
                        items: _divisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        validator: (v) => v == null ? 'Required' : null,
                        onChanged: (v) => setState(() => _division = v),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<StationCategory>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.star)),
                        items: StationCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _category = v); },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<StationType>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Station Type *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance)),
                        items: StationType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name[0].toUpperCase() + t.name.substring(1)))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _type = v); },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: Text(_active ? 'Station is operational' : 'Station is disabled'),
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                        activeColor: kSuccessGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Update Station' : 'Create Station'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
