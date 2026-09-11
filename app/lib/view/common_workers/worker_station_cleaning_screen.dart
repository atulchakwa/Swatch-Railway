import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../model/station_run_model.dart';
import '../../repositories/station_run_repository.dart';
import '../../services/api_services.dart';
import '../../utills/app_colors.dart';
import 'worker_pest_control_screen.dart';
import 'worker_garbage_screen.dart';
import 'worker_machine_screen.dart';

class WorkerStationCleaningScreen extends StatefulWidget {
  const WorkerStationCleaningScreen({super.key});

  @override
  State<WorkerStationCleaningScreen> createState() => _WorkerStationCleaningScreenState();
}

class _WorkerStationCleaningScreenState extends State<WorkerStationCleaningScreen> {
  bool _isLoading = true;
  String? _error;
  List<StationCleaningRunModel> _myRuns = [];

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  Future<void> _loadRuns() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final runs = await StationRunRepository.getMyStationRuns();
      if (mounted) setState(() { _myRuns = runs; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'in progress': return Colors.orange;
      case 'pending': return kRailwayBlue;
      default: return Colors.grey;
    }
  }

  IconData _shiftIcon(String shift) {
    switch (shift.toLowerCase()) {
      case 'morning': return Icons.wb_sunny;
      case 'evening': return Icons.wb_twilight;
      case 'night': return Icons.nights_stay;
      default: return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Station Cleaning',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRuns,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadRuns,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : _myRuns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cleaning_services_outlined, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No Station Cleaning Runs Assigned',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your assigned cleaning tasks will appear here\nonce a supervisor assigns them to you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRuns,
                      color: kRailwayBlue,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _myRuns.length,
                        itemBuilder: (context, index) => _buildRunCard(_myRuns[index]),
                      ),
                    ),
    );
  }

  Widget _buildRunCard(StationCleaningRunModel run) {
    final myPlatforms = run.platforms; // All are already filtered by server (only where janitorId matches me)
    final completedCount = myPlatforms.where((p) => p.status.toLowerCase() == 'completed').length;
    final progress = myPlatforms.isEmpty ? 0.0 : completedCount / myPlatforms.length;

    String formattedDate = run.date;
    try {
      formattedDate = DateFormat('dd MMM yyyy').format(DateFormat('yyyy-MM-dd').parse(run.date));
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: InkWell(
        onTap: () => _openRunDetail(run),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kRailwayBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.train_outlined, color: kRailwayBlue, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          run.stationName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(_shiftIcon(run.shift), size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('${run.shift} Shift', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const SizedBox(width: 12),
                            Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(run.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor(run.status).withOpacity(0.4)),
                    ),
                    child: Text(
                      run.status,
                      style: TextStyle(color: _statusColor(run.status), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Platforms
              Text(
                'My Platforms (${myPlatforms.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: myPlatforms.map((p) {
                  final isDone = p.status.toLowerCase() == 'completed';
                  return Chip(
                    label: Text(p.platformNumber, style: TextStyle(color: isDone ? Colors.green[800] : kRailwayBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                    avatar: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : kRailwayBlue, size: 16),
                    backgroundColor: isDone ? Colors.green[50] : kRailwayBlue.withOpacity(0.08),
                    side: BorderSide(color: isDone ? Colors.green[200]! : kRailwayBlue.withOpacity(0.3)),
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Progress
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? Colors.green : kRailwayBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$completedCount/${myPlatforms.length}', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openRunDetail(run),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Start / View Tasks'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRailwayBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRunDetail(StationCleaningRunModel run) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkerStationRunDetailScreen(run: run, onRefresh: _loadRuns)),
    );
  }
}

// ─── Detail Screen ──────────────────────────────────────────────────────────

class WorkerStationRunDetailScreen extends StatefulWidget {
  final StationCleaningRunModel run;
  final VoidCallback onRefresh;

  const WorkerStationRunDetailScreen({super.key, required this.run, required this.onRefresh});

  @override
  State<WorkerStationRunDetailScreen> createState() => _WorkerStationRunDetailScreenState();
}

class _WorkerStationRunDetailScreenState extends State<WorkerStationRunDetailScreen> {
  bool _isSubmitting = false;

  Future<void> _markPlatformComplete(StationPlatformAssignment platform) async {
    String? photoUrl;
    final ImagePicker _picker = ImagePicker();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark ${platform.platformNumber} Complete?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please upload a photo of the completed platform.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
                if (image != null) {
                  // Mock uploading and getting URL
                  // photoUrl = await ApiService.uploadFile(File(image.path));
                  photoUrl = image.path; // temporary
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Photo selected!')));
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Photo'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue),
            child: const Text('Mark Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (photoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please capture a photo before completing!'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Auth token not available');

      // Upload actual photo to S3 / Backend (Simulated here)
      // If we had a real upload, we would replace photoUrl with the remote URL.
      
      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/station-runs/${widget.run.id ?? widget.run.runInstanceId}/complete-platform'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'platformNumber': platform.platformNumber,
          'photoUrl': photoUrl,
        }),
      );
      final decoded = jsonDecode(resp.body);
      if (resp.statusCode != 200 || decoded['success'] != true) {
        throw Exception(decoded['error'] ?? 'Failed to complete platform');
      }

      if (!mounted) return;
      // Update local state
      setState(() {
        final updatedPlatforms = widget.run.platforms.map((p) {
          if (p.platformNumber == platform.platformNumber && p.janitorId == platform.janitorId) {
            return StationPlatformAssignment(
              platformNumber: p.platformNumber,
              janitorId: p.janitorId,
              janitorName: p.janitorName,
              status: 'Completed',
            );
          }
          return p;
        }).toList();
        widget.run.platforms.clear();
        widget.run.platforms.addAll(updatedPlatforms);
        widget.run.status = updatedPlatforms.every((p) => p.status == 'Completed') ? 'Completed' : 'In Progress';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${platform.platformNumber} marked as Completed!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = widget.run.date;
    try {
      formattedDate = DateFormat('EEEE, dd MMM yyyy').format(DateFormat('yyyy-MM-dd').parse(widget.run.date));
    } catch (_) {}

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.run.stationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Run summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kRailwayBlue, kRailwayBlue.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(widget.run.stationName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text(formattedDate, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.schedule, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text('${widget.run.shift} Shift', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(widget.run.status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Your Platform Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  ...widget.run.platforms.map((platform) => _buildPlatformCard(platform)),
                  const SizedBox(height: 24),
                  // ─── Quick Actions ──────────────────────────────────
                  const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _quickActionCard(
                        icon: Icons.bug_report,
                        label: 'Pest Control',
                        color: Colors.brown,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => WorkerPestControlScreen(
                            stationId: widget.run.stationId,
                            stationName: widget.run.stationName,
                          ),
                        )),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _quickActionCard(
                        icon: Icons.delete,
                        label: 'Garbage',
                        color: const Color(0xFF4CAF50),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => WorkerGarbageScreen(
                            stationId: widget.run.stationId,
                            stationName: widget.run.stationName,
                          ),
                        )),
                      )),
                      Expanded(child: _quickActionCard(
                        icon: Icons.precision_manufacturing,
                        label: 'Machines',
                        color: Colors.indigo,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => WorkerMachineScreen(
                            stationId: widget.run.stationId,
                          ),
                        )),
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildPlatformCard(StationPlatformAssignment platform) {
    final isDone = platform.status.toLowerCase() == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isDone ? 1 : 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDone ? Colors.green.withOpacity(0.1) : kRailwayBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDone ? Icons.check_circle : Icons.cleaning_services,
                        color: isDone ? Colors.green : kRailwayBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(platform.platformNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text('Assigned to you', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDone ? 'Completed' : 'Pending',
                    style: TextStyle(
                      color: isDone ? Colors.green[700] : Colors.orange[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (!isDone) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                'Cleaning Checklist:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              ...['Sweep & Mop Floor', 'Clean Benches', 'Empty Dustbins', 'Clean Toilets / Urinals', 'Wash Basin Cleaning'].map(
                (task) => Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(task, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markPlatformComplete(platform),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text('Mark ${platform.platformNumber} as Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRailwayBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text('Cleaning completed — awaiting supervisor review', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(0.15), radius: 22, child: Icon(icon, color: color, size: 24)),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[800]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
