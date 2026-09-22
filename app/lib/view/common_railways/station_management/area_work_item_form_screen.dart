import 'package:flutter/material.dart';
import 'package:crm_train/model/boq_data.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';

const _measurementOptions = <MapEntry<String, String>>[
  MapEntry('Sq Ft', 'sq_ft'),
  MapEntry('Sq Meter', 'sq_meter'),
  MapEntry('Running Ft', 'running_ft'),
  MapEntry('Count / Unit', 'count'),
  MapEntry('Number', 'number'),
  MapEntry('Quantity', 'quantity'),
  MapEntry('As Available', 'as_available'),
  MapEntry('Not Applicable', 'not_applicable'),
];

const _numericMeasurementTypes = <String>{
  'sq_ft', 'sq_meter', 'running_ft', 'count', 'number', 'quantity', 'unit'
};

const _frequencyOptions = <MapEntry<String, String>>[
  MapEntry('Once per day', 'once_daily'),
  MapEntry('Twice per day', 'twice_daily'),
  MapEntry('Three times per day', 'three_times_daily'),
  MapEntry('Four times per day', 'four_times_daily'),
  MapEntry('Once per week', 'once_weekly'),
  MapEntry('Twice per week', 'twice_weekly'),
  MapEntry('Once per fortnight', 'once_fortnightly'),
  MapEntry('Once per month', 'once_monthly'),
  MapEntry('Twice per month', 'twice_monthly'),
  MapEntry('As and when required', 'as_and_when_required'),
  MapEntry('Custom', 'custom'),
  MapEntry('Daily', 'daily'),
  MapEntry('Weekly', 'weekly'),
  MapEntry('Monthly', 'monthly'),
  MapEntry('Shift-wise (3/day)', 'shift_wise'),
  MapEntry('Every 4 hours', '4hrs'),
  MapEntry('Hourly', 'hourly'),
];

const _frequencyUnits = <String>['day', 'week', 'fortnight', 'month', 'shift'];

class AreaWorkItemFormScreen extends StatefulWidget {
  final String stationId;
  final Map<String, dynamic>? existingArea;

  const AreaWorkItemFormScreen({super.key, required this.stationId, this.existingArea});

  @override
  State<AreaWorkItemFormScreen> createState() => _AreaWorkItemFormScreenState();
}

