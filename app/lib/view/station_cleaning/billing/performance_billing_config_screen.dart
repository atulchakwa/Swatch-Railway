import 'package:crm_train/model/performance_billing_models.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class PerformanceBillingConfigScreen extends StatefulWidget {
  final String contractId;
  const PerformanceBillingConfigScreen({super.key, required this.contractId});

  @override
  State<PerformanceBillingConfigScreen> createState() => _PerformanceBillingConfigScreenState();
}

class _PerformanceBillingConfigScreenState extends State<PerformanceBillingConfigScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  BillingConfig? _config;

  // Editable state.
  late List<PerformanceBillingCategory> _categories;
  late List<PenaltyRule> _penaltyRules;
  late TextEditingController _gstCtrl;
  late TextEditingController _otherDeductionsCtrl;
  late TextEditingController _incompletePenaltyCtrl;
  late TextEditingController _rateCtrl;
  late List<String> _verifiedStatuses;
  final Map<String, TextEditingController> _areaRateCtrls = {};
  final Map<String, TextEditingController> _areaWeightCtrls = {};
  List<StationArea> _areas = [];

  @override
  void initState() {
    super.initState();
    _gstCtrl = TextEditingController();
    _otherDeductionsCtrl = TextEditingController();
    _incompletePenaltyCtrl = TextEditingController();
    _rateCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _gstCtrl.dispose();
    _otherDeductionsCtrl.dispose();
    _incompletePenaltyCtrl.dispose();
    _rateCtrl.dispose();
    for (final c in _areaRateCtrls.values) c.dispose();
    for (final c in _areaWeightCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final c = await ApiService.getPerformanceBillingConfig(widget.contractId);
      if (!mounted) return;
      setState(() {
        _config = c;
        _categories = List.of(c.categories);
        _penaltyRules = List.of(c.penaltyRules);
        _gstCtrl.text = '${c.gstRate}';
        _otherDeductionsCtrl.text = c.otherDeductions > 0 ? '${c.otherDeductions}' : '';
        _incompletePenaltyCtrl.text = c.dailyIncompleteExecutionPenalty > 0 ? '${c.dailyIncompleteExecutionPenalty}' : '';
        _rateCtrl.text = c.ratePerSqft != null ? '${c.ratePerSqft}' : '';
        _verifiedStatuses = List.of(c.verifiedStatuses);
        _loading = false;
      });
      setState(() {}); // keep UI reactive while areas load
      await _loadAreas();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
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
          final savedW = _config?.areaWeightages[uid] != null && _config!.areaWeightages[uid]! > 0
              ? _config!.areaWeightages[uid]!
              : 0.0;
          final savedOverride = _config?.areaRateOverrides[uid];
          _areaRateCtrls[uid] ??= TextEditingController(
            text: savedW > 0
                ? (_autoRate(uid, savedW) ?? 0).toStringAsFixed(4)
                : savedOverride != null && savedOverride > 0
                    ? '${savedOverride}'
                    : '',
          );
          _areaWeightCtrls[uid] ??= TextEditingController(
            text: savedW > 0 ? '${savedW}' : '',
          );
        }
      });
    } catch (_) {
      // Areas are optional for saving config; ignore list errors here.
    }
  }

  Map<String, double> _buildAreaOverrides() {
    final m = <String, double>{};
    _areaRateCtrls.forEach((areaId, ctrl) {
      final v = double.tryParse(ctrl.text.trim());
      if (v != null && v > 0) m[areaId] = v;
    });
    _areaWeightCtrls.forEach((areaId, ctrl) {
      final w = double.tryParse(ctrl.text.trim());
      final derived = w != null && w > 0 ? _autoRate(areaId, w) : null;
      if (derived != null && derived > 0) m[areaId] = derived;
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

  double get _weightTotal => _buildAreaWeightages().values.fold<double>(0, (s, v) => s + v);

  double get _annualContractValue => _config?.annualContractValue ?? 0;

  double get _contractDays => (_config?.contractDays ?? 0) > 0 ? _config!.contractDays.toDouble() : 365;

  double _sqftOf(String uid) {
    for (final a in _areas) {
      if (a.uid == uid) return a.basicAreaSqFt ?? 0;
    }
    return 0;
  }

  double? _autoRate(String uid, double weightage) {
    final acv = _annualContractValue;
    final sqft = _sqftOf(uid);
    if (acv <= 0 || sqft <= 0 || weightage <= 0) return null;
    final rate = (acv * weightage / 100 / _contractDays) / sqft;
    return double.parse(rate.toStringAsFixed(4));
  }

  Future<void> _save() async {
    final weightages = _buildAreaWeightages();
    if (weightages.isNotEmpty && (_weightTotal - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Area weightages must total exactly 100% (currently ${_weightTotal.toStringAsFixed(2)}%)'), backgroundColor: kErrorRed));
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final rateText = _rateCtrl.text.trim();
      final hasWeightages = weightages.isNotEmpty;
      await ApiService.savePerformanceBillingConfig(widget.contractId, {
        'ratePerSqft': hasWeightages ? null : (rateText.isEmpty ? null : double.tryParse(rateText) ?? 0),
        'areaRateOverrides': _buildAreaOverrides(),
        'areaWeightages': weightages,
        'gstRate': double.tryParse(_gstCtrl.text.trim()) ?? 18,
        'otherDeductions': double.tryParse(_otherDeductionsCtrl.text.trim()) ?? 0,
        'dailyIncompleteExecutionPenalty': double.tryParse(_incompletePenaltyCtrl.text.trim()) ?? 200,
        'verifiedStatuses': _verifiedStatuses,
        'categories': _categories.map((c) => c.toJson()).toList(),
        'penaltyRules': _penaltyRules.map((r) => r.toJson()).toList(),
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved'), backgroundColor: kSuccessGreen));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: kErrorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _config == null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: kErrorRed),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kErrorRed)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                ))
              : DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      Material(
                        color: kRailwayBlue,
                        child: TabBar(
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          indicatorColor: Colors.white,
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          tabs: const [
                            Tab(text: 'Categories'),
                            Tab(text: 'Area Rates'),
                            Tab(text: 'Penalty'),
                            Tab(text: 'General'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildCategoriesTab(),
                            _buildAreaRatesTab(),
                            _buildPenaltyTab(),
                            _buildGeneralTab(),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save),
                              style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
                              label: Text(_saving ? 'Saving…' : 'Save Configuration'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ── Categories (read-only) ──
  Widget _buildCategoriesTab() {
    final total = _categories.where((c) => c.enabled).fold<int>(0, (s, c) => s + c.maxMarks);
    final dataSourceLabel = {'execution': 'Cleaning Execution', 'inspection': 'Railway Inspection', 'feedback': 'Passenger Feedback'};
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _infoBanner(
          'Category max marks must total exactly 100. Currently $total.',
          ok: total == 100,
        ),
        for (final c in _categories)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kRailwayBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${c.maxMarks}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.source, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(dataSourceLabel[c.dataSource] ?? c.dataSource, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(width: 16),
                      Icon(Icons.straighten, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text('Max Marks: ${c.maxMarks} / 100', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: c.maxMarks / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      color: kRailwayBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Categories are fixed by the system. Execution achievement is value-weighted by area (sqft × rate × executions); Inspection uses railway inspection scores; Feedback uses passenger ratings (0–5 scale).',
          style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.4),
        ),
      ],
    );
  }

  // ── Area Rates ──
  Widget _buildAreaRatesTab() {
    final defaultRate = double.tryParse(_rateCtrl.text.trim());
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: kRailwayBlue.withOpacity(0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                defaultRate == null
                    ? 'Default rate not set — set it in General tab.'
                    : 'Default rate: ₹${defaultRate.toStringAsFixed(2)} / sqft per execution',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: defaultRate == null ? kErrorRed : kRailwayBlue),
              ),
              const SizedBox(height: 4),
              Text(
                'Leave the rate blank to use the default. Set a rate to override the price for that area. '
                'Weightages are shown for reference on the daily bill and must total 100%.',
                style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.35),
              ),
            ],
          ),
        ),
        _buildWeightageTotal(),
        Expanded(
          child: _areas.isEmpty
              ? Center(
                  child: Text('No active areas with area size found for this station',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: _areas.length,
                  itemBuilder: (context, i) {
                    final a = _areas[i];
                    final uid = a.uid!;
                    final rateCtrl = _areaRateCtrls[uid]!;
                    final weightCtrl = _areaWeightCtrls[uid]!;
                    final ov = double.tryParse(rateCtrl.text.trim());
                    final wt = double.tryParse(weightCtrl.text.trim());
                    final effective = ov ?? defaultRate;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
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
                                  Text('${(a.basicAreaSqFt ?? 0).round()} sqft  •  ${a.cleaningFrequency ?? a.frequencyType ?? ''}',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${effective == null ? '—' : effective.toStringAsFixed(2)}/sqft',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                      color: ov != null ? kSuccessGreen : Colors.grey[500]),
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
                                        readOnly: (() {
                                          final w = double.tryParse(weightCtrl.text.trim());
                                          return w != null && w > 0;
                                        })(),
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
                                        onChanged: (_) {
                                          final w = double.tryParse(weightCtrl.text.trim());
                                          final derived = w != null && w > 0 ? _autoRate(uid, w) : null;
                                          if (derived != null) {
                                            rateCtrl.text = derived.toStringAsFixed(4);
                                          } else if (ov == null) {
                                            rateCtrl.text = '';
                                          }
                                          setState(() {});
                                        },
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
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWeightageTotal() {
    final total = _weightTotal;
    final hasAny = total > 0;
    final ok = hasAny && (total - 100).abs() <= 0.01;
    final Color color;
    final String caption;
    if (ok) {
      color = kSuccessGreen;
      caption = 'Weightage total is 100% ✓';
    } else if (hasAny) {
      color = kErrorRed;
      caption = 'Weightage total must be 100%';
    } else {
      color = Colors.grey[500]!;
      caption = 'Optional — set weights per area summing to 100%';
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.percent, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Total Weightage: ${total.toStringAsFixed(2)}%  —  $caption',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ── Penalty ──
  Widget _buildPenaltyTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event_busy, size: 18, color: kErrorRed),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Incomplete Task Execution Penalty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Charged as a flat fixed penalty on ANY day where task execution is below 100%. Applies on top of the score slabs below.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _incompletePenaltyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Penalty amount per incomplete day (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        _infoBanner(
          'Penalty slabs keyed off the overall score. The FIRST matching slab (score >= from AND score < to) is applied.',
          ok: true,
        ),
        for (var i = 0; i < _penaltyRules.length; i++) _penaltyTile(i),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _penaltyRules.add(PenaltyRule(
                uid: 'r${DateTime.now().millisecondsSinceEpoch}', name: 'New slab', fromScore: 0, toScore: 100,
                action: 'PERCENT_OF_ELIGIBLE', value: 5, enabled: true));
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add Penalty Slab'),
        ),
      ],
    );
  }

  Widget _penaltyTile(int i) {
    final r = _penaltyRules[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: r.name,
                    decoration: const InputDecoration(labelText: 'Slab Name', isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => _mutatePenalty(i, (rr) => PenaltyRule(uid: rr.uid, name: v, fromScore: rr.fromScore, toScore: rr.toScore, action: rr.action, value: rr.value, maxAmount: rr.maxAmount, enabled: rr.enabled)),
                  ),
                ),
                const SizedBox(width: 6),
                Switch(
                  value: r.enabled,
                  onChanged: (v) => _mutatePenalty(i, (rr) => PenaltyRule(uid: rr.uid, name: rr.name, fromScore: rr.fromScore, toScore: rr.toScore, action: rr.action, value: rr.value, maxAmount: rr.maxAmount, enabled: v)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: kErrorRed, size: 20),
                  onPressed: () => setState(() => _penaltyRules.removeAt(i)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '${r.fromScore.toInt()}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Score >=', isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => _mutatePenalty(i, (rr) => PenaltyRule(uid: rr.uid, name: rr.name, fromScore: double.tryParse(v) ?? 0, toScore: rr.toScore, action: rr.action, value: rr.value, maxAmount: rr.maxAmount, enabled: rr.enabled)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: '${r.toScore.toInt()}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Score <', isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => _mutatePenalty(i, (rr) => PenaltyRule(uid: rr.uid, name: rr.name, fromScore: rr.fromScore, toScore: double.tryParse(v) ?? 0, action: rr.action, value: rr.value, maxAmount: rr.maxAmount, enabled: rr.enabled)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: '${r.value.toStringAsFixed(r.value == r.value.roundToDouble() ? 0 : 1)}',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: r.action.contains('FIXED') ? 'Amount ₹' : 'Value %', isDense: true, border: const OutlineInputBorder()),
                    onChanged: (v) => _mutatePenalty(i, (rr) => PenaltyRule(uid: rr.uid, name: rr.name, fromScore: rr.fromScore, toScore: rr.toScore, action: rr.action, value: double.tryParse(v) ?? 0, maxAmount: rr.maxAmount, enabled: rr.enabled)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: r.action,
              decoration: const InputDecoration(labelText: 'Action', isDense: true, border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'NONE', child: Text('No Penalty')),
                DropdownMenuItem(value: 'PERCENT_OF_ELIGIBLE', child: Text('% of Eligible Amount')),
                DropdownMenuItem(value: 'PERCENT_OF_MONTHLY_BASE', child: Text('% of Scheduled Value')),
                DropdownMenuItem(value: 'FIXED_AMOUNT', child: Text('Fixed Amount')),
              ],
              onChanged: (v) {
                if (v == null) return;
                _mutatePenalty(i, (rr) => PenaltyRule(uid: rr.uid, name: rr.name, fromScore: rr.fromScore, toScore: rr.toScore, action: v, value: rr.value, maxAmount: rr.maxAmount, enabled: rr.enabled));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mutatePenalty(int i, PenaltyRule Function(PenaltyRule) fn) {
    setState(() => _penaltyRules[i] = fn(_penaltyRules[i]));
  }

  // ── General ──
  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cleaning Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Rate per square foot per execution (₹/sqft). Required to generate scorecards and bills.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rate per sqft (₹)', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _gstCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'GST Rate (%)', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otherDeductionsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Other Contractual Deductions (₹)',
                    helperText: 'Fixed amount deducted per bill (e.g. water charges, misc). 0 = none.',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Execution Counting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text(
                  'Completed executions are counted from APPROVED shift summaries — the approval unit. '
                  'Tasks have no individual approval step: a task is COMPLETED directly by the supervisor and '
                  'the approved shift summary is what feeds billing.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How Billing is Computed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'AREA → SQFT → RATE → ACTUAL EXECUTION → GROSS WORK VALUE\n\n'
                  'Each scheduled cleaning pass for an area is valued as area-sqft × ₹/sqft. '
                  'Scheduled Work Value = Σ(sqft × rate × required executions). '
                  'Actual Work Value = Σ(sqft × rate × executions verified via APPROVED shift summaries). '
                  'Execution achievement = Actual ÷ Scheduled. '
                  'Final score = weighted 50% execution + 20% inspection + 30% feedback. '
                  'The final score is NOT multiplied into the work value — it only selects the '
                  'configured penalty/deduction slab. Net Payable = Actual Work Value − Performance '
                  'Penalty − Other Contractual Deductions, then GST.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoBanner(String text, {required bool ok}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (ok ? kSuccessGreen : kErrorRed).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.warning, color: ok ? kSuccessGreen : kErrorRed, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: ok ? kSuccessGreen : kErrorRed))),
        ],
      ),
    );
  }
}