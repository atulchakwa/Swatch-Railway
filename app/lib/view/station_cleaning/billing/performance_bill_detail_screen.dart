import 'package:crm_train/model/performance_billing_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PerformanceBillDetailScreen extends StatefulWidget {
  final String billUid;
  final String? contractId;
  final String? stationId;
  final String? stationName;
  const PerformanceBillDetailScreen({super.key, required this.billUid, this.contractId, this.stationId, this.stationName});

  @override
  State<PerformanceBillDetailScreen> createState() => _PerformanceBillDetailScreenState();
}

class _PerformanceBillDetailScreenState extends State<PerformanceBillDetailScreen> {
  bool _loading = true;
  bool _working = false;
  String? _error;
  PerformanceBill? _bill;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final b = await ApiService.getPerformanceBill(widget.billUid);
      if (!mounted) return;
      setState(() { _bill = b; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _action(String action, {Map<String, dynamic>? body}) async {
    setState(() => _working = true);
    try {
      final b = await ApiService.performanceBillAction(widget.billUid, action, body: body);
      if (!mounted) return;
      setState(() { _bill = b; _working = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bill ${action.toLowerCase()}'), backgroundColor: kSuccessGreen));
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: kErrorRed));
    }
  }

  Future<void> _reopen() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Bill'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason for reopening (required)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    if (ok == true) _action('reopen', body: {'reason': reasonCtrl.text.trim()});
  }

  Future<void> _editRecoveries() async {
    final bill = _bill!;
    final rows = List<RecoveryRow>.of(bill.otherRecoveries);
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Other Recoveries'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(rows[i].label, style: const TextStyle(fontSize: 12))),
                          Text('₹${rows[i].amount.round()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: kErrorRed, size: 20),
                            onPressed: () => setLocal(() => rows.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Recovery label', isDense: true, border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', isDense: true, border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (labelCtrl.text.trim().isEmpty || amount == null || amount <= 0) return;
                        setLocal(() {
                          rows.add(RecoveryRow(label: labelCtrl.text.trim(), amount: amount));
                          labelCtrl.clear();
                          amountCtrl.clear();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save Recoveries'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _action('recoveries', body: {
        'otherRecoveries': rows.map((r) => r.toJson()).toList(),
        'gstRate': bill.gstRate,
      });
    }
  }

  Future<void> _recordPayment() async {
    final amountCtrl = TextEditingController(text: '${_bill!.totalPayable.round()}');
    final refCtrl = TextEditingController();
    String mode = 'bank_transfer';
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Mode *', border: OutlineInputBorder()),
                items: ['bank_transfer', 'cheque', 'cash', 'online'].map((m) => DropdownMenuItem(value: m, child: Text(m.replaceAll('_', ' ').toUpperCase()))).toList(),
                onChanged: (v) { if (v != null) mode = v; },
              ),
              const SizedBox(height: 12),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference *', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0 || refCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
              _action('payment', body: {'amount': amount, 'paymentRef': refCtrl.text.trim(), 'mode': mode});
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill'),
        content: const Text('Delete this bill? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kErrorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _working = true);
    try {
      await ApiService.deletePerformanceBill(widget.billUid);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: kErrorRed));
    }
  }

