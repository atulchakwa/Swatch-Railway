import 'package:crm_train/model/annexure_weightage_defaults.dart';
import 'package:crm_train/model/task_billing_models.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/repositories/task_billing_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class AreaWeightageScreen extends StatefulWidget {
  final String contractId;
  final String stationId;
  final String stationName;
  const AreaWeightageScreen({super.key, required this.contractId, required this.stationId, required this.stationName});

  @override
  State<AreaWeightageScreen> createState() => _AreaWeightageScreenState();
}

class _WeightageRow {
  final String areaName;
  final String mainArea;
  final double tenderedAreaSqFt;
  final String cleaningFrequency;
  int? itemNo;
  final TextEditingController weightCtrl;
  final TextEditingController rateCtrl;

  _WeightageRow({
    required this.areaName,
    required this.mainArea,
    required this.tenderedAreaSqFt,
    required this.cleaningFrequency,
    this.itemNo,
    required this.weightCtrl,
    required this.rateCtrl,
  });
}

class _AreaWeightageScreenState extends State<AreaWeightageScreen> {
  List<_WeightageRow> _rows = [];
  List<AreaWeightage> _weightages = [];
  bool _loading = true;
  bool _saving = false;
  bool _defaultsApplied = false;
  bool _statusError = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.weightCtrl.dispose();
      r.rateCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final areaResult = await StationCleaningRepository.listAreas(widget.stationId);
      final rawAreas = (areaResult['areas'] as List?) ?? [];
      final activeAreas = rawAreas.where((a) {
        final m = a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
        return (m['status'] ?? 'active').toString() != 'inactive';
      }).toList();

      final weightages = await TaskBillingRepository.getWeightages(widget.contractId, widget.stationId);
      final savedByArea = {for (final w in weightages) w.areaName.trim(): w};

      final rows = <_WeightageRow>[];
      for (final ra in activeAreas) {
        final a = ra is Map ? Map<String, dynamic>.from(ra) : <String, dynamic>{};
        final areaName = (a['areaName'] ?? a['name'] ?? '').toString();
        if (areaName.trim().isEmpty) continue;
        final saved = savedByArea[areaName.trim()];
        rows.add(_WeightageRow(
          areaName: areaName,
          mainArea: (a['mainArea'] ?? '').toString(),
          tenderedAreaSqFt: double.tryParse((a['tenderedAreaPerDay'] ?? 0).toString()) ?? 0,
          cleaningFrequency: (a['cleaningFrequency'] ?? 'daily').toString(),
          itemNo: saved?.annexureItemNo ?? resolveAnnexureItemNo(mainArea: (a['mainArea'] ?? '').toString(), areaName: areaName),
          weightCtrl: TextEditingController(text: saved != null ? _fmt(saved.weightage) : ''),
          rateCtrl: TextEditingController(text: saved != null && saved.ratePerSqFt != null ? _fmt(saved.ratePerSqFt!) : ''),
        ));
      }

