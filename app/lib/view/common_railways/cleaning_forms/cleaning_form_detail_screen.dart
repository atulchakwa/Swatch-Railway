import 'dart:io';
import 'package:crm_train/model/cleaning_form_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/services/pdf_report_service.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/view/common_railways/cleaning_forms/cleaning_scoring_screen.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class CleaningFormDetailScreen extends StatefulWidget {
  final String formUid;
  const CleaningFormDetailScreen({super.key, required this.formUid});

  @override
  State<CleaningFormDetailScreen> createState() => _CleaningFormDetailScreenState();
}

class _CleaningFormDetailScreenState extends State<CleaningFormDetailScreen> {
  CleaningForm? form;
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
      final data = await ApiService.getCleaningFormDetail(widget.formUid);
      if (mounted) setState(() { form = CleaningForm.fromJson(data['form']); isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { isLoading = false; error = e.toString(); });
    }
  }

  Color _statusColor(CleaningFormStatus status) {
    switch (status) {
      case CleaningFormStatus.draft: return Colors.grey;
      case CleaningFormStatus.submitted: return Colors.blue;
      case CleaningFormStatus.approved: return kSuccessGreen;
      case CleaningFormStatus.rejected: return kErrorRed;
      case CleaningFormStatus.scored: return Colors.purple;
      case CleaningFormStatus.locked: return Colors.grey.shade800;
      case CleaningFormStatus.scoringInProgress: return kWarningOrange;
      case CleaningFormStatus.contractorApproved: return Colors.teal;
      case CleaningFormStatus.autoApproved: return Colors.indigo;
    }
  }

  String _formatDt(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context).currentUser?.role ?? '';
    final isSupervisor = role == 'Railway Supervisor';
    final isAdmin = role == 'SUPER_ADMIN' || role == 'Super Admin' || role == 'Railway Admin' || role == 'Railway Master' || role == 'Company Master';
    final isContractor = role == 'Contractor';

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
                _buildEntityInfo(f),
                const SizedBox(height: 12),
                if (f.formType == FormType.coach) _buildCoachDetails(f) else _buildPremiseDetails(f),
                const SizedBox(height: 12),
                _buildManpowerMachine(f),
                const SizedBox(height: 12),
                _buildGpsLocation(f),
                const SizedBox(height: 12),
                _buildPhotos(f),
                const SizedBox(height: 12),
                _buildActivities(f),
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
        _buildActionBar(f, role, isSupervisor, isAdmin, isContractor),
      ],
    );
  }

  Widget _buildHeaderCard(CleaningForm f) {
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(f.formType == FormType.coach ? Icons.train : Icons.business, size: 16, color: kRailwayBlue),
                const SizedBox(width: 6),
                Text(f.formTypeLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const Divider(height: 20),
            _detailRow('Date', f.cleaningDate),
            _detailRow('Shift', f.cleaningShift),
            _detailRow('Division', f.division),
            _detailRow('Depot', f.depot),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityInfo(CleaningForm f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.business, color: kRailwayBlue, size: 20)),
              const SizedBox(width: 10),
              const Text('Entity Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            _detailRow('Contract No.', f.contractNumber),
            _detailRow('Entity', f.entityName),
            _detailRow('Submitted By', f.submittedByName),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachDetails(CleaningForm f) {
    final cd = f.coachDetails ?? {};
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.train, color: Colors.teal, size: 20)),
              const SizedBox(width: 10),
              const Text('Coach Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            _detailRow('Train Number', cd['trainNumber']?.toString() ?? '-'),
            _detailRow('Train Name', cd['trainName']?.toString() ?? '-'),
            _detailRow('Coach Number', cd['coachNumber']?.toString() ?? '-'),
            _detailRow('Coach Type', cd['coachType']?.toString() ?? '-'),
            const SizedBox(height: 8),
            Row(children: [
              _checkIcon(cd['waterFilled'] == true, 'Water Tank'),
              const SizedBox(width: 16),
              _checkIcon(cd['toiletriesFilled'] == true, 'Toiletries'),
              const SizedBox(width: 16),
              _checkIcon(cd['dustbinsAvailable'] == true, 'Dustbins'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiseDetails(CleaningForm f) {
    final pd = f.premiseDetails ?? {};
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.business, color: Colors.teal, size: 20)),
              const SizedBox(width: 10),
              const Text('Premise Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            _detailRow('Premise Name', pd['premiseName']?.toString() ?? '-'),
            _detailRow('Type', pd['premiseType']?.toString() ?? '-'),
            _detailRow('Area Covered', pd['areaCovered']?.toString() ?? '-'),
            _detailRow('Area Uncleaned', pd['areaUncleaned']?.toString() ?? '-'),
            _detailRow('Garbage Collected', pd['garbageCollected']?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _checkIcon(bool value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(value ? Icons.check_circle : Icons.cancel, color: value ? kSuccessGreen : kErrorRed, size: 18),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildManpowerMachine(CleaningForm f) {
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

  Widget _buildGpsLocation(CleaningForm f) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kWarningOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.location_on, color: kWarningOrange, size: 20)),
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

  Widget _buildPhotos(CleaningForm f) {
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
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.photo_library, color: Colors.indigo, size: 20)),
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

  Widget _photoGroup(String label, List<CleaningPhoto> photos) {
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

  Widget _buildActivities(CleaningForm f) {
    final key = f.formType == FormType.coach ? 'coach' : 'premise';
    final categories = cleaningActivities[key] ?? [];
    if (categories.isEmpty) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kSuccessGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.checklist, color: kSuccessGreen, size: 20)),
              const SizedBox(width: 10),
              const Text('Activities', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            ...categories.map((cat) => _buildCategory(f, cat)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(CleaningForm f, Map<String, dynamic> cat) {
    final items = List<String>.from(cat['items'] ?? []);
    final categoryName = cat['category']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(categoryName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kRailwayBlue)),
          const SizedBox(height: 4),
          ...items.map((item) {
            final checked = _isActivityChecked(f, item);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: checked ? kSuccessGreen : Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text(item, style: TextStyle(fontSize: 12, color: checked ? Colors.black87 : Colors.grey.shade500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isActivityChecked(CleaningForm f, String item) {
    if (f.formType == FormType.coach) {
      final cd = f.coachDetails ?? {};
      if (item == 'Water Tank Filled') return cd['waterFilled'] == true;
      if (item == 'Toiletries Refilled') return cd['toiletriesFilled'] == true;
      if (item == 'Dustbins Available') return cd['dustbinsAvailable'] == true;
    } else {
      final pd = f.premiseDetails ?? {};
      if (item == 'Collection') return pd['garbageCollected'] != null && (pd['garbageCollected'] as num) > 0;
    }
    if (f.scoringData != null) {
      final criteria = f.scoringData!['criteria'] as List?;
      if (criteria != null) {
        for (final c in criteria) {
          if (c['name'] == item && (c['score'] as num?) == 1) return true;
        }
      }
    }
    return false;
  }

  Widget _buildScoreSection(CleaningForm f) {
    final sd = f.scoringData != null ? CleaningScoringData.fromJson(f.scoringData!) : null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.score, color: Colors.purple, size: 20)),
              const SizedBox(width: 10),
              const Text('Score', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 20),
            Row(
              children: [
                Text('${f.score?.toStringAsFixed(1) ?? '-'} / ${sd?.maxTotalScore.toStringAsFixed(0) ?? '100'}',
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
            if (f.scoringData != null && f.scoringData!['remarks'] != null && (f.scoringData!['remarks'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Remarks: ${f.scoringData!['remarks']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            if (sd != null && sd.criteria.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Criteria Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...sd.criteria.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(c.name, style: const TextStyle(fontSize: 12)),
                      Text('${c.score.toStringAsFixed(1)} / ${c.maxScore.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.score >= c.maxScore * 0.7 ? kSuccessGreen : kWarningOrange)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.maxScore > 0 ? c.score / c.maxScore : 0,
                        backgroundColor: Colors.grey.shade200,
                        color: c.score >= c.maxScore * 0.7 ? kSuccessGreen : kWarningOrange,
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

  Widget _buildAuditTrail(CleaningForm f) {
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
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kInfo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.history, color: kInfo, size: 20)),
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

  Widget _buildTimelineEntry(CleaningAuditLog log, bool isLast) {
    Color dotColor;
    switch (log.action.toLowerCase()) {
      case 'created': dotColor = Colors.blue; break;
      case 'submitted': dotColor = kWarningOrange; break;
      case 'approved': dotColor = kSuccessGreen; break;
      case 'rejected': dotColor = kErrorRed; break;
      case 'scored': dotColor = Colors.purple; break;
      case 'acknowledged': dotColor = Colors.teal; break;
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

  Widget _buildApprovalDetails(CleaningForm f) {
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
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isApproved ? kSuccessGreen.withOpacity(0.1) : kErrorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(isApproved ? Icons.verified : Icons.cancel, color: isApproved ? kSuccessGreen : kErrorRed, size: 20)),
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

  Widget _buildActionBar(CleaningForm f, String role, bool isSupervisor, bool isAdmin, bool isContractor) {
    final canApproveReject = f.status == CleaningFormStatus.submitted && (isSupervisor || isAdmin);
    final canEnterScore = f.status == CleaningFormStatus.approved;
    final canAcknowledge = f.status == CleaningFormStatus.scored && isContractor;
    final canLock = (f.status == CleaningFormStatus.contractorApproved || f.status == CleaningFormStatus.scored) && (isAdmin || isSupervisor);

    if (!canApproveReject && !canEnterScore && !canAcknowledge && !canLock) {
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
                  onPressed: () => _approveForm(),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectForm(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: kErrorRed, side: const BorderSide(color: kErrorRed), padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
            if (canEnterScore)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToScoring(),
                  icon: const Icon(Icons.score, size: 18),
                  label: const Text('Enter Score'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            if (canAcknowledge)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _acknowledgeForm(),
                  icon: const Icon(Icons.thumb_up, size: 18),
                  label: const Text('Acknowledge Score'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            if (canLock)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _lockForm(),
                  icon: const Icon(Icons.lock, size: 18),
                  label: const Text('Lock Form'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveForm() async {
    try {
      await ApiService.approveCleaningForm(widget.formUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form approved'), backgroundColor: kSuccessGreen));
        _loadForm();
      }
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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Provide rejection reason:'),
          const SizedBox(height: 12),
          TextField(controller: reasonCtrl, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()), style: ElevatedButton.styleFrom(backgroundColor: kErrorRed), child: const Text('Reject')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ApiService.rejectCleaningForm(widget.formUid, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form rejected'), backgroundColor: kErrorRed));
        _loadForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    }
  }

  Future<void> _navigateToScoring() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CleaningScoringScreen(formUid: widget.formUid)),
    );
    _loadForm();
  }

  Future<void> _acknowledgeForm() async {
    try {
      await ApiService.acknowledgeCleaningForm(widget.formUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Score acknowledged'), backgroundColor: Colors.teal));
        _loadForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    }
  }

  Future<void> _lockForm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lock Form'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800), child: const Text('Lock')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.lockCleaningForm(widget.formUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form locked'), backgroundColor: Colors.grey));
        _loadForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed));
    }
  }

  Future<void> _generatePdf() async {
    if (form == null) return;
    try {
      final bytes = await PDFReportService.generateCleaningFormReportPdf(form!.toJson());
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/cleaning_form_${form!.formId}.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved: ${file.path}'), backgroundColor: Colors.green));
        await Share.shareXFiles([XFile(file.path)], text: 'Cleaning Form - ${form!.formId}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: kErrorRed));
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
