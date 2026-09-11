import 'package:flutter/material.dart';
import 'package:crm_train/model/frequency_model.dart';
import 'package:crm_train/repositories/frequency_repository.dart';
import 'package:crm_train/utills/app_colors.dart';

const _frequencyTypes = [
  'once_per_day', 'twice_per_day', 'three_times_per_day',
  'every_six_hours', 'hourly', 'shift_wise', 'weekly', 'fortnightly',
  'monthly', 'as_and_when_required', 'other',
];

class FrequencyFormScreen extends StatefulWidget {
  final Frequency? existing;
  const FrequencyFormScreen({super.key, this.existing});

  @override
  State<FrequencyFormScreen> createState() => _FrequencyFormScreenState();
}

class _FrequencyFormScreenState extends State<FrequencyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _timesCtrl;
  late TextEditingController _daysCtrl;
  String _frequencyType = 'once_per_day';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.frequencyName ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _timesCtrl = TextEditingController(text: e?.timesPerDay.toString() ?? '');
    _daysCtrl = TextEditingController(text: e?.daysBetween.toString() ?? '');
    if (e != null) _frequencyType = e.frequencyType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _timesCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final body = {
        'frequencyName': _nameCtrl.text.trim(),
        'frequencyType': _frequencyType,
        'timesPerDay': int.tryParse(_timesCtrl.text) ?? 0,
        'daysBetween': int.tryParse(_daysCtrl.text) ?? 0,
        'description': _descCtrl.text.trim(),
      };
      if (_isEdit) {
        await FrequencyRepository.update(widget.existing!.uid!, body);
      } else {
        await FrequencyRepository.create(body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Frequency updated' : 'Frequency created'), backgroundColor: kSuccessGreen),
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
        title: Text('${_isEdit ? 'Edit' : 'Add'} Frequency', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          child: const Icon(Icons.schedule, color: kRailwayBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Frequency Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
                      const Divider(height: 20),
                      DropdownButtonFormField<String>(
                        value: _frequencyType,
                        decoration: const InputDecoration(labelText: 'Frequency Type *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.schedule)),
                        items: _frequencyTypes.map((f) => DropdownMenuItem(value: f, child: Text(f.replaceAll('_', ' ')))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _frequencyType = v); },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Label / Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.label)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _timesCtrl,
                              decoration: const InputDecoration(labelText: 'Times per day', border: OutlineInputBorder(), prefixIcon: Icon(Icons.repeat)),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _daysCtrl,
                              decoration: const InputDecoration(labelText: 'Days between', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                        maxLines: 2,
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
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEdit ? 'Update Frequency' : 'Create Frequency'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
