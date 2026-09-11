import 'dart:io';
import 'package:crm_train/model/station_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/services/pdf_report_service.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class StationFormDetailScreen extends StatefulWidget {
  final String formUid;
  const StationFormDetailScreen({super.key, required this.formUid});

  @override
  State<StationFormDetailScreen> createState() => _StationFormDetailScreenState();
}

class _StationFormDetailScreenState extends State<StationFormDetailScreen> {
  StationCleaningForm? form;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    setState(() { isLoading = true; error = null; });
    try {
      final formData = await ApiService.getStationCleaningFormDetail(widget.formUid);
      if (mounted) setState(() { form = formData; isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = e.toString(); });
    }
  }

  Color _statusColor(StationFormStatus status) {
    switch (status) {
      case StationFormStatus.draft: return Colors.grey;
      case StationFormStatus.submitted: return Colors.blue;
      case StationFormStatus.approved: return kSuccessGreen;
      case StationFormStatus.rejected: return kErrorRed;
      case StationFormStatus.scored: return Colors.purple;
      case StationFormStatus.locked: return Colors.grey.shade800;
    }
  }

  String _formatDt(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _generatePdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...')));
      final pdfBytes = await PDFReportService.generateBillingReportPdf({}, []);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/StationForm_${widget.formUid}.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Station Cleaning Form Report');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e'), backgroundColor: kErrorRed));
    }
  }

  Future<void> _approveForm() async {
    try {
      await ApiService.approveStationCleaningForm(widget.formUid);
      await _loadForm();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form approved'), backgroundColor: kSuccessGreen));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    }
  }

  Future<void> _rejectForm() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Form'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Rejection Reason', border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()), child: const Text('Reject')),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await ApiService.rejectStationCleaningForm(widget.formUid, reason: reason);
      await _loadForm();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form rejected'), backgroundColor: kErrorRed));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    }
  }

  Future<void> _showScoringSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ScoringSheet(),
    );
    if (result != null) {
      try {
        await ApiService.scoreStationCleaningForm(
          widget.formUid,
          totalScore: result['total'],
          grade: result['grade'],
          scoringData: result['data'],
        );
        await _loadForm();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Score submitted'), backgroundColor: kSuccessGreen));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
      }
    }
  }

  Future<void> _lockForm() async {
    try {
      await ApiService.lockStationCleaningForm(widget.formUid);
      await _loadForm();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form locked'), backgroundColor: Colors.grey));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context).currentUser?.role ?? '';
    final isSupervisor = role == 'Railway Supervisor';
    final isAdmin = role == 'SUPER_ADMIN' || role == 'Super Admin' || role == 'Railway Admin' || role == 'Railway Master' || role == 'Company Master';
    final isContractor = role == 'Contractor' || role == 'Contractor Master';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _generatePdf, tooltip: 'Generate PDF'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadForm, tooltip: 'Refresh'),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _loadForm, child: const Text('Retry')),
                ]))
              : form == null
                  ? const Center(child: Text('No data'))
                  : _buildContent(context, role, isSupervisor, isAdmin, isContractor),
    );
  }

  Widget _buildContent(BuildContext context, String role, bool isSupervisor, bool isAdmin, bool isContractor) {
    final f = form!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(f),
                const SizedBox(height: 12),
                _buildFormInfo(f),
                const SizedBox(height: 12),
                _buildAreaSection(f),
                const SizedBox(height: 12),
                _buildResourcesSection(f),
                const SizedBox(height: 12),
                _buildGpsLocation(f),
                const SizedBox(height: 12),
                _buildActivitiesList(f),
                const SizedBox(height: 12),
                _buildPhotosSection(f),
                const SizedBox(height: 12),
                if (f.score != null || f.grade != null) _buildScoreSection(f),
                if (f.score != null || f.grade != null) const SizedBox(height: 12),
                _buildAuditTrail(f),
                const SizedBox(height: 12),
                _buildApprovalDetails(f),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
        _buildActionBar(f, isSupervisor, isAdmin, isContractor),
      ],
    );
  }

  Widget _buildHeaderCard(StationCleaningForm f) {
    final statusColor = _statusColor(f.status);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(f.formId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(f.statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 20),
            _detailRow('Station', f.stationName),
            _detailRow('Area', f.areaName),
            _detailRow('Zone', f.zoneName),
            _detailRow('Division', f.division),
          ],
        ),
      ),
    );
  }

  Widget _buildFormInfo(StationCleaningForm f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.info, color: kRailwayBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Form Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            _detailRow('Date', f.cleaningDate),
            _detailRow('Shift', f.shift),
            _detailRow('Start Time', f.startTime.isNotEmpty ? f.startTime : '-'),
            _detailRow('End Time', f.endTime.isNotEmpty ? f.endTime : '-'),
            _detailRow('Submitted By', f.submittedByName),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaSection(StationCleaningForm f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kWarningOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.area_chart, color: kWarningOrange, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Area & Waste Statistics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            _detailRow('Area Covered', '${f.areaCovered} sqm'),
            _detailRow('Area Uncleaned', '${f.areaUncleaned} sqm'),
            _detailRow('Garbage Collected', '${f.garbageCollected} kg'),
            if (f.remarks.isNotEmpty) _detailRow('Remarks', f.remarks),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesSection(StationCleaningForm f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _statTile(Icons.people, 'Manpower', '${f.manpowerCount}', kRailwayBlue)),
            Container(height: 40, width: 1, color: kDivider),
            Expanded(child: _statTile(Icons.precision_manufacturing, 'Machines', '${f.machineCount}', Colors.teal)),
          ],
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildGpsLocation(StationCleaningForm f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kWarningOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.location_on, color: kWarningOrange, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('GPS Location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.my_location, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text('Lat: ${f.latitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 16),
                Text('Lng: ${f.longitude.toStringAsFixed(6)}', style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (f.gpsAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_city, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.gpsAddress, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesList(StationCleaningForm f) {
    if (f.activities.isEmpty) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kSuccessGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.checklist, color: kSuccessGreen, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Activities Performed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            ...stationCleaningActivities.map((activity) {
              final checked = f.activities.contains(activity);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: checked ? kSuccessGreen : Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(activity, style: TextStyle(fontSize: 12, color: checked ? Colors.black87 : Colors.grey.shade500)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection(StationCleaningForm f) {
    if (f.photos.isEmpty) return const SizedBox.shrink();
    final before = f.photos.where((p) => p.type == 'before').toList();
    final after = f.photos.where((p) => p.type == 'after').toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.photo_library, color: Colors.indigo, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Photos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            if (before.isNotEmpty) _photoGroup('Before', before),
            if (before.isNotEmpty && after.isNotEmpty) const SizedBox(height: 12),
            if (after.isNotEmpty) _photoGroup('After', after),
          ],
        ),
      ),
    );
  }

  Widget _photoGroup(String label, List<StationCleaningPhoto> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (${photos.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: photos.map((p) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, color: Colors.grey.shade400, size: 28),
                const SizedBox(height: 2),
                Text(p.url.length > 20 ? '...${p.url.substring(p.url.length - 20)}' : p.url, style: TextStyle(fontSize: 7, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildScoreSection(StationCleaningForm f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.score, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Score', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            Row(
              children: [
                Text('${f.score?.toStringAsFixed(1) ?? '-'} / 100',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.purple)),
                const SizedBox(width: 16),
                if (f.grade != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(f.grade!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
                  ),
              ],
            ),
            if (f.scoringData != null && _scoringBreakdown(f).isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Scoring Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._scoringBreakdown(f).entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(e.key, style: const TextStyle(fontSize: 12)),
                      Text('${e.value['score']} / ${e.value['max']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: e.value['score'] >= e.value['max'] * 0.7 ? kSuccessGreen : kWarningOrange)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (e.value['max'] as num) > 0 ? (e.value['score'] as num) / (e.value['max'] as num) : 0,
                        backgroundColor: Colors.grey.shade200,
                        color: e.value['score'] >= e.value['max'] * 0.7 ? kSuccessGreen : kWarningOrange,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              )),
            ],
            if (f.scoredByName != null || f.scoringAt != null) ...[
              const Divider(height: 16),
              if (f.scoredByName != null) _detailRow('Scored By', f.scoredByName!),
              if (f.scoringAt != null) _detailRow('Scored At', _formatDt(f.scoringAt)),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, Map<String, dynamic>> _scoringBreakdown(StationCleaningForm f) {
    if (f.scoringData == null) return {};
    final sd = f.scoringData!;
    final criteria = sd['criteria'] as List? ?? [];
    final Map<String, Map<String, dynamic>> result = {};
    for (final c in criteria) {
      if (c is Map<String, dynamic>) {
        result[c['name'] ?? 'Unknown'] = {
          'score': (c['score'] as num?)?.toDouble() ?? 0,
          'max': (c['maxScore'] as num?)?.toDouble() ?? 0,
        };
      }
    }
    return result;
  }

  Widget _buildAuditTrail(StationCleaningForm f) {
    if (f.auditLog.isEmpty) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kInfo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.history, color: kInfo, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Audit Trail', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            ...f.auditLog.asMap().entries.map((entry) => _buildTimelineEntry(entry.value, entry.key == f.auditLog.length - 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEntry(StationAuditLog log, bool isLast) {
    Color dotColor;
    switch (log.action.toLowerCase()) {
      case 'created': dotColor = Colors.blue; break;
      case 'submitted': dotColor = kWarningOrange; break;
      case 'approved': dotColor = kSuccessGreen; break;
      case 'rejected': dotColor = kErrorRed; break;
      case 'scored': dotColor = Colors.purple; break;
      case 'locked': dotColor = Colors.grey.shade800; break;
      default: dotColor = Colors.grey;
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.action, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: dotColor)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(child: Text(log.performedByName, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(_formatDt(log.timestamp), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  if (log.details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(log.details, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalDetails(StationCleaningForm f) {
    if (f.approvedBy == null && f.rejectedBy == null) return const SizedBox.shrink();
    final isApproved = f.approvedBy != null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isApproved ? kSuccessGreen.withOpacity(0.1) : kErrorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(isApproved ? Icons.verified : Icons.cancel, color: isApproved ? kSuccessGreen : kErrorRed, size: 20),
              ),
              const SizedBox(width: 10),
              Text(isApproved ? 'Approval Details' : 'Rejection Details', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            if (isApproved) ...[
              _detailRow('Approved By', f.approvedByName ?? f.approvedBy ?? '-'),
              if (f.approvedAt != null) _detailRow('Approved At', _formatDt(f.approvedAt)),
            ] else ...[
              _detailRow('Rejected By', f.rejectedByName ?? f.rejectedBy ?? '-'),
              if (f.rejectedAt != null) _detailRow('Rejected At', _formatDt(f.rejectedAt)),
              if (f.rejectionReason != null && f.rejectionReason!.isNotEmpty) _detailRow('Reason', f.rejectionReason!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(StationCleaningForm f, bool isSupervisor, bool isAdmin, bool isContractor) {
    final canApproveReject = f.status == StationFormStatus.submitted && (isSupervisor || isAdmin);
    final canEnterScore = f.status == StationFormStatus.approved && (isSupervisor || isAdmin);
    final canLock = f.status == StationFormStatus.scored && (isSupervisor || isAdmin);
    final isScoredOrLocked = f.status == StationFormStatus.scored || f.status == StationFormStatus.locked;

    if (!canApproveReject && !canEnterScore && !canLock && !isContractor) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (canApproveReject) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _approveForm,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rejectForm,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: kErrorRed, side: const BorderSide(color: kErrorRed), padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
            if (canEnterScore)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showScoringSheet,
                  icon: const Icon(Icons.score, size: 18),
                  label: const Text('Enter Score'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            if (canLock)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _lockForm,
                  icon: const Icon(Icons.lock, size: 18),
                  label: const Text('Lock Form'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            if (isContractor && isScoredOrLocked && !canEnterScore && !canApproveReject && !canLock)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Read Only', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ScoringSheet extends StatefulWidget {
  @override
  State<_ScoringSheet> createState() => _ScoringSheetState();
}

class _ScoringSheetState extends State<_ScoringSheet> {
  double _housekeeping = 0;
  double _washroom = 0;
  double _garbage = 0;
  double _areaCoverage = 0;
  double _manpowerCompliance = 0;

  double get _total => _housekeeping + _washroom + _garbage + _areaCoverage + _manpowerCompliance;

  String get _grade {
    if (_total >= 90) return 'A';
    if (_total >= 80) return 'B';
    if (_total >= 70) return 'C';
    return 'D';
  }

  Color get _gradeColor {
    if (_total >= 90) return kSuccessGreen;
    if (_total >= 80) return Colors.blue;
    if (_total >= 70) return kWarningOrange;
    return kErrorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enter Score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _gradeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total: ${_total.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(color: _gradeColor, borderRadius: BorderRadius.circular(10)),
                        child: Text(_grade, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _slider('Housekeeping', _housekeeping, 40, kRailwayBlue),
            _slider('Washroom', _washroom, 20, Colors.teal),
            _slider('Garbage Disposal', _garbage, 20, kWarningOrange),
            _slider('Area Coverage', _areaCoverage, 10, Colors.purple),
            _slider('Manpower Compliance', _manpowerCompliance, 10, kSuccessGreen),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Score: ${_total.toStringAsFixed(1)} / 100',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Grade: $_grade',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _gradeColor)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'total': _total,
                    'grade': _grade,
                    'data': {
                      'criteria': [
                        {'name': 'Housekeeping', 'score': _housekeeping, 'maxScore': 40},
                        {'name': 'Washroom', 'score': _washroom, 'maxScore': 20},
                        {'name': 'Garbage Disposal', 'score': _garbage, 'maxScore': 20},
                        {'name': 'Area Coverage', 'score': _areaCoverage, 'maxScore': 10},
                        {'name': 'Manpower Compliance', 'score': _manpowerCompliance, 'maxScore': 10},
                      ],
                    },
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                child: const Text('Submit Score'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double max, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${value.toStringAsFixed(0)} / ${max.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: max,
            divisions: max.toInt(),
            activeColor: color,
            onChanged: (v) => setState(() {
              switch (label) {
                case 'Housekeeping': _housekeeping = v; break;
                case 'Washroom': _washroom = v; break;
                case 'Garbage Disposal': _garbage = v; break;
                case 'Area Coverage': _areaCoverage = v; break;
                case 'Manpower Compliance': _manpowerCompliance = v; break;
              }
            }),
          ),
        ],
      ),
    );
  }
}
