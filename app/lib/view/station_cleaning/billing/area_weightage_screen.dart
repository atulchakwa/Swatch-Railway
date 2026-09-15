import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/repositories/task_billing_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final TextEditingController weightCtrl;
  final TextEditingController rateCtrl;

  _WeightageRow({
    required this.areaName,
    required this.mainArea,
    required this.tenderedAreaSqFt,
    required this.cleaningFrequency,
    required this.weightCtrl,
    required this.rateCtrl,
  });
}

class _AreaWeightageScreenState extends State<AreaWeightageScreen> {
  List<_WeightageRow> _rows = [];
  bool _loading = true;
  bool _saving = false;
  bool _statusError = false;
  String _status = '';

  bool get _readOnly {
    final role = (Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '').toUpperCase().replaceAll(' ', '_');
    return role == 'CONTRACTOR_SUPERVISOR' || role == 'CONTRACTOR_MASTER' || role == 'RAILWAY_MASTER';
  }

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
          weightCtrl: TextEditingController(text: saved != null ? _fmt(saved.weightage) : ''),
          rateCtrl: TextEditingController(text: saved?.ratePerSqFt != null ? _fmt(saved!.ratePerSqFt!) : ''),
        ));
      }

      if (!mounted) return;
      final hasBlank = rows.any((r) => r.weightCtrl.text.trim().isEmpty);
      setState(() {
        _rows = rows;
        _loading = false;
        _statusError = false;
        if (_readOnly) {
          _status = hasBlank
              ? 'View-only access — weightages shown as saved. Ask contractor admin to fill missing areas.'
              : 'View-only access — current weightages displayed.';
        } else if (rows.isEmpty) {
          _status = '';
        } else if (weightages.isEmpty) {
          _equalSplit();
          _status = 'Auto-filled equal split — total 100%. Adjust then Save All.';
        } else if (hasBlank) {
          _rebalanceForNewAreas();
          _status = 'New area(s) detected — equal share assigned, existing values scaled to keep total 100%.';
        } else {
          _status = '';
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

  void _equalSplit() {
    if (_rows.isEmpty) return;
    var assigned = 0.0;
    for (var i = 0; i < _rows.length; i++) {
      final share = i == _rows.length - 1 ? 100 - assigned : 100 / _rows.length;
      final val = double.parse(share.toStringAsFixed(2));
      _rows[i].weightCtrl.text = _fmt(val);
      assigned += val;
    }
    _snapTotalTo100();
  }

  void _rebalanceForNewAreas() {
    if (_rows.isEmpty) return;
    final unsaved = _rows.where((r) => r.weightCtrl.text.trim().isEmpty).toList();
    final saved = _rows.where((r) => r.weightCtrl.text.trim().isNotEmpty).toList();

    if (unsaved.isEmpty) return;
    if (saved.isEmpty) {
      _equalSplit();
      return;
    }
    final shareEach = 100 / _rows.length;
    final unsavedTotal = shareEach * unsaved.length;
    final savedSum = saved.fold<double>(0, (s, r) => s + (double.tryParse(r.weightCtrl.text.trim()) ?? 0));
    final factor = savedSum > 0 ? (100 - unsavedTotal) / savedSum : 1;

    for (final r in saved) {
      final val = double.tryParse(r.weightCtrl.text.trim()) ?? 0;
      r.weightCtrl.text = _fmt(val * factor);
    }
    for (final r in unsaved) {
      r.weightCtrl.text = _fmt(shareEach);
    }
    _snapTotalTo100();
  }

  void _snapTotalTo100() {
    if (_rows.isEmpty) return;
    final total = _currentTotal();
    final diff = double.parse((100 - total).toStringAsFixed(2));
    if (diff.abs() < 0.001) return;
    final cur = double.tryParse(_rows.first.weightCtrl.text) ?? 0;
    _rows.first.weightCtrl.text = _fmt(cur + diff);
  }

  Future<void> _resetToEqual() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to equal split?'),
        content: const Text('This divides 100% equally across all areas. Any weightages you entered will be overwritten. Your saved area ₹/sq.ft. rates are kept. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _equalSplit();
        _statusError = false;
        _status = 'Equal split applied — total 100%. Adjust then Save All.';
      });
    }
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
      final rt = r.rateCtrl.text.trim();
      final rate = rt.isNotEmpty ? double.tryParse(rt) : null;
      if (rt.isNotEmpty && (rate == null || rate <= 0)) {
        setState(() {
          _statusError = true;
          _status = 'Invalid rate for "${r.areaName}" — enter a positive ₹/sq.ft. or leave blank (contract-derived).';
        });
        return;
      }
    }
    setState(() {
      _saving = true;
      _status = '';
    });
    var saved = 0;
    var withRate = 0;
    try {
      for (final r in _rows) {
        final w = double.tryParse(r.weightCtrl.text) ?? 0;
        final rt = r.rateCtrl.text.trim();
        final rate = rt.isNotEmpty ? double.tryParse(rt) : null;
        await TaskBillingRepository.upsertWeightage({
          'contractId': widget.contractId,
          'stationId': widget.stationId,
          'areaName': r.areaName.trim(),
          'mainArea': r.mainArea,
          'weightage': w,
          'tenderedAreaSqFt': r.tenderedAreaSqFt,
          'cleaningFrequency': r.cleaningFrequency,
          if (rate != null) 'ratePerSqFt': rate,
        });
        saved++;
        if (rate != null) withRate++;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusError = false;
        _status = 'Saved $saved area weightage(s) — each update is versioned + audited.'
            + ' Rates: $withRate area(s) with own ₹/sq.ft.; the rest use the contract-derived rate.';
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
                        child: Text(_status, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _statusError ? kErrorRed : kSuccessGreen)),
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
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Each area can have its own ₹/sq.ft. rate (as per contract). Leave a rate blank for the contract-derived rate.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (ok ? kSuccessGreen : kErrorRed).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Total weightage: ${total.toStringAsFixed(2)}%${ok ? ' ✓' : ' (should be 100%)'}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: ok ? kSuccessGreen : kErrorRed, fontSize: 13),
                    ),
                  ),
                ),
                if (!_readOnly) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _saving || _loading ? null : _resetToEqual,
                    child: const Text('Equal Split'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving || _loading ? null : _saveAll,
                    child: Text(_saving ? 'Saving…' : 'Save All'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowCard(_WeightageRow r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
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
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: r.weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_saving && !_readOnly,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Weightage %',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.currency_rupee, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: r.rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_saving && !_readOnly,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Rate ₹/sq.ft. (this area)',
                      hintText: 'Blank → contract-derived',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}