import 'package:crm_train/model/performance_billing_models.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class AreaRateConfigScreen extends StatefulWidget {
  final String contractId;
  const AreaRateConfigScreen({super.key, required this.contractId});

  @override
  State<AreaRateConfigScreen> createState() => _AreaRateConfigScreenState();
}

class _AreaRateConfigScreenState extends State<AreaRateConfigScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  BillingConfig? _config;
  late TextEditingController _rateCtrl;
  final Map<String, TextEditingController> _areaRateCtrls = {};
  final Map<String, TextEditingController> _areaWeightCtrls = {};
  List<StationArea> _areas = [];

  @override
  void initState() {
    super.initState();
    _rateCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    for (final c in _areaRateCtrls.values) c.dispose();
    for (final c in _areaWeightCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await ApiService.getPerformanceBillingConfig(widget.contractId);
      if (!mounted) return;
      setState(() {
        _config = c;
        _rateCtrl.text = c.ratePerSqft != null ? '${c.ratePerSqft}' : '';
        _loading = false;
      });
      await _loadAreas();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAreas() async {
    final sid = _config?.stationId;
    if (sid == null || sid.isEmpty) return;
    try {
      final areas = await ApiService.getStationAreas(sid);
      if (!mounted) return;
      setState(() {
        _areas = areas.where((a) => a.active && a.basicAreaSqFt != null).toList();
        for (final a in _areas) {
          final uid = a.uid!;
          _areaRateCtrls[uid] ??= TextEditingController(
            text: _config?.areaRateOverrides[uid] != null && _config!.areaRateOverrides[uid]! > 0
                ? '${_config!.areaRateOverrides[uid]}'
                : '',
          );
          _areaWeightCtrls[uid] ??= TextEditingController(
            text: _config?.areaWeightages[uid] != null && _config!.areaWeightages[uid]! > 0
                ? '${_config!.areaWeightages[uid]}'
                : '',
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load areas for this station';
      });
    }
  }

  Map<String, double> _buildAreaOverrides() {
    final m = <String, double>{};
    _areaRateCtrls.forEach((areaId, ctrl) {
      final v = double.tryParse(ctrl.text.trim());
      if (v != null && v > 0) m[areaId] = v;
    });
    return m;
  }

  Map<String, double> _buildAreaWeightages() {
    final m = <String, double>{};
    _areaWeightCtrls.forEach((areaId, ctrl) {
      final v = double.tryParse(ctrl.text.trim());
      if (v != null && v > 0) m[areaId] = v;
    });
    return m;
  }

  Future<void> _save() async {
    final defaultRate = double.tryParse(_rateCtrl.text.trim());
    if ((defaultRate == null || defaultRate <= 0) && _buildAreaOverrides().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set the default rate or at least one area rate before saving'), backgroundColor: kWarningOrange),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = _config;
      await ApiService.savePerformanceBillingConfig(widget.contractId, {
        'ratePerSqft': defaultRate != null && defaultRate > 0 ? defaultRate : null,
        'areaRateOverrides': _buildAreaOverrides(),
        'areaWeightages': _buildAreaWeightages(),
        'gstRate': c?.gstRate ?? 18,
        'verifiedStatuses': c != null ? List.of(c.verifiedStatuses) : ['approved'],
        'categories': c != null ? c.categories.map((cat) => cat.toJson()).toList() : [],
        'penaltyRules': c != null ? c.penaltyRules.map((r) => r.toJson()).toList() : [],
      });
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area rates saved'), backgroundColor: kSuccessGreen),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: kErrorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Rates (₹/sq.ft.)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _config == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: kErrorRed),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kErrorRed)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildDefaultRateCard(),
                    const SizedBox(height: 10),
                    _buildAreasList(),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kRailwayBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.tips_and_updates, size: 16, color: kRailwayBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Daily billing values each cleaning pass as area sq.ft. × ₹/sq.ft. Leave a rate blank to use the default. '
                              'Set a Weightage % per area — it is shown for reference on the daily bill.',
                              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
                        label: Text(_saving ? 'Saving…' : 'Save Area Rates'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDefaultRateCard() {
    final defaultRate = double.tryParse(_rateCtrl.text.trim());
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Default Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
              'Rate per square foot per execution. Applied to every area that has no override below.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Default rate per sqft (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (defaultRate == null || defaultRate <= 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kWarningOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, size: 14, color: kWarningOrange),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'At least one ₹/sq.ft. rate must be set before daily bills can be generated.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAreasList() {
    if (_areas.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error != null ? _error! : 'No active areas with area size found for this station.',
            style: TextStyle(fontSize: 12, color: _error != null ? kErrorRed : Colors.grey[500]),
          ),
        ),
      );
    }
    final defaultRate = double.tryParse(_rateCtrl.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Area-wise Rates (${_areas.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        for (final a in _areas) _areaTile(a, defaultRate),
      ],
    );
  }

  Widget _areaTile(StationArea a, double? defaultRate) {
    final uid = a.uid!;
    final rateCtrl = _areaRateCtrls[uid]!;
    final weightCtrl = _areaWeightCtrls[uid]!;
    final ov = double.tryParse(rateCtrl.text.trim());
    final wt = double.tryParse(weightCtrl.text.trim());
    final effective = ov ?? defaultRate;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${(a.basicAreaSqFt ?? 0).round()} sqft  •  ${a.cleaningFrequency ?? a.frequencyType ?? ''}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (ov != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: kSuccessGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Text('CUSTOM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kSuccessGreen)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                        child: Text('DEFAULT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '₹${effective == null ? '—' : effective.toStringAsFixed(2)}/sqft',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: effective == null ? kErrorRed : Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 106,
                      child: TextField(
                        controller: rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Rate ₹',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Wt${wt != null ? ' ${wt.toStringAsFixed(2)}%' : ' %'}',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}