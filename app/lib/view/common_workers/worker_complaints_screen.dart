import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/worker_controller.dart';
import '../../repositories/worker_repo.dart';
import '../../utills/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class ComplaintModel {
  final String complaintId;
  final String coachId;
  final String category;
  final String description;
  final String status;
  final DateTime raisedDate;
  final String? photoUrl;
  final String? assignedTo;
  final String? resolutionRemark;

  ComplaintModel({
    required this.complaintId,
    required this.coachId,
    required this.category,
    required this.description,
    required this.status,
    required this.raisedDate,
    this.photoUrl,
    this.assignedTo,
    this.resolutionRemark,
  });

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      complaintId: json['complaintId'] ?? json['id'] ?? '',
      coachId: json['coachNo'] ?? json['coachId'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      status: _normaliseStatus(json['status']?.toString() ?? 'OPEN'),
      raisedDate: _parseDate(json['createdAt'] ?? json['date']),
      photoUrl: json['photoUrl']?.toString(),
      assignedTo: json['assignedTo']?.toString() ??
          json['supervisorName']?.toString(),
      resolutionRemark: json['resolutionRemark']?.toString(),
    );
  }

  static String _normaliseStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'OPEN':
        return 'Raised';
      case 'ACKNOWLEDGED':
        return 'Acknowledged';
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return 'In Progress';
      case 'ESCALATED':
        return 'Escalated';
      case 'RESOLVED':
        return 'Resolved';
      case 'CLOSED':
        return 'Closed';
      default:
        return raw;
    }
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() => {
    'complaintId': complaintId,
    'coachNo': coachId,
    'category': category,
    'description': description,
    'status': status,
    'createdAt': raisedDate.toIso8601String(),
    'photoUrl': photoUrl,
    'assignedTo': assignedTo,
    'resolutionRemark': resolutionRemark,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Complaints List Screen
// ─────────────────────────────────────────────────────────────────────────────
class WorkerComplaintsScreen extends StatefulWidget {
  const WorkerComplaintsScreen({super.key});

  @override
  State<WorkerComplaintsScreen> createState() => _WorkerComplaintsScreenState();
}

class _WorkerComplaintsScreenState extends State<WorkerComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ComplaintModel> complaints = [];
  bool isLoading = true;
  String? error;

  // SharedPreferences key for local complaint cache (scoped per run instance)
  static const _kCachePrefix = 'local_complaints_';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Local cache helpers ──────────────────────────────────────────────────

  Future<String?> _getRunInstanceId() async {
    final controller = Get.find<WorkerController>();
    return controller.resolveRunInstanceId();
  }

  Future<List<ComplaintModel>> _loadCachedComplaints(String runInstanceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kCachePrefix$runInstanceId');
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedComplaints(
      String runInstanceId, List<ComplaintModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list.map((c) => c.toJson()).toList());
      await prefs.setString('$_kCachePrefix$runInstanceId', encoded);
    } catch (_) {}
  }

  Future<void> _addToCache(String runInstanceId, ComplaintModel c) async {
    final cached = await _loadCachedComplaints(runInstanceId);
    // Avoid duplicates
    final exists = cached.any((e) => e.complaintId == c.complaintId);
    if (!exists) {
      cached.insert(0, c);
      await _saveCachedComplaints(runInstanceId, cached);
    }
  }

  /// Merges server list with local cache, deduplicating by complaintId.
  /// Server data takes precedence (fresher status). Local-only entries appended.
  List<ComplaintModel> _merge(
      List<ComplaintModel> server, List<ComplaintModel> cached) {
    final serverIds = server.map((c) => c.complaintId).toSet();
    final localOnly =
        cached.where((c) => !serverIds.contains(c.complaintId)).toList();
    return [...server, ...localOnly];
  }

  Future<void> _loadComplaints() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final runInstanceId = await _getRunInstanceId();

      // Always load from local cache first so screen is never blank
      final cached = runInstanceId != null
          ? await _loadCachedComplaints(runInstanceId)
          : <ComplaintModel>[];

      if (!mounted) return;
      if (cached.isNotEmpty) {
        setState(() {
          complaints = cached;
          isLoading = false;
        });
      }

      if (runInstanceId == null || runInstanceId.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      // Try to fetch from server (may return empty if endpoint not ready)
      final response = await WorkerRepository.getObhsComplaints(
        runInstanceId: runInstanceId,
      );

      final raw = response['complaints'] ??
          response['data'] ??
          response['items'] ??
          [];

      final serverList = (raw as List)
          .map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Merge: server data + locally-cached complaints not yet on server
      final merged = _merge(serverList, cached);

      // Update cache with merged result so it stays fresh
      await _saveCachedComplaints(runInstanceId, merged);

      if (!mounted) return;
      setState(() {
        complaints = merged;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final msg = e.toString().replaceAll('Exception: ', '');
        if (msg.contains('AUTH_ERROR')) {
          error = 'Session expired. Please log in again.';
        }
        // For other errors, keep whatever was already loaded (cache)
        isLoading = false;
      });
    }
  }

  List<ComplaintModel> get activeComplaints => complaints
      .where((c) =>
          ['Raised', 'Acknowledged', 'In Progress'].contains(c.status))
      .toList();

  List<ComplaintModel> get closedComplaints => complaints
      .where((c) => ['Resolved', 'Closed'].contains(c.status))
      .toList();

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Electrical':
        return Colors.amber;
      case 'Security':
        return Colors.red;
      case 'Mechanical':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Electrical':
        return Icons.bolt;
      case 'Security':
        return Icons.security;
      case 'Mechanical':
        return Icons.build;
      default:
        return Icons.report_problem;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Raised':
        return kWarningOrange;
      case 'Acknowledged':
        return Colors.blue;
      case 'In Progress':
        return Colors.cyan;
      case 'Resolved':
        return kSuccessGreen;
      case 'Closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Complaints',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: kRailwayBlue,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadComplaints,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Active (${activeComplaints.length})'),
            Tab(text: 'Resolved (${closedComplaints.length})'),
            Tab(text: 'All (${complaints.length})'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildComplaintsList(activeComplaints),
                    _buildComplaintsList(closedComplaints),
                    _buildComplaintsList(complaints),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<ComplaintModel>(
            context,
            MaterialPageRoute(
              builder: (context) => const RaiseComplaintScreen(),
            ),
          );
          if (added != null && mounted) {
            setState(() => complaints.insert(0, added));
          }
        },
        backgroundColor: kRailwayBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Raise Complaint',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadComplaints,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kRailwayBlue,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintsList(List<ComplaintModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_problem_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No complaints found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Raise Complaint" to report an issue',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildComplaintCard(list[index]),
      ),
    );
  }

  Widget _buildComplaintCard(ComplaintModel complaint) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: ComplaintDetailsSheet(complaint: complaint),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        _getCategoryColor(complaint.category).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(complaint.category),
                    color: _getCategoryColor(complaint.category),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Coach ${complaint.coachId}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(complaint.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _getStatusColor(complaint.status), width: 1),
                  ),
                  child: Text(
                    complaint.status,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: _getStatusColor(complaint.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              complaint.description,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[700], height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM').format(complaint.raisedDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                if (complaint.hasPhoto)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo, size: 12, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Photo',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (complaint.assignedTo != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.green[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Assigned to: ${complaint.assignedTo}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[900],
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Raise Complaint Screen
// ─────────────────────────────────────────────────────────────────────────────
class RaiseComplaintScreen extends StatefulWidget {
  const RaiseComplaintScreen({super.key});

  @override
  State<RaiseComplaintScreen> createState() => _RaiseComplaintScreenState();
}

class _RaiseComplaintScreenState extends State<RaiseComplaintScreen> {
  final Map<String, List<String>> categoryMap = {
    'Electrical': ['AC', 'Light', 'Other Electrical Equipment'],
    'Security': ['CCTV', 'Door Lock', 'Fire Extinguisher', 'Alarm', 'Other'],
    'Mechanical': [
      'Toilet Hardware',
      'Tap Leakage',
      'Coach Fittings',
      'Dustbin Fixture',
      'Other',
    ],
  };

  // Coach list comes from worker's assigned run
  List<String> assignedCoaches = [];
  String? selectedCoach;
  String? selectedCategory;
  String? selectedSubcategory;
  final TextEditingController _descController = TextEditingController();
  XFile? _photoFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadAssignedCoaches();
    _descController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedCoaches() async {
    try {
      final controller = Get.find<WorkerController>();
      final profile = controller.workerProfile.value;

      if (profile == null) {
        setState(() => assignedCoaches = []);
        return;
      }

      final coachSet = <String>{};

      for (final run in profile.assignedRuns) {
        if (run.myCoach != null && run.myCoach!.coachType.isNotEmpty) {
          coachSet.add(run.myCoach!.coachType);
        }
      }

      if (coachSet.isEmpty) {
        setState(() => assignedCoaches = []);
      } else {
        final coaches = coachSet.toList();
        setState(() {
          assignedCoaches = coaches;
          if (coaches.length == 1) selectedCoach = coaches.first;
        });
      }
    } catch (_) {
      setState(() => assignedCoaches = []);
    }
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (photo != null) setState(() => _photoFile = photo);
  }

  bool get _canSubmit =>
      selectedCoach != null &&
      selectedCategory != null &&
      _descController.text.trim().isNotEmpty &&
      _photoFile != null;

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final controller = Get.find<WorkerController>();

      // 1️⃣ Resolve runInstanceId
      final runInstanceId = await controller.resolveRunInstanceId();
      if (runInstanceId == null || runInstanceId.isEmpty) {
        throw Exception('No run instance assigned. Cannot raise complaint.');
      }

      // 2️⃣ Upload photo
      String? photoUrl;
      if (_photoFile != null) {
        photoUrl = await WorkerRepository.uploadMedia(_photoFile!.path);
      }

      // 3️⃣ Build category string — combine category + subcategory if set
      final categoryStr = selectedSubcategory != null
          ? '${selectedCategory!} - ${selectedSubcategory!}'
          : selectedCategory!;

      // 4️⃣ POST raise complaint
      final response = await WorkerRepository.raiseObhsComplaint(
        runInstanceId: runInstanceId,
        coachNo: selectedCoach!,
        category: categoryStr,
        description: _descController.text.trim(),
        photoUrl: photoUrl,
      );

      if (!mounted) return;

      if (response['success'] == true || response['complaintId'] != null) {
        // Build a local model from the response for immediate UI update
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final added = ComplaintModel(
          complaintId: data['complaintId']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          coachId: selectedCoach!,
          category: categoryStr,
          description: _descController.text.trim(),
          status: 'Raised',
          raisedDate: DateTime.now(),
          photoUrl: photoUrl,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint submitted successfully!'),
            backgroundColor: kSuccessGreen,
          ),
        );

        // Save to local cache so it persists on refresh even before
        // the backend GET endpoint is available
        try {
          final prefs = await SharedPreferences.getInstance();
          final cacheKey = 'local_complaints_$runInstanceId';
          final existing = prefs.getString(cacheKey);
          final list = existing != null
              ? (jsonDecode(existing) as List)
              : [];
          // Insert at front, avoid duplicates
          final alreadyExists = list.any((e) =>
              (e as Map<String, dynamic>)['complaintId'] == added.complaintId);
          if (!alreadyExists) {
            list.insert(0, added.toJson());
            await prefs.setString(cacheKey, jsonEncode(list));
          }
        } catch (_) {}

        if (!mounted) return;
        Navigator.pop(context, added);
      } else {
        throw Exception(
          response['message'] ?? response['error'] ?? 'Submission failed.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: kErrorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Raise Complaint',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: kRailwayBlue,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coach
            _sectionTitle('Select Coach'),
            const SizedBox(height: 10),
            _buildDropdown(
              value: selectedCoach,
              items: assignedCoaches,
              hint: 'Choose a coach',
              onChanged: (v) => setState(() => selectedCoach = v),
            ),
            const SizedBox(height: 20),

            // Category
            _sectionTitle('Category'),
            const SizedBox(height: 10),
            _buildDropdown(
              value: selectedCategory,
              items: categoryMap.keys.toList(),
              hint: 'Select category',
              onChanged: (v) => setState(() {
                selectedCategory = v;
                selectedSubcategory = null;
              }),
            ),
            const SizedBox(height: 20),

            // Subcategory
            if (selectedCategory != null) ...[
              _sectionTitle('Issue Type'),
              const SizedBox(height: 10),
              _buildDropdown(
                value: selectedSubcategory,
                items: categoryMap[selectedCategory!]!,
                hint: 'Select issue type',
                onChanged: (v) => setState(() => selectedSubcategory = v),
              ),
              const SizedBox(height: 20),
            ],

            // Description
            _sectionTitle('Description (Hinglish allowed)'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the issue in detail...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Characters: ${_descController.text.length}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Photo
            _sectionTitle('Attach Photo'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _photoFile != null
                        ? Colors.green[300]!
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: _photoFile != null ? Colors.green[50] : Colors.grey[50],
                ),
                child: _photoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_photoFile!.path),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to capture photo',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Photo is mandatory for complaint submission',
              style: TextStyle(
                  fontSize: 11,
                  color: kErrorRed,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 28),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRailwayBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Complaint',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
      );

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value != null && items.contains(value) ? value : null,
          hint: Text(hint),
          items: items
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Complaint Details Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class ComplaintDetailsSheet extends StatelessWidget {
  final ComplaintModel complaint;
  const ComplaintDetailsSheet({super.key, required this.complaint});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Raised':
        return kWarningOrange;
      case 'Acknowledged':
        return Colors.blue;
      case 'In Progress':
        return Colors.cyan;
      case 'Resolved':
        return kSuccessGreen;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coach ${complaint.coachId}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(complaint.status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                complaint.status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(complaint.status),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              complaint.description,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[800], height: 1.5),
            ),
            const SizedBox(height: 20),
            _detailRow('Raised On',
                DateFormat('dd MMM yyyy, hh:mm a').format(complaint.raisedDate)),
            if (complaint.assignedTo != null)
              _detailRow('Assigned To', complaint.assignedTo!),
            if (complaint.resolutionRemark != null)
              _detailRow('Resolution', complaint.resolutionRemark!),
            if (complaint.hasPhoto) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  complaint.photoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    color: Colors.grey[100],
                    child: Center(
                      child: Text('Photo unavailable',
                          style: TextStyle(color: Colors.grey[500])),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
