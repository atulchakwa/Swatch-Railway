import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/area_cleaning_models.dart';
import 'package:crm_train/model/contracts_model.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/model/task_billing_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/repositories/task_billing_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/view/station_cleaning/billing/area_weightage_screen.dart';
import 'area_form_screen.dart';

class AreaConfigScreen extends StatefulWidget {
  final Station? initialStation;
  const AreaConfigScreen({super.key, this.initialStation});

  @override
  State<AreaConfigScreen> createState() => _AreaConfigScreenState();
}

class _AreaConfigScreenState extends State<AreaConfigScreen> {
  List<Station> _stations = [];
  List<AreaConfig> _areas = [];
  Station? _selectedStation;
  bool _isLoadingStations = true;
  bool _isLoadingAreas = false;
  String? _error;
  ContractModel? _contract;
  List<AreaWeightage> _weightages = [];
  double _weightageTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      _stations = await ApiService.getStations();
      final initial = widget.initialStation;
      if (initial != null && initial.uid != null && initial.uid!.isNotEmpty) {
        final match = _stations.where((s) => s.uid == initial.uid).firstOrNull;
        if (match != null) {
          _selectedStation = match;
        } else {
          _stations = [initial, ..._stations];
          _selectedStation = initial;
        }
        _loadAreas();
      } else {
        if (_stations.isNotEmpty) {
          final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
          if (user?.stationId != null && user!.stationId!.isNotEmpty) {
            final match = _stations.where((s) => s.uid == user!.stationId).firstOrNull;
            if (match != null) _selectedStation = match;
          }
          _selectedStation ??= _stations.first;
          _loadAreas();
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _loadAreas() async {
    if (_selectedStation == null) return;
    setState(() => _isLoadingAreas = true);
    try {
      final result = await StationCleaningRepository.listAreas(
        _selectedStation!.uid ?? _selectedStation!.stationCode,
      );
      final rawAreas = result['areas'] as List? ?? [];
      _areas = rawAreas.map((a) => AreaConfig.fromJson(a as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
    _loadBillingMeta();
  }

  Future<void> _loadBillingMeta() async {
    if (_selectedStation == null) return;
    final stationId = _selectedStation!.uid ?? _selectedStation!.stationCode;
    setState(() {
      _contract = null;
      _weightages = [];
      _weightageTotal = 0;
    });
    try {
      final contracts = await ApiService.getStationContracts(stationId, contractType: 'station_cleaning');
      final contract = contracts.where((c) => c.isActive ?? false).firstOrNull ?? (contracts.isNotEmpty ? contracts.first : null);
      if (contract == null || !mounted) return;
      final weightages = await TaskBillingRepository.getWeightages(contract.uid, stationId);
      if (!mounted) return;
      setState(() {
        _contract = contract;
        _weightages = weightages;
        _weightageTotal = weightages.fold<double>(0, (s, w) => s + w.weightage);
      });
    } catch (_) {}
  }

  Future<void> _openWeightage() async {
    if (_selectedStation == null) return;
    final station = _selectedStation!;
    final stationId = station.uid ?? station.stationCode;
    if (_contract == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No station-cleaning contract linked to set weightages for this station'),
      ));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AreaWeightageScreen(
          contractId: _contract!.uid,
          stationId: stationId,
          stationName: station.stationName,
        ),
      ),
    );
    _loadBillingMeta();
  }

  Color _priorityColor(int p) {
    if (p <= 2) return kErrorRed;
    if (p == 3) return kWarningOrange;
    return kSuccessGreen;
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'daily': return 'Daily';
      case 'weekly': return 'Weekly';
      case 'monthly': return 'Monthly';
      default: return f;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Area Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingStations
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: kErrorRed),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadStations, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.white,
                      child: DropdownButtonFormField<Station>(
                        value: _selectedStation,
                        decoration: const InputDecoration(
                          labelText: 'Station',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.train),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _stations.map((s) => DropdownMenuItem(value: s, child: Text('${s.stationCode} - ${s.stationName}'))).toList(),
                        onChanged: (v) {
                          setState(() => _selectedStation = v);
                          _loadAreas();
                        },
                      ),
                    ),
                    _buildWeightageStrip(),
                    Expanded(
                      child: _isLoadingAreas
                          ? const Center(child: CircularProgressIndicator())
                          : _areas.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.map_outlined, size: 80, color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      const Text('No areas configured', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                      const SizedBox(height: 8),
                                      Text('Add areas for ${_selectedStation?.stationName ?? "this station"}', style: TextStyle(color: Colors.grey[400])),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadAreas,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _areas.length,
                                    itemBuilder: (context, index) {
                                      final a = _areas[index];
                                      return Card(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        margin: const EdgeInsets.only(bottom: 10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 40, height: 40,
                                                    decoration: BoxDecoration(
                                                      color: _priorityColor(a.priority).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Center(
                                                      child: Text('P${a.priority}', style: TextStyle(color: _priorityColor(a.priority), fontWeight: FontWeight.bold, fontSize: 14)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
children: [
                                                          Text(a.areaName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            children: [
                                                              _chip(_frequencyLabel(a.cleaningFrequency), kRailwayBlue),
                                                              const SizedBox(width: 6),
                                                              _chip(a.defaultShift, Colors.teal),
                                                              const SizedBox(width: 6),
                                                              _chip('${a.defaultWorkers} workers', Colors.indigo),
                                                              if (_tenderedText(a).isNotEmpty) ...[
                                                                const SizedBox(width: 6),
                                                                _chip(_tenderedText(a), Colors.brown),
                                                              ],
                                                            ],
                                                          ),
                                                        ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: a.status == 'active' ? kSuccessGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      a.status == 'active' ? 'Active' : 'Inactive',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: a.status == 'active' ? kSuccessGreen : Colors.grey,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (a.areaCode.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Text('Code: ${a.areaCode}', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                              ],
                                              if (a.frequencyTimes.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text('Times: ${a.frequencyTimes.join(', ')}', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                              ],
                                              if (_weightages.isNotEmpty)
                                                ..._weightageLine(a),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
      floatingActionButton: _selectedStation != null
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AreaFormScreen(
                      stationId: _selectedStation!.uid ?? _selectedStation!.stationCode,
                    ),
                  ),
                );
                if (result == true) _loadAreas();
              },
              backgroundColor: kRailwayBlue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildWeightageStrip() {
    final noContract = _contract == null;
    final totalOk = _weightageTotal > 0 && (_weightageTotal - 100).abs() <= 0.6;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: kRailwayBlue.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.tune, size: 18, color: kRailwayBlue),
          const SizedBox(width: 8),
          Expanded(
            child: noContract
                ? const Text(
                    'No station-cleaning contract — weightage not available. Add a billing contract to unlock per-area weightage & ₹/sq.ft.',
                    style: TextStyle(fontSize: 12, color: kTextSecondary),
                  )
                : Text(
                    '${_weightages.isNotEmpty ? '${_weightages.length} areas' : 'No weightages set'} · total ${_weightageTotal.toStringAsFixed(1)}% · ${_contract!.contractNumber ?? ''} · per-area ₹/sq.ft. rates',
                    style: const TextStyle(fontSize: 12, color: kTextSecondary),
                  ),
          ),
          const SizedBox(width: 8),
          if (_weightages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: totalOk ? kSuccessGreen : kWarningOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                totalOk ? 'OK 100%' : 'Split needed',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          TextButton.icon(
            onPressed: _openWeightage,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Weightage'),
            style: TextButton.styleFrom(foregroundColor: kRailwayBlue, visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  String _tenderedText(AreaConfig a) {
    final t = a.tenderedAreaSqFt;
    if (t == null) return '';
    return t == t.roundToDouble() ? '${t.toInt()} ft²/day' : '${t.toStringAsFixed(1)} ft²/day';
  }

  List<Widget> _weightageLine(AreaConfig a) {
    AreaWeightage? match;
    for (final w in _weightages) {
      if (w.areaName.trim() == a.areaName.trim()) {
        match = w;
        break;
      }
    }
    if (match == null) return const [];
    final rate = match.ratePerSqFt;
    return [
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: kRailwayBlue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pie_chart_outline, size: 13, color: kRailwayBlue),
            const SizedBox(width: 4),
            Text(
              'Weightage ${match.weightage.toStringAsFixed(1)}%',
              style: const TextStyle(color: kRailwayBlue, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            if (rate != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('·', style: TextStyle(color: kRailwayBlue, fontSize: 11)),
              ),
              const Icon(Icons.currency_rupee, size: 12, color: kErrorRed),
              Text(
                rate == rate.roundToDouble() ? '${rate.toInt()}/ft²' : '${rate.toStringAsFixed(2)}/ft²',
                style: const TextStyle(color: kErrorRed, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
