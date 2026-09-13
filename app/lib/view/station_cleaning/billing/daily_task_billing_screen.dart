import 'package:crm_train/model/task_billing_models.dart';
import 'package:crm_train/repositories/task_billing_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
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
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  DailyTaskBillingResponse? _bill;
  List<DailyTaskBillingResponse> _bills = [];
  List<AreaWeightage> _weightages = [];
  bool _loading = false;
  String _status = '';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final weightages = await TaskBillingRepository.getWeightages(widget.contractId, widget.stationId);
      final bills = await TaskBillingRepository.list(widget.contractId, widget.stationId, _month, _year);
      if (!mounted) return;
      setState(() {
        _weightages = weightages;
        _bills = bills;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = e.toString();
      });
    }
  }

  Future<void> _preview() async {
    setState(() => _loading = true);
    try {
      final bill = await TaskBillingRepository.preview(widget.contractId, widget.stationId, _dateCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _bill = bill;
        _status = bill.dayExecutionRate == null ? 'No approved execution for this date.' : '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final bill = await TaskBillingRepository.generate(widget.contractId, widget.stationId, _dateCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _bill = bill;
        _status = bill.status == 'generated' ? 'Daily bill generated (immutable).' : 'Existing bill reused.';
        _loading = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.toString();
        _loading = false;
      });
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
      appBar: AppBar(title: const Text('Daily Task Billing'), backgroundColor: kRailwayBlue, iconTheme: const IconThemeData(color: Colors.white)),
      body: _loading && _bill == null && _bills.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildControls(),
                  if (_status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(_status, style: const TextStyle(fontSize: 12, color: kErrorRed)),
                    ),
                  const SizedBox(height: 6),
                  _buildWeightagesCard(),
                  const SizedBox(height: 6),
                  _buildBillCard(),
                  const SizedBox(height: 6),
                  _buildMonthBillsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('50% Task Execution — daily bill (per sq.ft. × rate)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _dateCtrl,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _loading ? null : _preview, child: const Text('Preview')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(onPressed: _loading ? null : _generate, child: const Text('Generate Bill')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightagesCard() {
    final sum = _weightages.fold<double>(0, (s, w) => s + w.weightage);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Area Weightages (dept-editable)', style: TextStyle(fontWeight: FontWeight.bold))),
                Text('Total: ${sum.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: sum > 100 ? kErrorRed : Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Each update is versioned + audited. Weightages drive the weighted task-execution score.', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            for (final w in _weightages)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(w.areaName, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${w.tenderedAreaSqFt.toStringAsFixed(0)} sq.ft. · ${w.cleaningFrequency} · rate ${w.ratePerSqFt?.toStringAsFixed(3) ?? 'derived'}/sq.ft.', style: const TextStyle(fontSize: 11)),
                trailing: Text('${w.weightage}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (_weightages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('No weightages configured — the daily bill falls back to a flat sq.ft. ratio.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            TextButton.icon(
              onPressed: () => _manageWeightage(),
              icon: const Icon(Icons.tune),
              label: const Text('Manage Area Weightage'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard() {
    final b = _bill;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: b == null
            ? const Text('Select a date, Preview, then Generate to freeze the bill.', style: TextStyle(fontSize: 12, color: Colors.grey))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Daily Bill — ${b.date}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (b.status.isNotEmpty)
                        Chip(label: Text(b.status, style: const TextStyle(fontSize: 10)), backgroundColor: b.status == 'generated' ? Colors.green : Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Contract days: ${b.contractDays} (${b.contractStartDate} → ${b.contractEndDate})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 10),
                  _kv('Daily base (50% of contract/365-days-rate)', '₹${b.dailyBaseTask.toStringAsFixed(2)}'),
                  _kv('Executed / Expected sq.ft.', '${b.executedSqFt.toStringAsFixed(0)} / ${b.expectedSqFt.toStringAsFixed(0)}'),
                  _kv('Day execution rate', b.dayExecutionRate == null ? '—' : '${b.dayExecutionRate!.toStringAsFixed(1)}%'),
                  _kv('Weighted score', b.weighted?['weightedScore']?.toStringAsFixed(1) ?? '—'),
                  const Divider(),
                  _kv('Gross amount', '₹${b.grossAmount.toStringAsFixed(2)}'),
                  _kv('Deduction', '₹${b.deduction.toStringAsFixed(2)}'),
                  _kv('Net payable', '₹${b.netAmount.toStringAsFixed(2)}', emphasize: true),
                  const SizedBox(height: 8),
                  const Text('Area-wise detail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  for (final r in b.rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text('${r['areaName']}', style: const TextStyle(fontSize: 12))),
                          Expanded(flex: 2, child: Text('${r['billableSqFt']}/${r['expectedSqFt']} sq.ft.', style: const TextStyle(fontSize: 11))),
                          Expanded(flex: 2, child: Text('@ ${r['ratePerSqFt']}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 11))),
                          Expanded(flex: 2, child: Text('₹${r['areaAmount']}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _kv(String label, String value, {bool emphasize = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: emphasize ? kRailwayBlue : Colors.black, fontWeight: emphasize ? FontWeight.w700 : FontWeight.normal)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );

  Widget _buildMonthBillsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Month Bills', style: TextStyle(fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18),
                  onPressed: () {
                    setState(() {
                      _month--;
                      if (_month < 1) {
                        _month = 12;
                        _year--;
                      }
                    });
                    _load();
                  },
                ),
                Text('$_month/$_year'),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: () {
                    setState(() {
                      _month++;
                      if (_month > 12) {
                        _month = 1;
                        _year++;
                      }
                    });
                    _load();
                  },
                ),
              ],
            ),
            if (_bills.isEmpty)
              const Text('No generated daily bills for this month.', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              for (final b in _bills)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.date, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('exec ${b.executedSqFt.toStringAsFixed(0)} / ${b.expectedSqFt.toStringAsFixed(0)} sq.ft.', style: const TextStyle(fontSize: 11)),
                  trailing: Text('₹${b.netAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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