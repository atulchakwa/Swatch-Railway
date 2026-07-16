import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/repositories/worker_repo.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';

class FormAreaSelection {
  StationArea? selectedArea;
  StationZone? selectedZone;
  List<StationZone> zones = [];
  bool isLoadingZones = false;
}

class StationCleaningFormScreen extends StatefulWidget {
  const StationCleaningFormScreen({super.key});

  @override
  State<StationCleaningFormScreen> createState() => _StationCleaningFormScreenState();
}

class _StationCleaningFormScreenState extends State<StationCleaningFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoadingStations = true;
  bool isLoadingAreas = false;
  bool isSaving = false;

  List<Station> stations = [];
  List<StationArea> areas = [];

  Station? selectedStation;
  final List<FormAreaSelection> _areaSelections = [FormAreaSelection()];

  late TextEditingController _dateCtrl;
  late TextEditingController _startTimeCtrl;
  late TextEditingController _endTimeCtrl;
  late TextEditingController _manpowerCtrl;
  late TextEditingController _machineCtrl;
  late TextEditingController _areaCoveredCtrl;
  late TextEditingController _areaUncleanedCtrl;
  late TextEditingController _garbageCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;

  String _shift = 'Morning';
  DateTime? _cleaningDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final Map<String, bool> _activities = {};
  String? _beforePhotoUrl;
  String? _afterPhotoUrl;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickPhoto(bool isBefore) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      try {
        final url = await WorkerRepository.uploadMedia(image.path);
        if (mounted && url.isNotEmpty) {
          setState(() {
            if (isBefore) {
              _beforePhotoUrl = url;
            } else {
              _afterPhotoUrl = url;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photo: $e'), backgroundColor: kErrorRed),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController();
    _startTimeCtrl = TextEditingController();
    _endTimeCtrl = TextEditingController();
    _manpowerCtrl = TextEditingController();
    _machineCtrl = TextEditingController();
    _areaCoveredCtrl = TextEditingController();
    _areaUncleanedCtrl = TextEditingController();
    _garbageCtrl = TextEditingController();
    _remarksCtrl = TextEditingController();
    _latCtrl = TextEditingController();
    _lngCtrl = TextEditingController();

    for (final a in stationCleaningActivities) {
      _activities[a] = false;
    }

    _loadStations();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _manpowerCtrl.dispose();
    _machineCtrl.dispose();
    _areaCoveredCtrl.dispose();
    _areaUncleanedCtrl.dispose();
    _garbageCtrl.dispose();
    _remarksCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => isLoadingStations = true);
    try {
      final result = await ApiService.getStations();
      if (mounted) {
        setState(() {
          stations = result;
          isLoadingStations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingStations = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stations: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  Future<void> _loadAreas() async {
    if (selectedStation == null) return;
    setState(() => isLoadingAreas = true);
    try {
      final result = await ApiService.getStationAreas(selectedStation!.uid ?? '');
      if (mounted) {
        setState(() {
          areas = result;
          for (final selection in _areaSelections) {
            selection.selectedArea = null;
            selection.selectedZone = null;
            selection.zones = [];
          }
          isLoadingAreas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingAreas = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load areas: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  Future<void> _loadZones(FormAreaSelection selection) async {
    if (selectedStation == null || selection.selectedArea == null) return;
    setState(() => selection.isLoadingZones = true);
    try {
      final result = await ApiService.getStationZones(selectedStation!.uid ?? '', areaId: selection.selectedArea!.uid ?? '');
      if (mounted) {
        setState(() {
          selection.zones = result;
          selection.selectedZone = null;
          selection.isLoadingZones = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => selection.isLoadingZones = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load zones: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _cleaningDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _cleaningDate = picked;
        _dateCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _pickTime(TextEditingController ctrl, TimeOfDay? time, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
    if (picked != null) {
      onPicked(picked);
      ctrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  void _getLocation() {
    _latCtrl.text = '12.9716';
    _lngCtrl.text = '77.5946';
  }

  Map<String, dynamic> _buildPayload({required bool isDraft}) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final checkedActivities = _activities.entries.where((e) => e.value).map((e) => e.key).toList();
    
    final firstSelection = _areaSelections.first;
    final List<Map<String, dynamic>> areasList = _areaSelections.map((selection) {
      return {
        'areaId': selection.selectedArea?.uid ?? '',
        'areaName': selection.selectedArea?.name ?? '',
        'zoneId': selection.selectedZone?.uid ?? '',
        'zoneName': selection.selectedZone?.name ?? '',
      };
    }).toList();

    return {
      'formId': 'SCF-${DateTime.now().millisecondsSinceEpoch}',
      'stationId': selectedStation!.uid ?? '',
      'stationName': selectedStation!.stationName,
      'division': selectedStation!.division,
      'submittedBy': user?.uid ?? '',
      'submittedByName': user?.fullName ?? '',
      'status': isDraft ? 'draft' : 'submitted',
      'cleaningDate': _dateCtrl.text,
      'shift': _shift,
      'startTime': _startTimeCtrl.text,
      'endTime': _endTimeCtrl.text,
      'manpowerCount': int.tryParse(_manpowerCtrl.text) ?? 0,
      'machineCount': int.tryParse(_machineCtrl.text) ?? 0,
      'areaCovered': double.tryParse(_areaCoveredCtrl.text) ?? 0,
      'areaUncleaned': double.tryParse(_areaUncleanedCtrl.text) ?? 0,
      'garbageCollected': double.tryParse(_garbageCtrl.text) ?? 0,
      'remarks': _remarksCtrl.text.trim(),
      'latitude': double.tryParse(_latCtrl.text) ?? 0,
      'longitude': double.tryParse(_lngCtrl.text) ?? 0,
      'activities': checkedActivities,
      'photos': [
        if (_beforePhotoUrl != null) {'url': _beforePhotoUrl, 'type': 'before'},
        if (_afterPhotoUrl != null) {'url': _afterPhotoUrl, 'type': 'after'},
      ],
      
      // Root level fields for backward compatibility
      'areaId': firstSelection.selectedArea?.uid ?? '',
      'areaName': firstSelection.selectedArea?.name ?? '',
      'zoneId': firstSelection.selectedZone?.uid ?? '',
      'zoneName': firstSelection.selectedZone?.name ?? '',
      
      // Multi-area list
      'areasList': areasList,
    };
  }

  Future<void> _saveDraft() async {
    if (selectedStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a station')));
      return;
    }
    setState(() => isSaving = true);
    try {
      await ApiService.createStationCleaningForm(_buildPayload(isDraft: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _submitForReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a station')));
      return;
    }
    setState(() => isSaving = true);
    try {
      await ApiService.createStationCleaningForm(_buildPayload(isDraft: false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for review'), backgroundColor: kSuccessGreen));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Cleaning Form', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              _buildSectionCard(
                icon: Icons.train,
                iconColor: kRailwayBlue,
                title: 'Station Selection',
                children: [
                  DropdownButtonFormField<Station>(
                    value: selectedStation,
                    decoration: const InputDecoration(
                      labelText: 'Select Station *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.train),
                    ),
                    items: stations.map((s) => DropdownMenuItem(value: s, child: Text(s.stationName))).toList(),
                    onChanged: isLoadingStations ? null : (v) {
                      setState(() { selectedStation = v; areas = []; });
                      if (v != null) _loadAreas();
                    },
                    validator: (v) => v == null ? 'Please select a station' : null,
                  ),
                  if (isLoadingStations) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                  const SizedBox(height: 14),

                  if (selectedStation != null) ...[
                    const Divider(height: 24),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _areaSelections.length,
                      itemBuilder: (context, index) {
                        final selection = _areaSelections[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index > 0) const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Area / Platform #${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kRailwayBlue),
                                ),
                                if (_areaSelections.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _areaSelections.removeAt(index);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<StationArea>(
                              value: selection.selectedArea,
                              decoration: InputDecoration(
                                labelText: (selection.selectedArea != null && selection.selectedArea!.name.toLowerCase().contains('platform'))
                                    ? 'Select Platform'
                                    : 'Select Area / Platform',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.layers),
                              ),
                              items: areas.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                              onChanged: isLoadingAreas ? null : (v) {
                                setState(() { selection.selectedArea = v; selection.selectedZone = null; selection.zones = []; });
                                if (v != null) _loadZones(selection);
                              },
                            ),
                            if (isLoadingAreas) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                            const SizedBox(height: 14),

                            if (selection.selectedArea != null && selection.zones.isEmpty && !selection.isLoadingZones)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  (selection.selectedArea!.name.toLowerCase().contains('platform'))
                                      ? 'No areas configured for this platform (Optional)'
                                      : 'No zones configured for this area (Optional)',
                                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              DropdownButtonFormField<StationZone>(
                                value: selection.selectedZone,
                                decoration: InputDecoration(
                                  labelText: (selection.selectedArea != null && selection.selectedArea!.name.toLowerCase().contains('platform'))
                                      ? 'Select Area (Optional)'
                                      : 'Select Zone (Optional)',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.map),
                                ),
                                items: selection.zones.map((z) => DropdownMenuItem(value: z, child: Text(z.name))).toList(),
                                onChanged: selection.isLoadingZones || selection.zones.isEmpty ? null : (v) { setState(() { selection.selectedZone = v; }); },
                              ),
                            if (selection.isLoadingZones) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _areaSelections.add(FormAreaSelection());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add More Area / Platform'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kRailwayBlue,
                          side: const BorderSide(color: kRailwayBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              _buildSectionCard(
                icon: Icons.schedule,
                iconColor: Colors.teal,
                title: 'Date & Time',
                children: [
                  TextFormField(
                    controller: _dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cleaning Date *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    readOnly: true,
                    onTap: _pickDate,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _shift,
                    decoration: const InputDecoration(labelText: 'Shift *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.brightness_6)),
                    items: ['Morning', 'Evening', 'Night'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _shift = v); },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _startTimeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          readOnly: true,
                          onTap: () => _pickTime(_startTimeCtrl, _startTime, (t) => _startTime = t),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _endTimeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          readOnly: true,
                          onTap: () => _pickTime(_endTimeCtrl, _endTime, (t) => _endTime = t),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildSectionCard(
                icon: Icons.engineering,
                iconColor: kSuccessGreen,
                title: 'Resources',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _manpowerCtrl,
                          decoration: const InputDecoration(labelText: 'Manpower Count', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people)),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _machineCtrl,
                          decoration: const InputDecoration(labelText: 'Machine Count', border: OutlineInputBorder(), prefixIcon: Icon(Icons.precision_manufacturing)),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildSectionCard(
                icon: Icons.area_chart,
                iconColor: kWarningOrange,
                title: 'Area & Waste',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _areaCoveredCtrl,
                          decoration: const InputDecoration(labelText: 'Area Covered (sqm)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _areaUncleanedCtrl,
                          decoration: const InputDecoration(labelText: 'Area Uncleaned (sqm)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _garbageCtrl,
                    decoration: const InputDecoration(labelText: 'Garbage Collected (kg)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.delete)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildSectionCard(
                icon: Icons.location_on,
                iconColor: kWarningOrange,
                title: 'GPS Location',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latCtrl,
                          decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lngCtrl,
                          decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _getLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Get Location'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildSectionCard(
                icon: Icons.checklist,
                iconColor: kSuccessGreen,
                title: 'Activities Checklist',
                children: stationCleaningActivities.map((activity) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(activity, style: const TextStyle(fontSize: 14)),
                    value: _activities[activity],
                    onChanged: (v) { setState(() { _activities[activity] = v ?? false; }); },
                    activeColor: kSuccessGreen,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              _buildSectionCard(
                icon: Icons.photo_library,
                iconColor: Colors.indigo,
                title: 'Photos',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Before', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _pickPhoto(true),
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: _beforePhotoUrl != null
                                    ? Center(child: Text('Photo Added', style: TextStyle(color: kSuccessGreen, fontSize: 12)))
                                    : const Center(child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo, color: Colors.grey),
                                          SizedBox(height: 4),
                                          Text('Add Photo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      )),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('After', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _pickPhoto(false),
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: _afterPhotoUrl != null
                                    ? Center(child: Text('Photo Added', style: TextStyle(color: kSuccessGreen, fontSize: 12)))
                                    : const Center(child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo, color: Colors.grey),
                                          SizedBox(height: 4),
                                          Text('Add Photo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      )),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: isSaving ? null : _saveDraft,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kRailwayBlue,
                          side: const BorderSide(color: kRailwayBlue),
                        ),
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save Draft'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _submitForReview,
                        style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit for Review'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
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
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
