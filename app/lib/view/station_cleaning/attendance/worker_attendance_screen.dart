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
  final String attendanceType;

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
  final picker = ImagePicker();

  File? _selfie;
  String? _selfieUrl;
  Position? _gpsPosition;
  bool _submitting = false;
  String _livenessChallenge = '';

  bool _isCapturingSelfie = false;
  bool _isCapturingGps = false;

  @override
  void initState() {
    super.initState();
    _generateChallenge();
  }

  void _generateChallenge() {
    _livenessChallenge = 'SMILE';
  }

  Future<Map<String, dynamic>?> _captureSelfie() async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
      preferredCameraDevice: CameraDevice.front,
    );
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
        livenessChallenge: _livenessChallenge,
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
      body: _submitting
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Submitting attendance...'),
            ]))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Daily Attendance',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kRailwayBlue),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Show a wide smile in your selfie.\nCamera capture only.',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  _buildVerificationCard(
                    title: 'Selfie Verification',
                    subtitle: _selfie != null ? 'Selfie captured successfully' : 'Take a selfie with a wide smile',
                    icon: Icons.camera_front,
                    isVerified: _selfie != null,
                    isVerifying: _isCapturingSelfie,
                    onVerify: () async {
                      setState(() => _isCapturingSelfie = true);
                      final result = await _captureSelfie();
                      if (result != null) {
                        setState(() {
                          _selfie = result['file'];
                          if (result['url'] != null) _selfieUrl = result['url'];
                        });
                      }
                      if (mounted) setState(() => _isCapturingSelfie = false);
                    },
                    onRemove: _selfie != null ? () => setState(() { _selfie = null; _selfieUrl = null; _generateChallenge(); }) : null,
                  ),
                  const SizedBox(height: 24),

                  _buildVerificationCard(
                    title: 'Location Verification',
                    subtitle: _gpsPosition != null
                        ? 'GPS: ${_gpsPosition!.latitude.toStringAsFixed(5)}, ${_gpsPosition!.longitude.toStringAsFixed(5)}'
                        : 'Verify your current location',
                    icon: Icons.location_on,
                    isVerified: _gpsPosition != null,
                    isVerifying: _isCapturingGps,
                    onVerify: () async {
                      setState(() => _isCapturingGps = true);
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
                      if (mounted) setState(() => _isCapturingGps = false);
                    },
                  ),

                  const Spacer(),

                  ElevatedButton(
                    onPressed: (_selfie != null && _gpsPosition != null) ? _submitAttendance : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRailwayBlue,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Mark Present',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isVerified,
    required bool isVerifying,
    required VoidCallback onVerify,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isVerified ? kSuccessGreen : Colors.grey[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isVerified ? kSuccessGreen.withOpacity(0.1) : kRailwayBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isVerified ? kSuccessGreen : kRailwayBlue, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          if (isVerified)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRemove != null)
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(Icons.delete_outline, color: kErrorRed, size: 20),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: kSuccessGreen, size: 32),
              ],
            )
          else if (isVerifying)
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: kRailwayBlue),
            )
          else
            TextButton(
              onPressed: onVerify,
              style: TextButton.styleFrom(
                backgroundColor: kRailwayBlue.withOpacity(0.1),
                foregroundColor: kRailwayBlue,
              ),
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }
}
