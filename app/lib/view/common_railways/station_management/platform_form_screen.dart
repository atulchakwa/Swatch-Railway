import 'package:flutter/material.dart';
import 'package:crm_train/model/platform_model.dart';
import 'package:crm_train/repositories/platform_repository.dart';
import 'package:crm_train/utills/app_colors.dart';

class PlatformFormScreen extends StatefulWidget {
  final String stationId;
  final Platform? existingPlatform;

  const PlatformFormScreen({
    super.key,
    required this.stationId,
    this.existingPlatform,
  });

  @override
  State<PlatformFormScreen> createState() => _PlatformFormScreenState();
}

const List<String> _areaTypes = [
  'Toilet/Bathroom', 'Waiting Room', 'Concourse', 'FOB/Stairs', 'Lift/Escalator',
  'Office', 'Water Booth', 'Track-side Rag Picking Area',
  'Circulating Area', 'Approach Road', 'Garden',
  'Goods Platform/Goods Line', 'Drain', 'Other',
];

class _PlatformFormScreenState extends State<PlatformFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  late TextEditingController _numberCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _lengthCtrl;
  late TextEditingController _widthCtrl;
  String _surfaceType = 'concrete';
  String _platformArea = '';

  bool get isEdit => widget.existingPlatform != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlatform;
    _numberCtrl = TextEditingController(text: p?.platformNumber ?? '');
    _nameCtrl = TextEditingController(text: p?.platformName ?? '');
    _lengthCtrl = TextEditingController(text: p?.length?.toString() ?? '');
    _widthCtrl = TextEditingController(text: p?.width?.toString() ?? '');
    if (p?.surfaceType != null) _surfaceType = p!.surfaceType!;
    if (p?.platformArea != null) _platformArea = p!.platformArea!;
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);
    try {
      final data = {
        'platformNumber': _numberCtrl.text.trim(),
        'platformName': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        'stationId': widget.stationId,
        'surfaceType': _surfaceType,
        'platformArea': _platformArea.isEmpty ? null : _platformArea,
        if (_lengthCtrl.text.isNotEmpty) 'length': double.tryParse(_lengthCtrl.text),
        if (_widthCtrl.text.isNotEmpty) 'width': double.tryParse(_widthCtrl.text),
      };
      if (isEdit) {
        await PlatformRepository.update(widget.existingPlatform!.uid!, data);
      } else {
        await PlatformRepository.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Platform updated' : 'Platform created'), backgroundColor: kSuccessGreen),
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
        title: Text('${isEdit ? 'Edit' : 'Add'} Platform', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          child: const Icon(Icons.view_quilt, color: kRailwayBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Platform Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
                      const Divider(height: 20),
                      TextFormField(
                        controller: _numberCtrl,
                        decoration: const InputDecoration(labelText: 'Platform Number *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.tag)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Platform Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.label)),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _surfaceType,
                        decoration: const InputDecoration(labelText: 'Surface Type', border: OutlineInputBorder(), prefixIcon: Icon(Icons.layers)),
                        items: ['concrete', 'asphalt', 'tile', 'marble', 'other'].map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _surfaceType = v); },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _platformArea.isEmpty ? null : _platformArea,
                        decoration: const InputDecoration(labelText: 'Platform Area', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                        items: _areaTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _platformArea = v); },
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
                          child: const Icon(Icons.straighten, color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Dimensions (optional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lengthCtrl,
                              decoration: const InputDecoration(labelText: 'Length (m)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.arrow_forward)),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _widthCtrl,
                              decoration: const InputDecoration(labelText: 'Width (m)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.arrow_upward)),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
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
                      : Text(isEdit ? 'Update Platform' : 'Create Platform'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
