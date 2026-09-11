import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/base_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:provider/provider.dart';

class WorkerCheckinScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;
  const WorkerCheckinScreen({super.key, this.stationId, this.stationName});

  @override
  State<WorkerCheckinScreen> createState() => _WorkerCheckinScreenState();
}

class _WorkerCheckinScreenState extends State<WorkerCheckinScreen> {
  int _step = 0;
  bool _isScanning = false;
  bool _photoTaken = false;
  bool _gpsVerified = false;
  bool _isSubmitting = false;
  String? _scannedQrData;
  String? _areaName;
  String? _selfieBase64;
  Map<String, dynamic>? _gpsData;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Worker Check-in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 24),
            if (_step == 0) _buildStepScanQR(),
            if (_step == 1) _buildStepSelfie(),
            if (_step == 2) _buildStepGPS(),
            if (_step == 3) _buildStepConfirm(user),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(0, 'Scan QR', Icons.qr_code_scanner),
        _stepLine(0),
        _stepDot(1, 'Selfie', Icons.camera_alt),
        _stepLine(1),
        _stepDot(2, 'GPS', Icons.location_on),
        _stepLine(2),
        _stepDot(3, 'Confirm', Icons.check_circle),
      ],
    );
  }

  Widget _stepDot(int index, String label, IconData icon) {
    final isActive = _step >= index;
    final isCurrent = _step == index;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isActive ? kRailwayBlue : Colors.grey[300],
              shape: BoxShape.circle,
              border: isCurrent ? Border.all(color: kRailwayBlue, width: 3) : null,
            ),
            child: Icon(isActive ? (_step > index ? Icons.check : icon) : icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, color: isActive ? kRailwayBlue : Colors.grey, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _stepLine(int fromIndex) {
    return Container(
      width: 30, height: 2,
      color: _step > fromIndex ? kRailwayBlue : Colors.grey[300],
    );
  }

  Widget _buildStepScanQR() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: kRailwayBlue),
            const SizedBox(height: 16),
            const Text('Scan Area QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Position the QR code within the frame', style: TextStyle(color: kTextSecondary)),
            const SizedBox(height: 24),
            SizedBox(
              width: 250, height: 250,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kRailwayBlue, width: 3),
                ),
                child: Center(
                  child: _isScanning
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code, size: 60, color: Colors.white38),
                            const SizedBox(height: 12),
                            const Text('Camera preview here', style: TextStyle(color: Colors.white38)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan QR Code'),
                  onPressed: () {
                    setState(() {
                      _isScanning = true;
                      _scannedQrData = 'AREA_${DateTime.now().millisecondsSinceEpoch}';
                      _areaName = 'Platform 1 - Main Area';
                    });
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        setState(() {
                          _isScanning = false;
                          _step = 1;
                        });
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                ),
              ],
            ),
            if (_scannedQrData != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kSuccessGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: kSuccessGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Scanned: $_areaName', style: const TextStyle(color: kSuccessGreen, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepSelfie() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.camera_alt, size: 80, color: kRailwayBlue),
            const SizedBox(height: 16),
            const Text('Take a Selfie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Take a selfie to confirm your presence', style: TextStyle(color: kTextSecondary)),
            const SizedBox(height: 20),
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                image: _selfieBase64 != null
                    ? DecorationImage(image: MemoryImage(base64Decode(_selfieBase64!)), fit: BoxFit.cover)
                    : null,
              ),
              child: _selfieBase64 == null
                  ? const Center(child: Icon(Icons.person, size: 60, color: Colors.grey))
                  : null,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_photoTaken ? 'Retake' : 'Take Selfie'),
                  onPressed: () {
                    setState(() {
                      _selfieBase64 = 'base64_placeholder';
                      _photoTaken = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                ),
                if (_photoTaken) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    onPressed: () => setState(() => _step = 2),
                    style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepGPS() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.location_on, size: 80, color: kRailwayBlue),
            const SizedBox(height: 16),
            const Text('Verify Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Enable GPS to verify you are at the area', style: TextStyle(color: kTextSecondary)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity, height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _gpsVerified
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 40, color: kSuccessGreen),
                          const SizedBox(height: 8),
                          const Text('Location Verified', style: TextStyle(fontWeight: FontWeight.bold, color: kSuccessGreen)),
                          if (_gpsData != null) Text('${_gpsData!['lat']}, ${_gpsData!['lng']}', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('Map preview', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(_gpsVerified ? Icons.check_circle : Icons.my_location),
              label: Text(_gpsVerified ? 'Verified' : 'Verify GPS Location'),
              onPressed: _gpsVerified ? null : () {
                setState(() {
                  _gpsData = {'lat': 28.6422, 'lng': 77.2200};
                  _gpsVerified = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _gpsVerified ? kSuccessGreen : kRailwayBlue,
                foregroundColor: Colors.white,
              ),
            ),
            if (_gpsVerified) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
                onPressed: () => setState(() => _step = 3),
                style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepConfirm(user) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 80, color: kSuccessGreen),
            const SizedBox(height: 16),
            const Text('Confirm Check-in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _infoRow('Worker', user?.fullName ?? 'N/A'),
            _infoRow('Area', _areaName ?? 'N/A'),
            _infoRow('Time', DateTime.now().toString().substring(0, 19)),
            _infoRow('Selfie', _photoTaken ? 'Taken' : 'Not taken', _photoTaken ? kSuccessGreen : kErrorRed),
            _infoRow('GPS', _gpsVerified ? 'Verified' : 'Not verified', _gpsVerified ? kSuccessGreen : kErrorRed),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitCheckin,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(_isSubmitting ? 'Submitting...' : 'Confirm Check-in'),
                style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: kErrorRed)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: kTextSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor))),
        ],
      ),
    );
  }

  Future<void> _submitCheckin() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final hour = now.hour;
    final shift = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'night';
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/station-attendance/mark',
        body: {
          'stationId': widget.stationId ?? user.stationId ?? _scannedQrData,
          'workerId': user.uid,
          'date': now.toIso8601String().substring(0, 10),
          'shift': shift,
          'captureMode': 'gps',
          'photoUrl': _selfieBase64,
          'latitude': _gpsData?['lat'],
          'longitude': _gpsData?['lng'],
          'workerName': user.fullName ?? '',
        },
        parser: (d) => d,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in successful!'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