class _AreaWorkItemFormScreenState extends State<AreaWorkItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _workItemCtrl = TextEditingController();
  final _areaNameCtrl = TextEditingController();
  final _mainAreaCtrl = TextEditingController();
  final _subAreaCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _asAvailableActualCtrl = TextEditingController();
  final _freqValueCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  String _measurementType = 'sq_ft';
  String _frequency = 'once_daily';
  String _frequencyUnit = 'day';
  String _status = 'active';

  static const _customAreaKey = '__custom_area__';

  String? _mainAreaSelection;
  String? _subAreaSelection;

  final _mainAreaList = <String>{
    for (final item in boqData) item.mainArea,
  }.toList()
    ..sort();

  final _subAreasByMain = () {
    final m = <String, Set<String>>{};
    for (final item in boqData) {
      (m[item.mainArea] ??= <String>{}).add(item.subArea);
    }
    return <String, List<String>>{
      for (final e in m.entries) e.key: (e.value.toList()..sort()),
    };
  }();

  final _allSubAreas = <String>{
    for (final item in boqData) item.subArea,
  }.toList()
    ..sort();

  List<String> get _currentSubAreaOptions {
    final main = _mainAreaSelection;
    if (main == null || main == _customAreaKey) return _allSubAreas;
    return _subAreasByMain[main] ?? const <String>[];
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existingArea;
    if (e != null) {
      _workItemCtrl.text = (e['workItem'] ?? '').toString();
      _areaNameCtrl.text = (e['areaName'] ?? e['name'] ?? '').toString();

      final existingMain = (e['mainArea'] ?? '').toString();
      _mainAreaCtrl.text = existingMain;
      _mainAreaSelection = _mainAreaList.contains(existingMain) ? existingMain : _customAreaKey;

      final existingSub = (e['subArea'] ?? '').toString();
      _subAreaCtrl.text = existingSub;
      _subAreaSelection =
          _currentSubAreaOptions.contains(existingSub) ? existingSub : _customAreaKey;

      _remarksCtrl.text = (e['remarks'] ?? '').toString();

      final sqft = (e['basicAreaSqFt'] as num?)?.toDouble() ?? 0;
      final qty = (e['quantity'] as num?)?.toDouble();
      _measurementType = (e['measurementType'] ?? (sqft > 0 ? 'sq_ft' : 'as_available')).toString();
      final displayQty = (qty != null && qty > 0) ? qty : (sqft > 0 ? sqft : null);
      if (displayQty != null) _quantityCtrl.text = _numText(displayQty);

      _frequency = (e['frequencyType'] ?? 'once_daily').toString();
      if (_frequency == 'custom') {
        final fv = (e['frequencyValue'] as num?)?.toInt();
        if (fv != null && fv > 0) _freqValueCtrl.text = '$fv';
        _frequencyUnit = (e['frequencyUnit'] ?? 'day').toString();
      }

      final active = e['active'] ?? (e['status'] == null ? true : e['status'] != 'inactive');
      _status = (active == true) ? 'active' : 'inactive';
    }
  }

  @override
  void dispose() {
    _workItemCtrl.dispose();
    _areaNameCtrl.dispose();
    _mainAreaCtrl.dispose();
    _subAreaCtrl.dispose();
    _quantityCtrl.dispose();
    _asAvailableActualCtrl.dispose();
    _freqValueCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  String get _measurementLabel {
    for (final e in _measurementOptions) {
      if (e.value == _measurementType) return e.key;
    }
    return _measurementType;
  }

  String get _quantityFieldLabel {
    switch (_measurementType) {
      case 'sq_ft': return 'Area Size / Quantity (Sq Ft)';
      case 'sq_meter': return 'Quantity (Sq Meter)';
      case 'running_ft': return 'Quantity (Running Ft)';
      case 'count':
      case 'unit': return 'Quantity (Count / Unit)';
      case 'number': return 'Quantity (Number)';
      default: return 'Quantity';
    }
  }

  bool get _isNumericMeasurement => _numericMeasurementTypes.contains(_measurementType);

  bool get _isAsAvailable => _measurementType == 'as_available';

  bool get _isNotApplicable => _measurementType == 'not_applicable';

  void _onMainAreaChanged(String v) {
    setState(() {
      _mainAreaSelection = v;
      if (v != _customAreaKey) {
        _mainAreaCtrl.text = v;
        final subs = _currentSubAreaOptions;
        if (_subAreaSelection != null &&
            _subAreaSelection != _customAreaKey &&
            !subs.contains(_subAreaSelection)) {
          _subAreaSelection = null;
          _subAreaCtrl.clear();
        }
      }
    });
  }

  int _boqTimesFor(String ftype, int? fval, String? funit) {
    switch (ftype) {
      case 'twice_daily':
      case 'two_times_daily':
      case 'twice_weekly':
      case 'twice_monthly':
        return 2;
      case 'three_times_daily':
      case 'shift_wise':
        return 3;
      case 'four_times_daily':
        return 4;
      case 'custom':
        if (funit == 'day' && fval != null && fval > 0) return fval;
        return 1;
      default:
        return 1;
    }
  }

  String _cleaningFreqFor(String ftype, int? fval, String? funit) {
    switch (ftype) {
      case 'once_daily':
      case 'daily':
        return 'daily';
      case 'twice_daily':
      case 'two_times_daily':
        return 'twice_daily';
      case 'three_times_daily':
      case 'shift_wise':
        return 'shift_wise';
      case 'four_times_daily':
        return 'four_times_daily';
      case 'custom':
        if (funit == 'day') {
          if (fval == 2) return 'twice_daily';
          if (fval == 3) return 'shift_wise';
          if (fval == 4) return 'four_times_daily';
          if (fval != null && fval > 4) return '4hrs';
        }
        return 'daily';
      default:
        return 'daily';
    }
  }

  String? _validate() {
    if (_areaNameCtrl.text.trim().isEmpty) {
      return 'Area Name is required';
    }
    if (_isNumericMeasurement) {
      final q = double.tryParse(_quantityCtrl.text.trim());
      if (q == null || q <= 0) {
        return 'Quantity must be a valid positive number for "$_measurementLabel"';
      }
    }
    if (_frequency == 'custom') {
      final fv = int.tryParse(_freqValueCtrl.text.trim());
      if (fv == null || fv <= 0) {
        return 'Custom frequency requires a frequency value greater than 0';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: kErrorRed));
      return;
    }

    setState(() => _isSaving = true);
    final areaName = _areaNameCtrl.text.trim();

    double? quantity;
    if (_isNumericMeasurement) {
      quantity = double.parse(_quantityCtrl.text.trim());
    } else if (_isAsAvailable) {
      final a = double.tryParse(_asAvailableActualCtrl.text.trim());
      quantity = (a != null && a > 0) ? a : null;
    }

    int? freqValue = _frequency == 'custom' ? int.tryParse(_freqValueCtrl.text.trim()) : null;
    String? freqUnit = _frequency == 'custom' ? _frequencyUnit : null;

    final workItem = _workItemCtrl.text.trim();
    final mainArea = _mainAreaCtrl.text.trim();
    final subArea = _subAreaCtrl.text.trim();
    final remarks = _remarksCtrl.text.trim();

    final data = <String, dynamic>{
      'areaName': areaName,
      'name': areaName,
      if (workItem.isNotEmpty) 'workItem': workItem,
      if (mainArea.isNotEmpty) 'mainArea': mainArea,
      if (subArea.isNotEmpty) 'subArea': subArea,
      'measurementType': _measurementType,
      'quantity': quantity,
      'quantityMode': _isNumericMeasurement ? 'numeric' : (_isAsAvailable ? 'as_available' : 'not_applicable'),
      'basicAreaSqFt': _measurementType == 'sq_ft' ? quantity : null,
      'frequencyType': _frequency,
      'frequencyValue': freqValue,
      'frequencyUnit': freqUnit,
      'boqTimesPerPeriod': _boqTimesFor(_frequency, freqValue, freqUnit),
      'cleaningFrequency': _cleaningFreqFor(_frequency, freqValue, freqUnit),
      if (remarks.isNotEmpty) 'remarks': remarks,
      if (remarks.isNotEmpty) 'description': remarks,
      'status': _status,
      'active': _status == 'active',
    };

    try {
      if (widget.existingArea != null) {
        final uid = widget.existingArea!['uid'] ?? widget.existingArea!['id'];
        await StationCleaningRepository.updateArea(uid.toString(), data);
      } else {
        data['stationId'] = widget.stationId;
        await StationCleaningRepository.createArea(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.existingArea != null ? 'Area updated' : 'Area created'),
          backgroundColor: kSuccessGreen,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kErrorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingArea != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Station Area / Work Item' : 'Create Station Area / Work Item',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _workItemCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Work Item',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cleaning_services),
                      hintText: 'e.g. Scrubbing, wet cleaning of floor',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _areaNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Area Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                      hintText: 'e.g. PF-01',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _mainAreaSelection,
                    decoration: const InputDecoration(
                      labelText: 'Main Area',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    hint: const Text('Select Main Area'),
                    isExpanded: true,
                    items: [
                      for (final m in _mainAreaList)
                        DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
                      const DropdownMenuItem<String?>(
                        value: _customAreaKey,
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Custom - Create New'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) _onMainAreaChanged(v);
                    },
                  ),
                  if (_mainAreaSelection == _customAreaKey) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mainAreaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Custom Main Area',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_outlined),
                        hintText: 'e.g. Platforms',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _currentSubAreaOptions.contains(_subAreaSelection) || _subAreaSelection == _customAreaKey
                        ? _subAreaSelection
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Sub Area',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    hint: const Text('Select Sub Area'),
                    isExpanded: true,
                    items: [
                      for (final s in _currentSubAreaOptions)
                        DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
                      const DropdownMenuItem<String?>(
                        value: _customAreaKey,
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Custom - Create New'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _subAreaSelection = v;
                        if (v != _customAreaKey) _subAreaCtrl.text = v;
                      });
                    },
                  ),
                  if (_subAreaSelection == _customAreaKey) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subAreaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Custom Sub Area',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_outlined),
                        hintText: 'e.g. Platform 1',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _measurementType,
                    decoration: const InputDecoration(
                      labelText: 'Measurement Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    items: _measurementOptions.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
                    onChanged: (v) => setState(() {
                      _measurementType = v!;
                      if (!_isNumericMeasurement) _quantityCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_isNumericMeasurement)
                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(
                        labelText: _quantityFieldLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    )
                  else if (_isAsAvailable) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kRailwayBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kRailwayBlue.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: kRailwayBlue),
                          SizedBox(width: 8),
                          Expanded(child: Text('Quantity: As Available', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _asAvailableActualCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Actual Quantity (if known)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ] else if (_isNotApplicable)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kRailwayBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kRailwayBlue.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.do_not_disturb, color: kRailwayBlue),
                          SizedBox(width: 8),
                          Expanded(child: Text('Quantity: Not Applicable / Service Based', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: _frequencyOptions.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
                    onChanged: (v) => setState(() => _frequency = v!),
                  ),
                  if (_frequency == 'custom') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _freqValueCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Frequency Value',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.format_list_numbered),
                              hintText: 'e.g. 3',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _frequencyUnit,
                              decoration: const InputDecoration(
                                labelText: 'Frequency Unit',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.schedule),
                              ),
                              items: _frequencyUnits
                                  .map((u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(
                                            'Per ${u == 'day' ? 'Day' : u == 'week' ? 'Week' : u == 'fortnight' ? 'Fortnight' : u == 'month' ? 'Month' : 'Shift'}'),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _frequencyUnit = v!),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _remarksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                      hintText: 'e.g. Four times daily as required',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.toggle_on),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check),
                          label: Text(isEdit ? 'Save' : 'Create'),
                          style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _numText(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}