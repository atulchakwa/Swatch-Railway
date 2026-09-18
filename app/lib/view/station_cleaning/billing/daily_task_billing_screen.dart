import 'package:crm_train/model/task_billing_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/task_billing_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'area_rate_config_screen.dart';

class DailyTaskBillingScreen extends StatefulWidget {
  final String contractId;
  final String stationId;
  final String stationName;
  const DailyTaskBillingScreen({super.key, required this.contractId, required this.stationId, required this.stationName});

  @override
  State<DailyTaskBillingScreen> createState() => _DailyTaskBillingScreenState();
}

class _DailyTaskBillingScreenState extends State<DailyTaskBillingScreen> {
  final _dateCtrl = TextEditingController(text: _today());
  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  DailyTaskBillingResponse? _bill;
  DailyBillingMonth _monthData = DailyBillingMonth();
  bool _loading = false;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _can(String action) {
    final role = (Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '').toUpperCase().replaceAll(' ', '_');
    const perms = {
      'SUPER_ADMIN': {'VIEW', 'GENERATE', 'MANAGE'},
      'COMPANY_MASTER': {'VIEW', 'GENERATE', 'MANAGE'},
      'RAILWAY_MASTER': {'VIEW'},
      'ADMIN': {'VIEW', 'GENERATE', 'MANAGE'},
      'RAILWAY_ADMIN': {'VIEW', 'GENERATE', 'MANAGE'},
      'CONTRACTOR_MASTER': {'VIEW'},
      'CONTRACTOR_ADMIN': {'VIEW', 'GENERATE', 'MANAGE'},
      'CONTRACTOR_SUPERVISOR': {'VIEW'},
    };
    return (perms[role] ?? <String>{}).contains(action);
  }

  bool get _canGenerate => _can('GENERATE');
  bool get _isReadOnly => !_canGenerate;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final month = await TaskBillingRepository.list(widget.contractId, widget.stationId, _month, _year);
      if (!mounted) return;
      setState(() {
        _monthData = month;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showStatus('Bills unavailable: $e', isError: true);
    }
  }

