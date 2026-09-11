import 'package:flutter/material.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/helper/api_error_handler.dart';
import 'package:crm_train/utills/app_colors.dart';

class ShiftSummaryApprovalScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;

  const ShiftSummaryApprovalScreen({super.key, this.stationId, this.stationName});

  @override
  State<ShiftSummaryApprovalScreen> createState() => _ShiftSummaryApprovalScreenState();
}

class _ShiftSummaryApprovalScreenState extends State<ShiftSummaryApprovalScreen> {
  List<Map<String, dynamic>> _summaries = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'submitted';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.getShiftSummaries(
        stationId: widget.stationId,
        status: _filterStatus,
      );
      if (!mounted) return;
      setState(() => _summaries = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiErrorHandler.getErrorMessage(e, null));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Summary Approvals'),
        backgroundColor: kRailwayBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: kRailwayBlue.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _statusChip('submitted'),
                const SizedBox(width: 8),
                _statusChip('approved'),
                const SizedBox(width: 8),
                _statusChip('rejected'),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final active = _filterStatus == status;
    return ChoiceChip(
      label: Text(status.toUpperCase()),
      selected: active,
      selectedColor: kRailwayBlue,
      labelStyle: TextStyle(
        color: active ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() => _filterStatus = status);
        _load();
      },
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_summaries.isEmpty) {
      return const Center(child: Text('No shift summaries found'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _summaries.length,
        itemBuilder: (ctx, i) => _buildSummaryCard(_summaries[i]),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> s) {
    final status = (s['status'] ?? '').toString();
    final areas = (s['areas'] as List?) ?? [];
    final color = status == 'approved'
        ? kSuccessGreen
        : status == 'rejected'
            ? kErrorRed
            : kWarningOrange;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${s['stationName'] ?? ''} — ${s['shift'] ?? ''} Shift',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Date: ${s['date'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            Text('Supervisor: ${s['supervisorName'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 8),
            Text('Areas: ${areas.length}  |  Total Work Done: ${(s['totalWorkDone'] ?? 0).toStringAsFixed(0)} sqft',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (status == 'rejected' && s['rejectionReason'] != null) ...[
              const SizedBox(height: 6),
              Text(
                'Rejected: ${s['rejectionReason']}',
                style: TextStyle(color: kErrorRed, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShiftSummaryDetailScreen(
                            summary: s,
                            canApprove: status == 'submitted',
                          ),
                        ),
                      );
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShiftSummaryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> summary;
  final bool canApprove;

  const ShiftSummaryDetailScreen({
    super.key,
    required this.summary,
    required this.canApprove,
  });

  @override
  State<ShiftSummaryDetailScreen> createState() => _ShiftSummaryDetailScreenState();
}

class _ShiftSummaryDetailScreenState extends State<ShiftSummaryDetailScreen> {
  bool _processing = false;
  String? _uid;
  late Map<String, dynamic> _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
    _uid = (widget.summary['uid'] ?? widget.summary['id']).toString();
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Summary'),
        content: Text('Approve the shift summary for ${_summary['stationName'] ?? ''}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _processing = true);
    try {
      await ApiService.approveShiftSummary(_uid!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift summary approved'), backgroundColor: kSuccessGreen),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorHandler.getErrorMessage(e, null)), backgroundColor: kErrorRed),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Summary'),
        content: TextField(
          controller: reasonCtrl,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Rejection reason',
            hintText: 'Required',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, reasonCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorRed),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    setState(() => _processing = true);
    try {
      await ApiService.rejectShiftSummary(_uid!, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift summary rejected'), backgroundColor: kErrorRed),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorHandler.getErrorMessage(e, null)), backgroundColor: kErrorRed),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = (_summary['areas'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Summary Detail'),
        backgroundColor: kRailwayBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerRow('Station', '${_summary['stationName'] ?? ''}'),
          _headerRow('Date', '${_summary['date'] ?? ''}'),
          _headerRow('Shift', '${_summary['shift'] ?? ''}'),
          _headerRow('Supervisor', '${_summary['supervisorName'] ?? ''}'),
          _headerRow('Status', '${_summary['status'] ?? ''}'),
          _headerRow('Total Work Done', '${(_summary['totalWorkDone'] ?? 0).toStringAsFixed(0)} sqft'),
          if (_summary['rejectionReason'] != null)
            _headerRow('Rejection Reason', '${_summary['rejectionReason']}'),
          const SizedBox(height: 16),
          _buildAreaCleanedSummary(areas),
          const SizedBox(height: 16),
          const Text('Areas Work', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          ...areas.map((a) {
            final m = Map<String, dynamic>.from(a as Map);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cleaning_services, size: 18, color: kRailwayBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${m['areaName'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (m['mainArea'] != null && m['mainArea'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('${m['mainArea']}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Basic ${(m['basicAreaSqFt'] ?? 0).toStringAsFixed(0)} sqft × ${m['boqTimesPerPeriod'] ?? 1}x = ${(m['workDone'] ?? 0).toStringAsFixed(0)} sqft',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remark: ${m['remark'] ?? ''}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    if (m['photoUrl'] != null && m['photoUrl'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          m['photoUrl'].toString(),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 140,
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: widget.canApprove && !_processing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kErrorRed,
                          side: const BorderSide(color: kErrorRed),
                        ),
                        onPressed: _reject,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSuccessGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _approve,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAreaCleanedSummary(List areas) {
    double totalSqft = 0;
    for (final a in areas) {
      final m = Map<String, dynamic>.from(a as Map);
      final sqft = (m['basicAreaSqFt'] ?? 0).toDouble();
      final freq = (m['boqTimesPerPeriod'] ?? 1).toInt();
      totalSqft += sqft * freq;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Area Cleaned Summary',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...areas.map((a) {
            final m = Map<String, dynamic>.from(a as Map);
            final sqft = (m['basicAreaSqFt'] ?? 0).toDouble();
            final freq = (m['boqTimesPerPeriod'] ?? 1).toInt();
            final cleaned = sqft * freq;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${m['areaName'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${sqft.toStringAsFixed(0)} sqft × ${freq}x = ${cleaned.toStringAsFixed(0)} sqft',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Row(
            children: [
              const Expanded(
                child: Text('Total Area Cleaned',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Text(
                '${totalSqft.toStringAsFixed(0)} sqft',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1B5E20)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
