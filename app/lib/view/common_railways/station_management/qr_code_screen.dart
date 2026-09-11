import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';

class QRCodeScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;
  const QRCodeScreen({super.key, this.stationId, this.stationName});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  List<Station> _stations = [];
  List<StationArea> _areas = [];
  Station? _selectedStation;
  StationArea? _selectedArea;
  bool _isLoadingStations = true;
  bool _isLoadingAreas = false;
  Map<String, dynamic>? _qrData;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      _stations = await ApiService.getStations(active: true);
      if (_stations.isNotEmpty) {
        final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
        if (user?.stationId != null && user!.stationId!.isNotEmpty) {
          final match = _stations.where((s) => s.uid == user!.stationId).firstOrNull;
          if (match != null) _selectedStation = match;
        }
        _selectedStation ??= _stations.first;
        _loadAreas();
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
      _areas = await ApiService.getStationAreas(_selectedStation!.uid ?? '');
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
  }

  Future<void> _generateQR() async {
    if (_selectedArea?.uid == null) return;
    setState(() => _isGenerating = true);
    try {
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-feedback/qr/${_selectedStation!.uid}',
        parser: (d) => d,
      );
      _qrData = result;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kErrorRed));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('QR Code Generator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingStations
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Station & Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<Station>(
                            value: _selectedStation,
                            decoration: const InputDecoration(labelText: 'Station', border: OutlineInputBorder(), prefixIcon: Icon(Icons.train)),
                            items: _stations.map((s) => DropdownMenuItem(value: s, child: Text('${s.stationCode} - ${s.stationName}'))).toList(),
                            onChanged: (v) {
                              setState(() => _selectedStation = v);
                              _loadAreas();
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<StationArea>(
                            value: _selectedArea,
                            decoration: const InputDecoration(labelText: 'Area', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                            items: _areas.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                            onChanged: (v) => setState(() => _selectedArea = v),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isGenerating ? null : _generateQR,
                              icon: _isGenerating
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.qr_code),
                              label: Text(_isGenerating ? 'Generating...' : 'Generate QR Code'),
                              style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_qrData != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              width: 200, height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: _qrData!['qrImageUrl'] != null
                                    ? Image.network(_qrData!['qrImageUrl'], width: 180, height: 180, fit: BoxFit.contain)
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.qr_code, size: 80, color: kRailwayBlue),
                                          const SizedBox(height: 8),
                                          Text(_qrData!['qrData'] ?? 'QR Data', style: const TextStyle(fontSize: 10, color: kTextSecondary)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('${_selectedStation?.stationName ?? ""} - ${_selectedArea?.name ?? ""}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (_qrData!['qrData'] != null) ...[
                              const SizedBox(height: 4),
                              Text('Code: ${_qrData!['qrData']}', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                            ],
                            if (_qrData!['qrImageUrl'] != null) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text('Download'),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Download initiated'), backgroundColor: kSuccessGreen),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.print, size: 18),
                                    label: const Text('Print'),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Print initiated'), backgroundColor: kInfo),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
