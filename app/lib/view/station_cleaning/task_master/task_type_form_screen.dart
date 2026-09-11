import 'package:flutter/material.dart';
import 'package:crm_train/model/task_type_model.dart';
import 'package:crm_train/repositories/task_type_repository.dart';
import 'package:crm_train/utills/app_colors.dart';

class TaskTypeFormScreen extends StatefulWidget {
  final TaskType? taskType;
  final String stationId;
  final String stationName;
  const TaskTypeFormScreen({super.key, this.taskType, required this.stationId, required this.stationName});
  @override State<TaskTypeFormScreen> createState() => _TaskTypeFormScreenState();
}

class _TaskTypeFormScreenState extends State<TaskTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _labelCtrl;
  String _category = 'cleaning';
  bool _isActive = true;

  bool get isEdit => widget.taskType != null;

  static const _categories = ['cleaning', 'inspection', 'maintenance', 'repair', 'other'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.taskType?.name ?? '');
    _labelCtrl = TextEditingController(text: widget.taskType?.label ?? '');
    _category = widget.taskType?.category ?? 'cleaning';
    _isActive = widget.taskType?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
        'label': _labelCtrl.text.trim(),
        'category': _category,
        'isActive': _isActive,
      };
      if (isEdit) {
        await TaskTypeRepository.update(widget.taskType!.uid, data);
      } else {
        await TaskTypeRepository.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Task type updated' : 'Task type created')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${isEdit ? 'Edit' : 'New'} Task Type', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Slug Name', hintText: 'e.g. sweeping', helperText: 'Lowercase, no spaces'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _labelCtrl,
                        decoration: const InputDecoration(labelText: 'Display Label', hintText: 'e.g. Sweeping'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _categories.contains(_category) ? _category : _categories.first,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1)))).toList(),
                        onChanged: (v) => setState(() => _category = v ?? 'cleaning'),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Active'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue),
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
