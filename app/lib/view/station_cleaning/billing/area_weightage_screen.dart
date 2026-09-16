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

class _RateRow {
  final String areaName;
  final String mainArea;
  final double tenderedAreaSqFt;
  final String cleaningFrequency;
  final TextEditingController rateCtrl;

  _RateRow({
    required this.areaName,
    required this.mainArea,
    required this.tenderedAreaSqFt,
    required this.cleaningFrequency,
    required this.rateCtrl,
  });
}

class _AreaWeightageScreenState extends State<AreaWeightageScreen> {
  List<_RateRow> _rows = [];
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
      r.rateCtrl.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? v.toStringAsFixed(0) : s;
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

      final rows = <_RateRow>[];
      for (final ra in activeAreas) {
        final a = ra is Map ? Map<String, dynamic>.from(ra) : <String, dynamic>{};
        final areaName = (a['areaName'] ?? a['name'] ?? '').toString();
        if (areaName.trim().isEmpty) continue;
        final saved = savedByArea[areaName.trim()];
        rows.add(_RateRow(
          areaName: areaName,
          mainArea: (a['mainArea'] ?? '').toString(),
          tenderedAreaSqFt: double.tryParse((a['tenderedAreaPerDay'] ?? 0).toString()) ?? 0,
          cleaningFrequency: (a['cleaningFrequency'] ?? 'daily').toString(),
          rateCtrl: TextEditingController(text: saved?.ratePerSqFt != null ? _fmt(saved!.ratePerSqFt!) : ''),
        ));
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _statusError = false;
        if (_readOnly) {
          _status = 'View-only access — rates shown as saved. Ask contractor admin to update.';
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

  // Weightage is no longer set by the user; share 100% equally so the
  // backend / daily task billing keeps a valid 100% configuration.
  List<double> _equalShares() {
    if (_rows.isEmpty) return const [];
    final shares = <double>[];
    var assigned = 0.0;
    for (var i = 0; i < _rows.length; i++) {
      final share = i == _rows.length - 1 ? 100 - assigned : 100 / _rows.length;
      final val = double.parse(share.toStringAsFixed(2));
      shares.add(val);
      assigned += val;
    }
    return shares;
  }

  Future<void> _saveAll() async {
    for (final r in _rows) {
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
    final shares = _equalShares();
    var saved = 0;
    try {
      for (var i = 0; i < _rows.length; i++) {
        final r = _rows[i];
        final rt = r.rateCtrl.text.trim();
        final rate = rt.isNotEmpty ? double.tryParse(rt) : null;
        await TaskBillingRepository.upsertWeightage({
          'contractId': widget.contractId,
          'stationId': widget.stationId,
          'areaName': r.areaName.trim(),
          'mainArea': r.mainArea,
          'weightage': shares.isNotEmpty ? shares[i] : 0,
          'tenderedAreaSqFt': r.tenderedAreaSqFt,
          'cleaningFrequency': r.cleaningFrequency,
          if (rate != null) 'ratePerSqFt': rate,
        });
        saved++;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusError = false;
        _status = 'Saved $saved area rate(s) — each update is versioned + audited.';
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
            const Text('Area Rates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.stationName, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
          ],
        ),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
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
                          itemBuilder: (context, index) => _buildRowCard(_rows[index]),
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
              Expanded(child: _heroStat('Rates set', '$withRate', Icons.currency_rupee)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Leave Rate blank to use the contract-derived ₹/sq.ft.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ],
          ),
          if (!_readOnly) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving || _loading ? null : _saveAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kRailwayBlue,
                ),
                icon: Icon(_saving ? Icons.hourglass_top : Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save All Rates'),
              ),
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

  Widget _buildRowCard(_RateRow r) {
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
            TextField(
              controller: r.rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_saving && !_readOnly,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Rate ₹/sq.ft.',
                hintText: 'Blank → contract-derived rate',
                isDense: true,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.currency_rupee, size: 16, color: Colors.grey),
                prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 0),
              ),
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