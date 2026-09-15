import 'package:crm_train/model/task_billing_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/task_billing_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'area_weightage_screen.dart';

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
  List<DailyTaskBillingResponse> _bills = [];
  List<AreaWeightage> _weightages = [];
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
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadWeightages(), _loadBills()]);
  }

  Future<void> _loadWeightages() async {
    try {
      final weightages = await TaskBillingRepository.getWeightages(widget.contractId, widget.stationId);
      if (!mounted) return;
      setState(() => _weightages = weightages);
    } catch (e) {
      if (!mounted) return;
      _showStatus('Weightages unavailable: $e', isError: true);
    }
  }

  Future<void> _loadBills() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final bills = await TaskBillingRepository.list(widget.contractId, widget.stationId, _month, _year);
      if (!mounted) return;
      setState(() {
        _bills = bills;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
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
      if (bill.dayExecutionRate == null) {
        _showStatus('No approved execution found for this date.', isError: true);
      } else {
        _showStatus('Preview loaded for ${bill.date}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
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
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      _showStatus(e.toString(), isError: true);
    }
  }

  Future<void> _manageWeightage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AreaWeightageScreen(
          contractId: widget.contractId,
          stationId: widget.stationId,
          stationName: widget.stationName,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
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
      body: _loading && _bill == null && _bills.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 14),
                  _buildWeightagesCard(),
                  const SizedBox(height: 14),
                  _buildBillCard(),
                  const SizedBox(height: 14),
                  _buildMonthBillsCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Header card ──────────────────────────────────────────────────────────────
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
                  '50% Task Execution — Per Sq.Ft. Daily Billing',
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

  // ── Weightage summary card ────────────────────────────────────────────────────
  Widget _buildWeightagesCard() {
    final sum = _weightages.fold<double>(0, (s, w) => s + w.weightage);
    final totalOk = (sum - 100).abs() <= 0.6;
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
                const Icon(Icons.pie_chart, size: 18, color: kRailwayBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Area Weightage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: totalOk ? kSuccessGreen : kErrorRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${sum.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: sum / 100,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                color: totalOk ? kSuccessGreen : kWarningOrange,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Weightages drive the weighted task-execution score. Each area bills at its own ₹/sq.ft. rate (contract-set) — areas without a rate use the derived rate.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            for (final w in _weightages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: w.ratePerSqFt != null && w.ratePerSqFt! > 1.8 ? kWarningOrange : kRailwayBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.areaName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${w.tenderedAreaSqFt.toStringAsFixed(0)} sq.ft. · ${w.cleaningFrequency}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${w.weightage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kRailwayBlue)),
                        if (w.ratePerSqFt != null) Text(_fmt.format(w.ratePerSqFt), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),
            if (_weightages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text('No weightages — flat sq.ft. ratio used.', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: _manageWeightage,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(_canGenerate ? 'Manage Area Weightage' : 'View Area Weightage'),
              style: TextButton.styleFrom(foregroundColor: kRailwayBlue),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active bill card ──────────────────────────────────────────────────────────
  Widget _buildBillCard() {
    final b = _bill;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: b == null
            ? Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select a date, Preview, then Generate to freeze the bill for this date.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title + status ──
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Daily Bill — ${b.date}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      _statusChip(b.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Contract period: ${b.contractStartDate} → ${b.contractEndDate}  (${b.contractDays} days)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 14),

                  // ── Execution progress ──
                  if (b.dayExecutionRate != null) ...[
                    Row(
                      children: [
                        const Text('Execution Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (b.dayExecutionRate ?? 0) / 100,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              color: (b.dayExecutionRate ?? 0) >= 80 ? kSuccessGreen : kWarningOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${b.dayExecutionRate!.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: b.dayExecutionRate! >= 80 ? kSuccessGreen : kWarningOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // ── Key figures ──
                  _kvRow('Daily base task (contract÷30 days)', _fmt.format(b.dailyBaseTask)),
                  _kvRow('Executed / Expected sq.ft.', '${b.executedSqFt.toStringAsFixed(0)} / ${b.expectedSqFt.toStringAsFixed(0)}'),
                  if (b.weighted != null)
                    _kvRow('Weighted execution score', '${(b.weighted!['weightedScore'] ?? 0).toStringAsFixed(1)}%'),
                  const Divider(height: 18),
                  _kvRow('Gross amount', _fmt.format(b.grossAmount)),
                  if (b.deduction > 0) _kvRow('Deduction', _fmt.format(b.deduction), valueColor: kErrorRed),
                  _kvRow('Net payable', _fmt.format(b.netAmount), bold: true, valueColor: kSuccessGreen),
                  const SizedBox(height: 14),

                  // ── Area detail table ──
                  const Text('Area-wise Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  _areaTableHeader(),
                  for (var i = 0; i < b.rows.length; i++)
                    _areaTableRow(b.rows[i], i.isEven),
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

  Widget _areaTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.07), borderRadius: BorderRadius.circular(6)),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Area', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kRailwayBlue))),
          Expanded(flex: 2, child: Text('Executed', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kRailwayBlue))),
          Expanded(flex: 2, child: Text('Rate/ft²', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kRailwayBlue))),
          Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kRailwayBlue))),
        ],
      ),
    );
  }

  Widget _areaTableRow(Map<String, dynamic> r, bool even) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: even ? Colors.grey[50] : Colors.white),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('${r['areaName']}', style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text('${r['executedSqFt']?.toStringAsFixed(0) ?? '0'}/${r['expectedSqFt']?.toStringAsFixed(0) ?? '0'}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmt.format(r['ratePerSqFt'] ?? 0), textAlign: TextAlign.end, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmt.format(r['areaAmount'] ?? 0), textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kRailwayBlue)),
          ),
        ],
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

  // ── Month bills list card ─────────────────────────────────────────────────────
  Widget _buildMonthBillsCard() {
    final total = _bills.fold<double>(0, (s, b) => s + b.netAmount);
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
                    _load();
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
                    _load();
                  },
                ),
              ],
            ),
            if (_bills.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: kSuccessGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Text('${_bills.length} bill${_bills.length != 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Text('Total: ', style: TextStyle(fontSize: 12)),
                    Text(_fmt.format(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kSuccessGreen)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_bills.isEmpty)
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
            else
              for (final b in _bills)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kRailwayBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(b.date.split('-').last, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kRailwayBlue)),
                  ),
                  title: Text(b.date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'exec ${b.executedSqFt.toStringAsFixed(0)} / ${b.expectedSqFt.toStringAsFixed(0)} sq.ft. · ${b.dayExecutionRate != null ? '${b.dayExecutionRate!.toStringAsFixed(0)}% rate' : '—'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kSuccessGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_fmt.format(b.netAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kSuccessGreen)),
                  ),
                  onTap: () => setState(() {
                    _bill = b;
                    _dateCtrl.text = b.date;
                  }),
                ),
          ],
        ),
      ),
    );
  }
}
