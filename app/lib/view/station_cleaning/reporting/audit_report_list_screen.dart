import 'dart:convert';
import 'package:crm_train/repositories/station_report_repository.dart';
import 'package:crm_train/services/station_audit_pdf_service.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class AuditReportListScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const AuditReportListScreen({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<AuditReportListScreen> createState() => _AuditReportListScreenState();
}

class _AuditReportListScreenState extends State<AuditReportListScreen> {
  String _selectedType = 'user-activity';
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;

  final _startDateCtrl = TextEditingController(
    text: DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10),
  );
  final _endDateCtrl = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _userIdCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  final _inspectorIdCtrl = TextEditingController();

  final _auditTypes = [
    {'key': 'user-activity', 'label': 'User Activity Audit'},
    {'key': 'image-archive', 'label': 'Image Evidence Archive'},
    {'key': 'rejected-forms', 'label': 'Rejected/Resubmitted Forms'},
    {'key': 'inspection-history', 'label': 'Inspection History'},
    {'key': 'data-modification', 'label': 'Data Modification'},
  ];

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _userIdCtrl.dispose();
    _actionCtrl.dispose();
    _inspectorIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });
    try {
      final query = <String, String>{
        'stationId': widget.stationId,
        'startDate': _startDateCtrl.text.trim(),
        'endDate': _endDateCtrl.text.trim(),
      };
      if (_userIdCtrl.text.trim().isNotEmpty)
        query['userId'] = _userIdCtrl.text.trim();
      if (_actionCtrl.text.trim().isNotEmpty)
        query['action'] = _actionCtrl.text.trim();
      if (_inspectorIdCtrl.text.trim().isNotEmpty)
        query['inspectorId'] = _inspectorIdCtrl.text.trim();
      final data = await StationReportRepository.generateAuditReport(
        _selectedType,
        query,
      );
      if (mounted)
        setState(() {
          _result = data;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audit Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      items: _auditTypes
                          .map(
                            (t) => DropdownMenuItem(
                              value: t['key'],
                              child: Text(t['label']!),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedType = v!;
                        _result = null;
                      }),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate:
                                    DateTime.tryParse(_startDateCtrl.text) ??
                                    DateTime.now().subtract(
                                      const Duration(days: 30),
                                    ),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (d != null)
                                _startDateCtrl.text = d
                                    .toIso8601String()
                                    .substring(0, 10);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(_startDateCtrl.text),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate:
                                    DateTime.tryParse(_endDateCtrl.text) ??
                                    DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (d != null)
                                _endDateCtrl.text = d
                                    .toIso8601String()
                                    .substring(0, 10);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(_endDateCtrl.text),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedType == 'user-activity' ||
                        _selectedType == 'data-modification') ...[
                      TextField(
                        controller: _userIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'User ID (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_selectedType == 'user-activity') ...[
                      TextField(
                        controller: _actionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Action (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_selectedType == 'inspection-history') ...[
                      TextField(
                        controller: _inspectorIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Inspector ID (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _generate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[800],
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Generate Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: kErrorRed.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: kErrorRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: kErrorRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: kSuccessGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Report Generated',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kSuccessGreen,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Share as PDF',
                            icon: const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.indigo,
                            ),
                            onPressed: () => _sharePdf(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSummary(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_result!['summary']?['records'] is List)
                ...(_result!['summary']['records'] as List).map(
                  (r) => _RecordCard(record: r),
                ),
              if (_result!['summary']?['inspections'] is List)
                ...(_result!['summary']['inspections'] as List).map(
                  (r) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['inspectionType'] ?? 'Inspection'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Status: ${r['status']} | Score: ${r['score'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Inspector: ${r['inspector']} | Date: ${r['date'] ?? ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_result!['summary']?['images'] is List)
                ...(_result!['summary']['images'] as List).map(
                  (r) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.image,
                        size: 32,
                        color: Colors.grey,
                      ),
                      title: Text(
                        r['evidenceType'] ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${r['uploadedAt']?.substring(0, 10) ?? ''} | ${r['fileSize'] != null ? '${(r['fileSize'] / 1024).toStringAsFixed(0)}KB' : ''}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
              if (_result!['summary']?['forms'] is List)
                ...(_result!['summary']['forms'] as List).map(
                  (r) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        '${r['collection'] ?? ''} — ${r['formId'] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        'Reason: ${r['reason'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
              if (_result!['summary']?['modifications'] is List)
                ...(_result!['summary']['modifications'] as List).map(
                  (r) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        '${r['userName'] ?? r['userId'] ?? ''} — ${r['action'] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        '${r['details'] ?? ''}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final s = _result!['summary'] ?? {};
    final entries = s.entries.where(
      (e) => ![
        'records',
        'inspections',
        'images',
        'forms',
        'modifications',
      ].contains(e.key),
    );
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      children: entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(
                      '${e.key}:',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${e.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _sharePdf() async {
    try {
      final bytes = await StationAuditPdfService.generateAuditPdf(
        reportType: _selectedType,
        stationName: widget.stationName,
        result: _result!,
      );
      final dateStr = _endDateCtrl.text.replaceAll('-', '');
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          mimeType: 'application/pdf',
          name: 'AuditReport_${_selectedType}_$dateStr.pdf',
        ),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF failed: $e'), backgroundColor: kErrorRed),
        );
      }
    }
  }
}

class _RecordCard extends StatelessWidget {
  final dynamic record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record is Map<String, dynamic>
        ? Map<String, dynamic>.from(record)
        : {'value': record};
    final entries = r.entries.take(8).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        _formatLabel(e.key),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formatValue(e.value),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatValue(dynamic v) {
    if (v == null) return '-';
    if (v is Map || v is List) {
      final s = jsonEncode(v);
      return s.length > 200 ? '${s.substring(0, 200)}…' : s;
    }
    return '$v';
  }

  String _formatLabel(String key) {
    final spaced = key.replaceAll(RegExp('([a-z])([A-Z])'), r'$1 $2');
    final words = spaced.replaceAll('_', ' ');
    if (words.isEmpty) return key;
    return words[0].toUpperCase() + words.substring(1);
  }
}
