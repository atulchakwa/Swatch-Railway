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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Area Weightage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.stationName, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
          ],
        ),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.donut_small, color: Colors.white),
            tooltip: 'Distribute weightage',
            onPressed: _readOnly ? null : _resetToEqual,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dashboard_customize_outlined, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text('No active areas configured for this station.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        const Text('Add areas first from "Area Arrangement".', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    _buildStatusBanner(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) => _buildRowCard(_rows[index], index),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatusBanner() {
    if (_status.isEmpty) return const SizedBox.shrink();
    final Color bg = _statusError ? kErrorRed : kSuccessGreen;
    final String msg = _status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: bg.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(_statusError ? Icons.error_outline : Icons.check_circle_outline, size: 18, color: bg),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: bg, fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
      ],
    );
  }

  Widget _buildHeader() {
    final total = _currentTotal();
    final ok = (total - 100).abs() <= 0.6;
    final withRate = _rows.where((r) => r.rateCtrl.text.trim().isNotEmpty).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kRailwayBlue, Color(0xFF2A5AB8)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: kRailwayBlue.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _heroStat('Areas', '${_rows.length}', Icons.dashboard_outlined)),
              SizedBox(
                height: 70,
                width: 70,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (total / 100).clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: Colors.white24,
                      color: ok ? Colors.white : const Color(0xFFFFD54F),
                    ),
                    Center(
                      child: Text(
                        '${total.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _heroStat('Rates set', '$withRate', Icons.currency_rupee)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ok ? Icons.check_circle : Icons.info_outline, size: 14, color: ok ? Colors.white : const Color(0xFFFFD54F)),
              const SizedBox(width: 6),
              Text(
                ok ? 'Distributed — total ${total.toStringAsFixed(2)}%' : 'Total ${total.toStringAsFixed(2)}% — must add up to 100%',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ok ? Colors.white : const Color(0xFFFFD54F)),
              ),
            ],
          ),
          if (!_readOnly) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || _loading ? null : _resetToEqual,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                      backgroundColor: Colors.transparent,
                    ),
                    icon: const Icon(Icons.percent, size: 18),
                    label: const Text('Equal Split'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving || _loading ? null : _saveAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kRailwayBlue,
                    ),
                    icon: Icon(_saving ? Icons.hourglass_top : Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving…' : 'Save All'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const List<Color> _avatarPalette = [
    Color(0xFF4E79A7), Color(0xFF59A14F), Color(0xFFF28E2B),
    Color(0xFFE15759), Color(0xFFB07AA1), Color(0xFF76B7B2),
    Color(0xFFEDC948), Color(0xFF9C755F),
  ];

  Widget _buildRowCard(_WeightageRow r, int index) {
    final w = double.tryParse(r.weightCtrl.text) ?? 0;
    final filled = r.weightCtrl.text.trim().isNotEmpty;
    final hasRate = r.rateCtrl.text.trim().isNotEmpty;
    final avatarColor = _avatarPalette[r.areaName.hashCode.abs() % _avatarPalette.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarColor.withValues(alpha: 0.14),
                  child: Text(
                    r.areaName.isEmpty ? '?' : r.areaName.characters.first.toUpperCase(),
                    style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.areaName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      if (r.mainArea.isNotEmpty)
                        Text(r.mainArea, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _chip('${r.tenderedAreaSqFt.toStringAsFixed(0)} sq.ft.', Icons.square_foot),
                          const SizedBox(width: 6),
                          _chip(r.cleaningFrequency, Icons.refresh),
                          if (hasRate) ...[
                            const SizedBox(width: 6),
                            _chip('₹${r.rateCtrl.text} /sq.ft.', Icons.currency_rupee, accent: kSuccessGreen),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: r.weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_saving && !_readOnly,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Weightage %',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.percent, size: 16, color: Colors.grey),
                      ),
                      suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: r.rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_saving && !_readOnly,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Rate ₹/sq.ft.',
                      hintText: 'Blank → contract',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (w / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.grey[200],
                      color: filled ? kRailwayBlue : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  filled ? '${w.toStringAsFixed(2)}%' : '—',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: filled ? kRailwayBlue : Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, IconData icon, {Color accent = kRailwayBlue}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}