  bool _can(String permission) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return false;
    final r = user.role.toUpperCase().replaceAll(' ', '_');
    const perms = {
      'SUPER_ADMIN': {'VIEW', 'GENERATE', 'MANAGE', 'APPROVE', 'PAY'},
      'COMPANY_MASTER': {'VIEW', 'GENERATE', 'MANAGE', 'APPROVE', 'PAY'},
      'RAILWAY_MASTER': {'VIEW'},
      'ADMIN': {'VIEW', 'GENERATE', 'MANAGE', 'APPROVE', 'PAY'},
      'RAILWAY_ADMIN': {'VIEW', 'GENERATE', 'MANAGE', 'APPROVE', 'PAY'},
      'CONTRACTOR_MASTER': {'VIEW'},
      'CONTRACTOR_ADMIN': {'VIEW', 'GENERATE', 'MANAGE', 'APPROVE', 'PAY'},
      'CONTRACTOR_SUPERVISOR': {'VIEW'},
    };
    return (perms[r] ?? <String>{}).contains(permission);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: kErrorRed),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kErrorRed)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 10),
                        _buildScore(),
                        const SizedBox(height: 10),
                        _buildAreaBreakdown(),
                        const SizedBox(height: 10),
                        _buildFinancial(),
                        const SizedBox(height: 10),
                        _buildAudit(),
                        const SizedBox(height: 10),
                        _buildActions(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DRAFT': return kRailwayBlue;
      case 'CALCULATED': return Colors.indigo;
      case 'SUBMITTED': return kWarningOrange;
      case 'VERIFIED': return Colors.teal;
      case 'APPROVED': return kSuccessGreen;
      case 'LOCKED': return Colors.deepPurple;
      default: return Colors.grey;
    }
  }

  Widget _buildHeader() {
    final b = _bill!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(b.billNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: _statusColor(b.status), borderRadius: BorderRadius.circular(12)),
                  child: Text(b.status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Contract: ${b.contractNumber}  •  ${b.contractorName}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            Text('Station: ${b.stationName}  •  Period: ${b.month}/${b.year}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            Text('Scorecard period: ${b.scorecard.periodStart} to ${b.scorecard.periodEnd} (${b.scorecard.applicableDays} days)',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            Text('Payment: ${b.paymentStatus}${b.paymentRef != null ? '  (${b.paymentRef})' : ''}',
                style: TextStyle(color: b.paymentStatus == 'paid' ? kSuccessGreen : Colors.grey[600], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children, {Color? headerColor}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: headerColor ?? kRailwayBlue,
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color))),
        ],
      ),
    );
  }

  Color _achColor(double v) => v >= 80 ? kSuccessGreen : v >= 60 ? kWarningOrange : kErrorRed;

  Widget _buildScore() {
    final sc = _bill!.scorecard;
    return _sectionCard('Performance Score (out of 100)', [
      _row('Overall Score', '${sc.overallScore.toStringAsFixed(1)} / 100  (Grade ${sc.grade})', color: _achColor(sc.overallScore), bold: true),
      const Divider(),
      for (final c in sc.categories)
        _row('${c.name} (${c.maxMarks})',
            c.notApplicable && c.count == 0
                ? 'No data in period'
                : '${c.achievement.toStringAsFixed(1)}%  →  ${c.marks.toStringAsFixed(1)} marks',
            color: _achColor(c.achievement)),
      const Divider(),
      _row('Execution Achievement', '${sc.executionAchievement.toStringAsFixed(1)}%', color: _achColor(sc.executionAchievement)),
      _row('Verified Executions', '${sc.areaRows.fold<int>(0, (s, r) => s + r.verified)} / ${sc.areaRows.fold<int>(0, (s, r) => s + r.required)}'),
      _row('Rate', '₹${sc.ratePerSqft.toStringAsFixed(2)} / sqft'),
      _row('Scheduled Work Value', '₹${_inr(sc.scheduledWorkValue)}'),
      _row('Gross Work Value', '₹${_inr(sc.grossWorkValue)}', color: kSuccessGreen),
      const SizedBox(height: 4),
    ]);
  }

  String _inr(double v) {
    return v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _buildAreaBreakdown() {
    final sc = _bill!.scorecard;
    final rows = sc.areaRows;
    return _sectionCard('Area-wise Execution — AREA × SQFT × RATE (${rows.length} areas)', [
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text('No scheduled execution records in this period.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Expanded(flex: 3, child: Text('Area / Rate', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
              const SizedBox(width: 6),
              SizedBox(width: 32, child: Text('Req', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500]))),
              const SizedBox(width: 6),
              SizedBox(width: 32, child: Text('Ver', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500]))),
              const SizedBox(width: 6),
              SizedBox(width: 70, child: Text('Scheduled ₹', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500]))),
              const SizedBox(width: 6),
              SizedBox(width: 66, child: Text('Actual ₹', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500]))),
            ],
          ),
        ),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${r.areaName}\n${r.sqft.round()} sqft  •  ₹${r.rate.toStringAsFixed(2)}/sqft  •  ${r.frequency}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(width: 32, child: Text('${r.required}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10))),
                    const SizedBox(width: 6),
                    SizedBox(width: 32, child: Text('${r.verified}', textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r.verified < r.required ? kErrorRed : kSuccessGreen))),
                    const SizedBox(width: 6),
                    SizedBox(width: 70, child: Text(_inr(r.scheduledValue), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10))),
                    const SizedBox(width: 6),
                    SizedBox(width: 66, child: Text(_inr(r.actualValue), textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _achColor(r.achievement ?? 0)))),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: r.required > 0 ? (r.verified / r.required).clamp(0.0, 1.0) : 0,
                    minHeight: 2,
                    backgroundColor: Colors.grey[200],
                    color: _achColor(r.achievement ?? 0),
                  ),
                ),
                const Divider(height: 10, color: Colors.transparent),
              ],
            ),
          ),
      ],
    ]);
  }

  Widget _buildFinancial() {
    final b = _bill!;
    return _sectionCard('Amount Calculation', [
      _row('Scheduled Work Value', '₹${_inr(b.scheduledWorkValue)}'),
      _row('Less Execution (${b.lessExecutionPercent.toStringAsFixed(1)}%)', '− ₹${_inr(b.lessExecutionAmount)}', color: kErrorRed),
      _row('Gross Work Value (verified)', '₹${_inr(b.grossWorkValue)}', color: kSuccessGreen),
      _row('Eligible Amount', '₹${_inr(b.eligibleAmount)}', color: kSuccessGreen, bold: true),
      const Divider(),
      _row('Penalty', '₹${_inr(b.penaltyTotal)}', color: b.penaltyTotal > 0 ? kErrorRed : kSuccessGreen, bold: true),
      for (final p in b.penaltyRows)
        Padding(
          padding: const EdgeInsets.only(left: 170),
          child: Text('${p.name}  (${p.value.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ),
      _row('Other Recoveries', '− ₹${_inr(b.otherRecoveriesAmount)}', color: b.otherRecoveriesAmount > 0 ? kErrorRed : Colors.grey),
      for (final r in b.otherRecoveries)
        Padding(
          padding: const EdgeInsets.only(left: 170),
          child: Text('${r.label}: ₹${_inr(r.amount)}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ),
      _row('Net Amount', '₹${_inr(b.netAmount)}', bold: true),
      _row('GST (${b.gstRate.toStringAsFixed(1)}%)', '₹${_inr(b.gstAmount)}'),
      _row('Total Payable', '₹${_inr(b.totalPayable)}', color: Colors.deepOrange, bold: true),
      const SizedBox(height: 4),
    ], headerColor: Colors.deepOrange);
  }

  Widget _buildAudit() {
    final b = _bill!;
    return _sectionCard('Audit Trail (${b.auditTrail.length})', [
      for (final e in b.auditTrail.reversed.take(30))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 82, child: Text(e.at.length >= 16 ? e.at.substring(0, 16) : e.at,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.message, style: const TextStyle(fontSize: 11)),
                    Text('by ${e.byName}', style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 4),
    ], headerColor: Colors.blueGrey);
  }

  Widget _buildActions() {
    final b = _bill!;
    final buttons = <Widget>[];

    void add(Widget w) => buttons.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: w));

    if (_working) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    }

    if (b.status == 'DRAFT' && _can('GENERATE')) {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: () => _action('calculate'), icon: const Icon(Icons.calculate),
        style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
        label: const Text('Calculate Bill'))));
    }
    if (b.status == 'CALCULATED' && _can('GENERATE')) {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: () => _action('calculate'), icon: const Icon(Icons.refresh),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
        label: const Text('Recalculate'))));
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: () => _action('submit'), icon: const Icon(Icons.send),
        style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
        label: const Text('Submit for Verification'))));
    }
    if (b.status == 'SUBMITTED' && _can('APPROVE')) {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: () => _action('verify'), icon: const Icon(Icons.verified_user),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
        label: const Text('Verify Against Records'))));
    }
    if (b.status == 'VERIFIED' && _can('APPROVE')) {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: () => _action('approve'), icon: const Icon(Icons.check_circle),
        style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
        label: const Text('Approve'))));
    }
    if (b.status == 'APPROVED' && _can('APPROVE')) {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: () => _action('lock'), icon: const Icon(Icons.lock),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
        label: const Text('Lock Bill (Final)'))));
    }
    if (['APPROVED', 'LOCKED'].contains(b.status) && _can('PAY') && b.paymentStatus != 'paid') {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: _recordPayment, icon: const Icon(Icons.payment),
        style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
        label: const Text('Record Payment'))));
    }
    if ((b.status == 'DRAFT' || b.status == 'CALCULATED') && _can('MANAGE')) {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: _editRecoveries, icon: const Icon(Icons.request_quote),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
        label: const Text('Edit Other Recoveries'))));
    }
    if (!['DRAFT'].contains(b.status) && _can('MANAGE')) {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: _reopen, icon: const Icon(Icons.lock_open),
        style: ElevatedButton.styleFrom(backgroundColor: kWarningOrange, foregroundColor: Colors.white),
        label: const Text('Reopen Bill'))));
    }
    if ((b.status == 'DRAFT' || b.status == 'CALCULATED') && _can('MANAGE')) {
      add(SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
        onPressed: _delete, icon: const Icon(Icons.delete),
        style: ElevatedButton.styleFrom(backgroundColor: kErrorRed, foregroundColor: Colors.white),
        label: const Text('Delete Bill'))));
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(children: buttons);
  }
}