import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/repositories/station_cleaning_repository.dart';
import 'package:crm_train/repositories/worker_repo.dart';
import 'package:crm_train/utills/app_colors.dart';

class PhotoSubmissionScreen extends StatefulWidget {
  final String stationId;
  final String stationName;

  const PhotoSubmissionScreen({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<PhotoSubmissionScreen> createState() => _PhotoSubmissionScreenState();
}

class _PhotoSubmissionScreenState extends State<PhotoSubmissionScreen> {
  bool _loadingAreas = true;
  List<StationArea> _areas = [];
  List<CleaningSubmission> _todaySubmissions = [];

  StationArea? _selectedArea;
  String? _beforePhotoUrl;
  String? _afterPhotoUrl;
  String _notes = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAreas();
    _loadTodaySubmissions();
  }

  Future<void> _loadAreas() async {
    try {
      final result = await StationCleaningRepository.listAreas(widget.stationId);
      final list = (result['areas'] ?? []) as List;
      setState(() {
        _areas = list.map((e) {
          if (e is StationArea) return e;
          if (e is Map<String, dynamic>) return StationArea.fromJson(e);
          return StationArea.fromJson({});
        }).where((a) => a.name.isNotEmpty).toList();
        _loadingAreas = false;
      });
    } catch (e) {
      setState(() => _loadingAreas = false);
    }
  }

  Future<void> _loadTodaySubmissions() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final result = await StationCleaningRepository.listMySubmissions(date: today);
      final list = (result['submissions'] as List?) ?? [];
      setState(() {
        _todaySubmissions = list.map((e) => CleaningSubmission.fromJson(e is Map<String, dynamic> ? e : {})).toList();
      });
    } catch (_) {}
  }

  Future<String?> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1280);
    if (picked == null) return null;
    try {
      return await WorkerRepository.uploadMedia(picked.path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an area'), backgroundColor: kErrorRed));
      return;
    }
    if (_beforePhotoUrl == null || _afterPhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capture both before and after photos'), backgroundColor: kErrorRed));
      return;
    }
    setState(() => _submitting = true);
    try {
      await StationCleaningRepository.createSubmission({
        'stationId': widget.stationId,
        'stationName': widget.stationName,
        'areaId': _selectedArea!.uid ?? _selectedArea!.stationId,
        'areaName': _selectedArea!.name,
        'beforePhotoUrl': _beforePhotoUrl,
        'afterPhotoUrl': _afterPhotoUrl,
        'notes': _notes,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission created'), backgroundColor: kSuccessGreen));
        setState(() {
          _selectedArea = null;
          _beforePhotoUrl = null;
          _afterPhotoUrl = null;
          _notes = '';
        });
        _loadTodaySubmissions();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Field Work', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.stationName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Submission', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_loadingAreas)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<StationArea>(
                        initialValue: _selectedArea,
                        decoration: const InputDecoration(labelText: 'Select Area *', border: OutlineInputBorder()),
                        isExpanded: true,
                        items: _areas.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                        onChanged: (v) => setState(() => _selectedArea = v),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _photoCaptureCard(
                            'Before Photo', _beforePhotoUrl,
                            () async {
                              final url = await _pickAndUploadImage();
                              if (url != null) setState(() => _beforePhotoUrl = url);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _photoCaptureCard(
                            'After Photo', _afterPhotoUrl,
                            () async {
                              final url = await _pickAndUploadImage();
                              if (url != null) setState(() => _afterPhotoUrl = url);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                      maxLines: 3,
                      onChanged: (v) => _notes = v,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Today's Submissions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_todaySubmissions.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No submissions today', style: TextStyle(color: Colors.grey[600])))))
            else
              ..._todaySubmissions.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: s.status == 'approved' ? kSuccessGreen : s.status == 'rejected' ? kErrorRed : kWarningOrange,
                    radius: 18,
                    child: Icon(
                      s.status == 'approved' ? Icons.check : s.status == 'rejected' ? Icons.close : Icons.schedule,
                      color: Colors.white, size: 20,
                    ),
                  ),
                  title: Text(s.areaName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${s.status} · ${s.submittedAt.isNotEmpty ? s.submittedAt.substring(0, 10) : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.beforePhotoUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showPhoto(context, s.beforePhotoUrl, 'Before'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(s.beforePhotoUrl, width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 24)),
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (s.afterPhotoUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showPhoto(context, s.afterPhotoUrl, 'After'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(s.afterPhotoUrl, width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 24)),
                          ),
                        ),
                    ],
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _photoCaptureCard(String label, String? imageUrl, VoidCallback onCapture) {
    return GestureDetector(
      onTap: onCapture,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: imageUrl != null ? kSuccessGreen : Colors.grey[400]!),
        ),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40)),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: kSuccessGreen, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                  Positioned(
                    bottom: 4, right: 4,
                    child: GestureDetector(
                      onTap: onCapture,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 40, color: Colors.grey[500]),
                  const SizedBox(height: 8),
                  Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
      ),
    );
  }

  void _showPhoto(BuildContext context, String url, String label) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 60)),
          ],
        ),
      ),
    );
  }
}
