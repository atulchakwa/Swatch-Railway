import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:crm_train/repositories/worker_repo.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/utills/app_colors.dart';

class StationWorkerAttendanceScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final String? runInstanceId;
  final String? stationId;
  final String attendanceType; // 'start', 'mid', or 'end'

  const StationWorkerAttendanceScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    this.runInstanceId,
    this.stationId,
    required this.attendanceType,
  });

  @override
  State<StationWorkerAttendanceScreen> createState() => _StationWorkerAttendanceScreenState();
}

class _StationWorkerAttendanceScreenState extends State<StationWorkerAttendanceScreen> {
  int currentStep = 0;
  final picker = ImagePicker();

  File? _selfie;
  String? _selfieUrl;
  Position? _gpsPosition;
  bool _submitting = false;

  Future<Map<String, dynamic>?> _captureAndUploadSelfie() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Selfie Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Front Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;

    final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1920);
    if (picked == null) return null;

    final file = File(picked.path);
    String? url;
    try {
      url = await WorkerRepository.uploadMedia(picked.path);
    } catch (_) {}

    return {'url': url, 'file': file};
  }

  Future<Position?> _captureGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        return Position(
          longitude: 0.0, latitude: 0.0,
          timestamp: DateTime.now(),
          accuracy: 0.0, altitude: 0.0, heading: 0.0, speed: 0.0,
          speedAccuracy: 0.0, altitudeAccuracy: 0.0, headingAccuracy: 0.0,
        );
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitAttendance() async {
    if (_selfieUrl == null && _selfie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selfie is required'), backgroundColor: kWarningOrange),
      );
      return;
    }
    if (_gpsPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS location is required'), backgroundColor: kWarningOrange),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await StationCleaningRepository.markStationAttendance(
        type: widget.attendanceType,
        runInstanceId: widget.runInstanceId ?? '',
        stationId: widget.stationId ?? '',
        imageUrl: _selfieUrl ?? 'captured',
        latitude: _gpsPosition!.latitude,
        longitude: _gpsPosition!.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.attendanceType.toUpperCase()} attendance marked successfully'),
            backgroundColor: kSuccessGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.attendanceType == 'start' ? 'Start Attendance' :
        widget.attendanceType == 'mid' ? 'Mid Check-in' : 'End Attendance';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _submitting
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Submitting attendance...'),
                    ]))
                  : _buildCurrentStepContent(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final labels = ['Selfie', 'GPS', 'Submit'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          final isActive = index == currentStep;
          final isCompleted = index < currentStep;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? kRailwayBlue : isCompleted ? kSuccessGreen : Colors.grey[300],
                  ),
                  alignment: Alignment.center,
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('${index + 1}',
                          style: TextStyle(color: isActive ? Colors.white : Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text(labels[index], style: TextStyle(fontSize: 9, color: isActive ? kRailwayBlue : Colors.grey[500])),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (currentStep) {
      case 0: return _buildSelfieStep();
      case 1: return _buildGpsStep();
      case 2: return _buildSubmitStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildSelfieStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.camera_front_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Take a Selfie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Capture a clear selfie for identity verification.',
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 24),
        if (_selfie != null)
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selfie!, height: 220, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => setState(() { _selfie = null; _selfieUrl = null; }),
                icon: const Icon(Icons.delete_outline, color: kErrorRed),
                label: const Text('Remove', style: TextStyle(color: kErrorRed)),
              ),
            ],
          )
        else
          ElevatedButton.icon(
            onPressed: () async {
              final result = await _captureAndUploadSelfie();
              if (result != null) {
                setState(() {
                  _selfie = result['file'];
                  if (result['url'] != null) _selfieUrl = result['url'];
                });
              }
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Selfie'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kRailwayBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildGpsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.location_on_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Location Capture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('GPS coordinates are mandatory for attendance.',
            style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 24),
        if (_gpsPosition != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kSuccessGreen),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: kSuccessGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Location Captured', style: TextStyle(fontWeight: FontWeight.bold, color: kSuccessGreen)),
                      Text('Lat: ${_gpsPosition!.latitude.toStringAsFixed(5)}, Lng: ${_gpsPosition!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(fontSize: 12, color: Colors.green[800])),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () async {
              final pos = await _captureGps();
              if (pos != null) {
                setState(() => _gpsPosition = pos);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not get GPS. Check location permissions.')),
                  );
                }
              }
            },
            icon: const Icon(Icons.my_location),
            label: const Text('Capture Location Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kRailwayBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.fact_check_outlined, size: 64, color: kRailwayBlue),
        const SizedBox(height: 16),
        Text('Review & Submit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              _reviewRow('Selfie Captured', _selfieUrl != null || _selfie != null),
              const Divider(),
              _reviewRow('GPS Attached', _gpsPosition != null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Icon(done ? Icons.check_circle : Icons.cancel, color: done ? kSuccessGreen : kErrorRed, size: 20),
      ]),
    );
  }

  Widget _buildBottomBar() {
    final canProceed = _canProceedFromCurrentStep();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 4)],
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: const Text('Back', style: TextStyle(color: Colors.black87)),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canProceed
                  ? () {
                      if (currentStep < 2) {
                        setState(() => currentStep++);
                      } else {
                        _submitAttendance();
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kRailwayBlue, disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                currentStep == 2 ? 'Submit Attendance' : 'Continue',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceedFromCurrentStep() {
    switch (currentStep) {
      case 0: return _selfieUrl != null || _selfie != null;
      case 1: return _gpsPosition != null;
      case 2: return (_selfieUrl != null || _selfie != null) && _gpsPosition != null;
      default: return false;
    }
  }
}