  Future<void> _shiftDate(int days) async {
    final parsed = DateTime.tryParse(_dateCtrl.text.trim());
    final base = parsed ?? DateTime.now();
    final shifted = base.add(Duration(days: days));
    _dateCtrl.text = '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
    setState(() {});
    await _preview();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_dateCtrl.text.trim()) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now.add(const Duration(days: 1)),
      helpText: 'Pick a billing date (past days close automatically)',
    );
    if (picked == null || !mounted) return;
    _dateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {});
    final bill = await TaskBillingRepository.getByDate(widget.contractId, widget.stationId, _dateCtrl.text.trim());
    if (!mounted) return;
    if (bill != null) {
      setState(() => _bill = bill);
    } else {
      await _preview();
    }
  }

  void _showStatus(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? kErrorRed : kSuccessGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _preview() async {
    setState(() => _loading = true);
    try {
      final bill = await TaskBillingRepository.preview(widget.contractId, widget.stationId, _dateCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _bill = bill;
        _loading = false;
      });
      if (bill.areaRows.isEmpty) {
        _showStatus('No cleaning tasks found for this date.', isError: true);
      } else {
        _showStatus('Preview loaded for ${bill.date}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showStatus(e.toString(), isError: true);
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final bill = await TaskBillingRepository.generate(widget.contractId, widget.stationId, _dateCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _bill = bill;
        _loading = false;
      });
      _showStatus(bill.status == 'generated' ? 'Daily bill generated (immutable).' : 'Existing bill reused.');
      await _loadBills();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showStatus(e.toString(), isError: true);
    }
  }

  // ── Formatting helpers ──────────────────────────────────────────────────────
  String _money(double v) => _fmt.format(v);
  String _pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final b = _bill;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Task Billing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.stationName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading && _bill == null && _monthData.bills.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBills,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 14),
                  _buildAreaRatesCard(),
                  const SizedBox(height: 14),
                  if (b == null)
                    _buildEmptyHint()
                  else ...[
                    _buildBillSummaryCard(b),
                    const SizedBox(height: 14),
                    _buildPerformanceCard(b),
                    const SizedBox(height: 14),
                    _buildAreaTableCard(b),
                    const SizedBox(height: 14),
                  ],
                  _buildMonthBillsCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Header card ─────────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: kRailwayBannerGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Daily Billing — Value = Area × Rate × Executions',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : () => _shiftDate(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                tooltip: 'Previous day',
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _dateCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Date',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'YYYY-MM-DD',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.white60, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.date_range, color: Colors.white70, size: 20),
                      tooltip: 'Pick date',
                      onPressed: _loading ? null : _pickDate,
                    ),
                  ),
                  onSubmitted: (_) => _preview(),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => _shiftDate(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                tooltip: 'Next day',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _preview,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Preview / View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (_canGenerate) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: Icon(_loading ? Icons.hourglass_empty : Icons.check_circle_outline, size: 18),
                    label: Text(_loading ? 'Working…' : 'Generate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD54F),
                      foregroundColor: kTextPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('View-only billing access', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_isReadOnly)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.white70, size: 13),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'You can check all billed dates and past months. Generation is done by contractor admin / railway.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Area rates management ───────────────────────────────────────────────────
  Widget _buildAreaRatesCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.currency_rupee, size: 18, color: kRailwayBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Area Rates (₹/sq.ft.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Each area bills at its own ₹/sq.ft. — fees are applied at preview/generate time.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openAreaRates,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Manage Area Rates'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRailwayBlue,
                  side: BorderSide(color: kRailwayBlue.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAreaRates() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AreaRateConfigScreen(contractId: widget.contractId)));
    if (!mounted) return;
    if (_bill != null) await _preview();
  }

  Widget _buildEmptyHint() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Select a date, Preview, then Generate to freeze the bill for that date.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'generated' ? kSuccessGreen : kRailwayBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  // ── Daily bill summary card ─────────────────────────────────────────────────
  Widget _buildBillSummaryCard(DailyTaskBillingResponse b) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, size: 18, color: kRailwayBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Daily Bill — ${b.date}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                _statusChip(b.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Contract: ${b.contractNumber} · ${b.contractStartDate} → ${b.contractEndDate} (${b.contractDays} days) · ₹${b.ratePerSqft.toStringAsFixed(2)}/sq.ft.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 14),

            const Text('Bill Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            _kvRow('Expected Work Value', _money(b.expectedWorkValue)),
            _kvRow('Actual Executed Value', _money(b.actualExecutionValue), bold: true, valueColor: kSuccessGreen),
            _kvRow('Executed / Expected sq.ft.', '${b.executedSqFt.toStringAsFixed(0)} / ${b.expectedSqFt.toStringAsFixed(0)}'),
            const SizedBox(height: 6),
            if (b.taskExecutionScore != null) ...[
              Row(
                children: [
                  const Expanded(child: Text('Task Execution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (b.taskExecutionScore ?? 0) / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        color: (b.taskExecutionScore ?? 0) >= 80 ? kSuccessGreen : kWarningOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${b.taskExecutionScore!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: b.taskExecutionScore! >= 80 ? kSuccessGreen : kWarningOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            const Divider(height: 18),
            if (b.lessExecutionAmount > 0) _kvRow('Less on performance (${b.lessExecutionPercent.toStringAsFixed(0)}%)', _money(b.lessExecutionAmount), valueColor: kErrorRed),
            _kvRow('Eligible Amount', _money(b.eligibleAmount)),
            if (b.penaltyApplied && b.penalty > 0) _kvRow('Penalty', _money(b.penalty), valueColor: kErrorRed),
            _kvRow('Deduction', _money(b.deduction), valueColor: kErrorRed),
            _kvRow('Net Payable', _money(b.netAmount), bold: true, valueColor: kSuccessGreen),
            if (b.gstRate > 0) _kvRow('GST (${b.gstRate.toStringAsFixed(0)}%)', _money(b.gstAmount)),
            if (b.gstRate > 0) _kvRow('Total Payable', _money(b.totalPayable), bold: true, valueColor: kRailwayBlue),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String label, String value, {bool bold = false, Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.normal, color: bold ? kRailwayBlue : Colors.black87)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: valueColor ?? Colors.black87)),
          ],
        ),
      );

  // ── Performance summary card (50 / 20 / 30) ─────────────────────────────────
  Widget _buildPerformanceCard(DailyTaskBillingResponse b) {
    Widget row(String name, int weight, double? score, double? marks) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 4, height: 30,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: kRailwayBlue, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(score == null ? 'No data (counts as full)' : 'achievement ${score.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 11, color: score == null ? Colors.grey[500] : Colors.grey[600])),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kRailwayBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$weight%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kRailwayBlue)),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: Text(
                marks == null ? '—' : '${marks.toStringAsFixed(1)} / $weight',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    final cats = b.categories;
    final Map<String, Map<String, dynamic>> bySrc = {};
    for (final c in cats) {
      bySrc[c['dataSource']] = c;
    }
    final exec = bySrc['execution'];
    final insp = bySrc['inspection'];
    final fb = bySrc['feedback'];

    final scoreColor = b.overallScore >= 90
        ? kSuccessGreen
        : b.overallScore >= 70
            ? kWarningOrange
            : kErrorRed;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, size: 18, color: kRailwayBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Performance Summary (50 / 20 / 30)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            row('Task Execution', 50, exec?['achievement'] as double?, (exec?['marks'] as num?)?.toDouble()),
            row('Railway Inspection', 20, insp?['achievement'] as double?, (insp?['marks'] as num?)?.toDouble()),
            row('Passenger Feedback', 30, fb?['achievement'] as double?, (fb?['marks'] as num?)?.toDouble()),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Final Performance Score', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: scoreColor, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${b.overallScore.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('Grade ${b.grade}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Area-wise execution table ───────────────────────────────────────────────
  Widget _buildAreaTableCard(DailyTaskBillingResponse b) {
    const colW = {'area': 130.0, 'sqft': 78.0, 'rate': 92.0, 'req': 58.0, 'done': 58.0, 'exp': 108.0, 'act': 108.0};
    Widget cell(Object? text, double w, {TextAlign align = TextAlign.right, bool bold = false, Color? color}) {
      return SizedBox(
        width: w,
        child: Text(
          text == null ? '—' : text.toString(),
          textAlign: align,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart, size: 18, color: kRailwayBlue),
                const SizedBox(width: 8),
                const Expanded(child: Text('Area-wise Execution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.07), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      children: [
                        cell('Area', colW['area']!, align: TextAlign.left, bold: true, color: kRailwayBlue),
                        cell('SQFT', colW['sqft']!, bold: true, color: kRailwayBlue),
                        cell('Rate/sq.ft.', colW['rate']!, bold: true, color: kRailwayBlue),
                        cell('Req', colW['req']!, bold: true, color: kRailwayBlue),
                        cell('Done', colW['done']!, bold: true, color: kRailwayBlue),
                        cell('Expected', colW['exp']!, bold: true, color: kRailwayBlue),
                        cell('Actual', colW['act']!, bold: true, color: kRailwayBlue),
                      ],
                    ),
                  ),
                  for (var i = 0; i < b.areaRows.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      color: i.isEven ? Colors.grey[50] : Colors.white,
                      child: Row(
                        children: [
                          cell(b.areaRows[i]['areaName'] ?? '—', colW['area']!, align: TextAlign.left),
                          cell((b.areaRows[i]['areaSqft'] as num?)?.toDouble().toStringAsFixed(0) ?? '0', colW['sqft']!),
                          cell('₹${((b.areaRows[i]['ratePerSqft'] as num?) ?? 0).toStringAsFixed(2)}', colW['rate']!),
                          cell('${b.areaRows[i]['required'] ?? 0}', colW['req']!),
                          cell('${b.areaRows[i]['completed'] ?? 0}', colW['done']!),
                          cell(_money(((b.areaRows[i]['expectedValue'] as num?) ?? 0).toDouble()), colW['exp']!, bold: true),
                          cell(_money(((b.areaRows[i]['actualExecutionValue'] as num?) ?? 0).toDouble()), colW['act']!, bold: true, color: kSuccessGreen),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Each scheduled pass is valued at area sq.ft. × ₹/sq.ft. Executions are counted from APPROVED shift summaries (the approval unit) — tasks have no individual approval step.',
              style: TextStyle(fontSize: 10, color: Colors.grey[500], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ── Monthly bills card ──────────────────────────────────────────────────────
  Widget _buildMonthBillsCard() {
    const colW = {'date': 92.0, 'exp': 104.0, 'act': 104.0, 'tex': 62.0, 'ins': 62.0, 'fb': 62.0, 'fin': 62.0, 'gross': 104.0, 'ded': 92.0, 'net': 104.0};
    Widget h(String t, double w) => SizedBox(
          width: w,
          child: Text(t, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kRailwayBlue)),
        );
    Widget c(String t, double w, {bool bold = false, Color? color}) => SizedBox(
          width: w,
          child: Text(t, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87)),
        );

    final month = _monthData;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range, size: 18, color: kRailwayBlue),
                const SizedBox(width: 8),
                const Expanded(child: Text('Monthly Bills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  color: kRailwayBlue,
                  onPressed: () {
                    setState(() { _month--; if (_month < 1) { _month = 12; _year--; } });
                    _loadBills();
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.07), borderRadius: BorderRadius.circular(16)),
                  child: Text('$_month / $_year', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kRailwayBlue)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  color: kRailwayBlue,
                  onPressed: () {
                    setState(() { _month++; if (_month > 12) { _month = 1; _year++; } });
                    _loadBills();
                  },
                ),
              ],
            ),
            if (month.bills.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No bills generated for $_month/$_year. Use ◀ ▶ to browse past months, or pick a date above to view/preview any day.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: kSuccessGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Text('${month.count} bill${month.count != 1 ? 's' : ''} · ${month.totalDeduction > 0 ? 'Deduction ${_money(month.totalDeduction)} · ' : ''}Net ${_money(month.totalNetAmount)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('Expected ${_money(month.totalExpectedWorkValue)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.07), borderRadius: BorderRadius.circular(6)),
                      child: Row(children: [
                        h('Date', colW['date']!),
                        h('Expected ₹', colW['exp']!),
                        h('Actual ₹', colW['act']!),
                        h('TaskEx %', colW['tex']!),
                        h('Insp %', colW['ins']!),
                        h('Feedback %', colW['fb']!),
                        h('Final %', colW['fin']!),
                        h('Gross ₹', colW['gross']!),
                        h('Deduct ₹', colW['ded']!),
                        h('Net ₹', colW['net']!),
                      ]),
                    ),
                    for (final bill in month.bills) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                        decoration: BoxDecoration(
                          color: kSuccessGreen.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(children: [
                          c(bill.date, colW['date']!),
                          c(_money(bill.expectedWorkValue), colW['exp']!),
                          c(_money(bill.actualExecutionValue), colW['act']!),
                          c(_pct(bill.taskExecutionScore), colW['tex']!),
                          c(_pct(bill.inspectionScore), colW['ins']!),
                          c(_pct(bill.feedbackScore), colW['fb']!),
                          c('${bill.overallScore.toStringAsFixed(1)}', colW['fin']!, bold: true),
                          c(_money(bill.grossAmount), colW['gross']!),
                          c(_money(bill.deduction), colW['ded']!, color: bill.deduction > 0 ? kErrorRed : Colors.grey),
                          c(_money(bill.netAmount), colW['net']!, bold: true, color: kSuccessGreen),
                        ]),
                      ),
                      const Divider(height: 1, thickness: 1),
                    ],
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
                      child: Row(children: [
                        c('TOTAL', colW['date']!, bold: true, color: kRailwayBlue),
                        c(_money(month.totalExpectedWorkValue), colW['exp']!, bold: true),
                        c(_money(month.totalActualExecutionValue), colW['act']!, bold: true),
                        c(_pct(month.avgTaskExecutionScore), colW['tex']!, bold: true),
                        c(_pct(month.avgInspectionScore), colW['ins']!, bold: true),
                        c(_pct(month.avgFeedbackScore), colW['fb']!, bold: true),
                        c(_pct(month.avgFinalScore), colW['fin']!, bold: true),
                        c(_money(month.totalGrossAmount), colW['gross']!, bold: true),
                        c(_money(month.totalDeduction), colW['ded']!, bold: true),
                        c(_money(month.totalNetAmount), colW['net']!, bold: true, color: kSuccessGreen),
                      ]),
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