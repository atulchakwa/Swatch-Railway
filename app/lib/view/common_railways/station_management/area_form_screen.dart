import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/platform_model.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

const List<String> _areaTypes = [
  'Toilet/Bathroom', 'Waiting Room', 'Concourse', 'FOB/Stairs', 'Lift/Escalator',
  'Office', 'Water Booth', 'Track-side Rag Picking Area',
  'Circulating Area', 'Approach Road', 'Garden',
  'Goods Platform/Goods Line', 'Drain', 'Other',
];

class AreaFormScreen extends StatefulWidget {
  final String stationId;
  final String? platformId;
  final String? platformName;
  final List<Platform>? platforms;
  final Map<String, dynamic>? existingArea;
  const AreaFormScreen({super.key, required this.stationId, this.platformId, this.platformName, this.platforms, this.existingArea});

  @override
  State<AreaFormScreen> createState() => _AreaFormScreenState();
}

class _AreaFormScreenState extends State<AreaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _descCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');
  final _customAreaCtrl = TextEditingController();
  final _singleNameCtrl = TextEditingController(); // For edit mode
  
  final List<String> _selectedAreas = [];
  bool _active = true;
  Platform? _selectedPlatform;

  bool get _isReadOnly {
    final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '';
    return role == 'Area Master' || role == 'Platform Master';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existingArea;
    if (e != null) {
      _singleNameCtrl.text = e['name'] ?? e['areaName'] ?? '';
      _descCtrl.text = e['description'] ?? '';
      _orderCtrl.text = '${e['order'] ?? 0}';
      _active = e['active'] ?? true;
    }
    // Pre-select platform from widget
    if (widget.platforms != null && widget.platformId != null) {
      _selectedPlatform = widget.platforms!.where((p) => p.uid == widget.platformId).firstOrNull;
    }
    if (_selectedPlatform == null && widget.platforms != null && widget.platforms!.isNotEmpty) {
      _selectedPlatform = widget.platforms!.first;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _orderCtrl.dispose();
    _customAreaCtrl.dispose();
    _singleNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final isEdit = widget.existingArea != null;
    if (isEdit) {
      if (!_formKey.currentState!.validate()) return;
    } else {
      if (_selectedAreas.isEmpty && _customAreaCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or enter at least one area'), backgroundColor: kErrorRed),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      if (isEdit) {
        final data = {
          'stationId': widget.stationId,
          'name': _singleNameCtrl.text.trim(),
          'areaName': _singleNameCtrl.text.trim(),
          'areaType': _singleNameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'order': int.tryParse(_orderCtrl.text) ?? 0,
          'active': _active,
          'platformId': _selectedPlatform?.uid ?? widget.platformId ?? widget.existingArea!['platformId'],
        };
        final uid = widget.existingArea!['uid'] ?? widget.existingArea!['id'];
        await ApiService.updateStationArea(uid, data);
      } else {
        // Collect all areas to create
        final List<String> areasToCreate = List.from(_selectedAreas);
        if (_customAreaCtrl.text.trim().isNotEmpty) {
          final customList = _customAreaCtrl.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          areasToCreate.addAll(customList);
        }

        // Create each area in a loop
        for (final areaName in areasToCreate) {
          final data = {
            'stationId': widget.stationId,
            'name': areaName,
            'areaName': areaName,
            'areaType': areaName,
            'description': _descCtrl.text.trim(),
            'order': int.tryParse(_orderCtrl.text) ?? 0,
            'active': _active,
            'platformId': _selectedPlatform?.uid ?? widget.platformId,
          };
          await ApiService.createStationArea(data);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Area updated' : 'Areas created successfully'),
            backgroundColor: kSuccessGreen,
          ),
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
    final isEdit = widget.existingArea != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('${isEdit ? 'Edit' : 'Add'} Area', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              Text(isEdit ? 'Edit Area Details' : 'Select Areas to Create', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Platform dropdown (read-only for Area/Platform Master)
              if (widget.platforms != null && widget.platforms!.isNotEmpty) ...[
                DropdownButtonFormField<Platform>(
                  value: _selectedPlatform,
                  decoration: const InputDecoration(
                    labelText: 'Platform',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.view_quilt),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: widget.platforms!.map((p) => DropdownMenuItem(value: p, child: Text(p.displayName))).toList(),
                  onChanged: _isReadOnly
                      ? null
                      : (v) => setState(() => _selectedPlatform = v),
                  disabledHint: Text(_selectedPlatform?.displayName ?? widget.platformName ?? ''),
                ),
                const SizedBox(height: 12),
              ] else if (widget.platformName != null && widget.platformName!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kRailwayBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kRailwayBlue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.layers, color: kRailwayBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Adding areas under: ${widget.platformName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kRailwayBlue, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              if (isEdit) ...[
                TextFormField(
                  controller: _singleNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Area Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ] else ...[
                const Text('Choose from predefined areas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _areaTypes.map((a) {
                    final isSelected = _selectedAreas.contains(a);
                    return FilterChip(
                      label: Text(a, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedAreas.add(a);
                          } else {
                            _selectedAreas.remove(a);
                          }
                        });
                      },
                      selectedColor: kRailwayBlue.withOpacity(0.2),
                      checkmarkColor: kRailwayBlue,
                      labelStyle: TextStyle(color: isSelected ? kRailwayBlue : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customAreaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Add Custom Areas (comma-separated)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.add_box),
                    hintText: 'e.g. Platform 4, Waiting Hall B',
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _orderCtrl,
                decoration: const InputDecoration(labelText: 'Display Order', border: OutlineInputBorder(), prefixIcon: Icon(Icons.sort)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                activeColor: kRailwayBlue,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Update Area' : 'Save Areas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