      if (!mounted) return;
      final hasBlank = rows.any((r) => r.weightCtrl.text.trim().isEmpty);
      setState(() {
        _rows = rows;
        _weightages = weightages;
        _loading = false;
        if (weightages.isEmpty && rows.isNotEmpty) {
          _applyDefaults();
          _statusError = false;
          _status = 'Auto-filled Annexure-AB defaults — total 100%. Review then Save All.';
        } else if (hasBlank) {
          _applyDefaults(recompute: false);
          _statusError = false;
          _status = 'New area(s) detected in Area Management — weightage re-split across all areas so the total stays 100%. Review then Save All.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusError = true;
        _status = e.toString();
      });
    }
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? v.toStringAsFixed(0) : s;
  }

  double _currentTotal() {
    var sum = 0.0;
    for (final r in _rows) {
      sum += double.tryParse(r.weightCtrl.text) ?? 0;
    }
    return sum;
  }

  void _applyDefaults({bool recompute = true}) {
    if (_rows.isEmpty) return;
    final byItem = <int, List<_WeightageRow>>{};
    for (final r in _rows) {
      if (recompute) {
        r.itemNo = resolveAnnexureItemNo(mainArea: r.mainArea, areaName: r.areaName) ?? 1;
      }
      byItem.putIfAbsent(r.itemNo ?? 1, () => []).add(r);
    }

    final present = byItem.keys.toSet();
    final hasItem1 = present.contains(1);
    final bucketOf = <int, double>{};
    var presentBaseSum = 0.0;
    for (final itemNo in present) {
      final def = annexureWeightageDefaults.where((d) => d.itemNo == itemNo).firstOrNull;
      bucketOf[itemNo] = def?.weightage ?? 0;
      presentBaseSum += bucketOf[itemNo]!;
    }
    final absentPool = 100 - presentBaseSum;

    double effectiveBucket(int itemNo) {
      var b = bucketOf[itemNo] ?? 0;
      if (hasItem1) {
        if (itemNo == 1) b += absentPool;
      } else if (presentBaseSum > 0) {
        b += absentPool * b / presentBaseSum;
      }
      return b;
    }

    for (final entry in byItem.entries) {
      final itemNo = entry.key;
      final bucket = effectiveBucket(itemNo);
      final rows = entry.value;
      final totalTendered = rows.fold<double>(0, (s, r) => s + r.tenderedAreaSqFt);
      var assigned = 0.0;
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final share = totalTendered > 0
            ? double.parse((bucket * r.tenderedAreaSqFt / totalTendered).toStringAsFixed(2))
            : double.parse((bucket / rows.length).toStringAsFixed(2));
        final val = (i == rows.length - 1)
            ? double.parse((bucket - assigned).toStringAsFixed(2))
            : share;
        assigned += val;
        r.weightCtrl.text = _fmt(val);
      }
    }
    setState(() => _defaultsApplied = true);
  }

  Future<void> _confirmAndApplyDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Annexure-AB defaults?'),
        content: const Text('This recomputes every area weightage from the Annexure-AB table (25 items). The 100% is always split across this station\'s \u201CArea Arrangement\u201D: missing items are added to Item 1 (45%) when a Platform/other area exists, otherwise they are redistributed proportionally across the areas present, so the station total always equals 100%. Your saved rate overrides are kept. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (ok == true) _applyDefaults(recompute: true);
  }

  Future<void> _saveAll() async {
    for (final r in _rows) {
      final w = double.tryParse(r.weightCtrl.text);
      if (w == null || w < 0 || w > 100) {
        setState(() {
          _statusError = true;
          _status = 'Invalid weightage for "${r.areaName}" (0–100%).';
        });
        return;
      }
    }
    setState(() {
      _saving = true;
      _status = '';
    });
    var saved = 0;
    try {
      for (final r in _rows) {
        await TaskBillingRepository.upsertWeightage({
          'contractId': widget.contractId,
          'stationId': widget.stationId,
          'areaName': r.areaName.trim(),
          'mainArea': r.mainArea,
          'annexureItemNo': r.itemNo,
          'weightage': double.tryParse(r.weightCtrl.text) ?? 0,
          'tenderedAreaSqFt': r.tenderedAreaSqFt,
          'cleaningFrequency': r.cleaningFrequency,
          if (r.rateCtrl.text.trim().isNotEmpty) 'ratePerSqFt': double.tryParse(r.rateCtrl.text.trim()),
        });
        saved++;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusError = false;
        _status = 'Saved $saved area weightage(s) — each update is versioned + audited.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusError = true;
        _status = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Area Weightage — ${widget.stationName}'),
        backgroundColor: Colors.brown,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No active areas configured for this station. Add areas first from "Area Arrangement".', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    if (_status.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(_status, style: TextStyle(fontSize: 12, color: _statusError ? kErrorRed : kSuccessGreen)),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) => _buildRowCard(_rows[index]),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    final total = _currentTotal();
    final ok = (total - 100).abs() <= 0.6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total weightage: ${total.toStringAsFixed(2)}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: ok ? kSuccessGreen : kErrorRed),
            ),
          ),
          OutlinedButton(
            onPressed: _saving || _loading ? null : _confirmAndApplyDefaults,
            child: const Text('Load Defaults'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _saving || _loading ? null : _saveAll,
            child: Text(_saving ? 'Saving…' : 'Save All'),
          ),
        ],
      ),
    );
  }

  Widget _buildRowCard(_WeightageRow r) {
    final itemDef = annexureWeightageDefaults.where((d) => d.itemNo == r.itemNo).firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.areaName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (r.mainArea.isNotEmpty)
                        Text(r.mainArea, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text('${r.tenderedAreaSqFt.toStringAsFixed(0)} sq.ft./day · ${r.cleaningFrequency}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                if (itemDef != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.brown.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('Item ${itemDef.itemNo}', style: const TextStyle(fontSize: 11, color: Colors.brown, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    initialValue: r.itemNo,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Annexure item *', isDense: true, border: OutlineInputBorder()),
                    items: [
                      for (final d in annexureWeightageDefaults)
                        DropdownMenuItem(value: d.itemNo, child: Text('${d.itemNo}. ${d.name}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _saving ? null : (v) {
                      setState(() {
                        r.itemNo = v;
                        final def = annexureWeightageDefaults.where((d) => d.itemNo == v).firstOrNull;
                        final cur = double.tryParse(r.weightCtrl.text) ?? 0;
                        if (r.weightCtrl.text.trim().isEmpty || cur == 0) {
                          r.weightCtrl.text = def != null ? _fmt(def.weightage) : '';
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: r.weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Weightage %', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: r.rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Rate ₹/sq.ft.', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            if (itemDef != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(itemDef.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull {
    for (final e in this) {
      return e;
    }
    return null;
  }
}