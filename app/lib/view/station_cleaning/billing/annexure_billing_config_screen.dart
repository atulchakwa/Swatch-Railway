import 'package:crm_train/model/annexure_billing_models.dart';
import 'package:crm_train/repositories/annexure_billing_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Annexure-4B Contract Rule Engine — Admin Configuration UI.
///
/// Shows CONTRACT -> ITEM (40 contractual items) -> AREA COMPONENTS hierarchy,
/// enforces area weightage <= contractual weightage, allows unallocated
/// weightage, runs the daily-money-value deduction engine and tracks the
/// weightage-transfer audit trail.
class AnnexureBillingConfigScreen extends StatefulWidget {
  final String contractId;
  final String? contractNumber;
  final String? stationName;

  const AnnexureBillingConfigScreen({
    super.key,
    required this.contractId,
    this.contractNumber,
    this.stationName,
  });

  @override
  State<AnnexureBillingConfigScreen> createState() => _AnnexureBillingConfigScreenState();
}

class _AnnexureBillingConfigScreenState extends State<AnnexureBillingConfigScreen> {
  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _pct = NumberFormat.decimalPattern('en_IN');

  final Set<String> _expanded = {};
  String _query = '';
  bool _loading = false;
  bool _seeding = false;

  AnnexureContractItemsResult _result = AnnexureContractItemsResult();
  AnnexureBillingSummary _summary = AnnexureBillingSummary();
  List<AnnexureWeightageTransfer> _transfers = [];

  TextEditingController _fromCtrl = TextEditingController();
  TextEditingController _toCtrl = TextEditingController();
  bool _deductionsLoading = false;
  bool _finalizing = false;
  bool _summaryLoading = false;

  int _tab = 0;

  List<AnnexureContractItem> get _visibleItems {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _result.items;
    return _result.items.where((i) {
      return i.contractualDescription.toLowerCase().contains(q) ||
          i.itemNumber.toString() == q ||
          i.areas.any((a) => a.areaName.toLowerCase().contains(q));
    }).toList();
  }

  double get _totalAllocated =>
      _result.items.fold(0.0, (s, i) => s + i.allocatedWeightage);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0);
    _fromCtrl = TextEditingController(text: _ymd(first));
    _toCtrl = TextEditingController(text: _ymd(last));
    _load();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AnnexureBillingRepository.items(widget.contractId);
      final validate = await AnnexureBillingRepository.validate(widget.contractId);
      if (!mounted) return;
      setState(() {
        _result = res;
        _result = AnnexureContractItemsResult(
          count: res.count,
          items: res.items,
          totalWeightage: res.totalWeightage,
          warnings: validate.warnings,
          valid: validate.valid,
        );
        _loading = false;
      });
      if (res.count == 0) {
        _promptSeed();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Failed to load contract items: $e', error: true);
    }
  }

  Future<void> _promptSeed() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed Annexure-4B items?'),
        content: const Text(
          'This contract has no Annexure-4B items yet. Seed the 40 contractual '
          'items exactly as per the contract?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Seed 40 items')),
        ],
      ),
    );
    if (go == true) {
      setState(() => _seeding = true);
      try {
        final r = await AnnexureBillingRepository.seed(widget.contractId);
        if (!mounted) return;
        _toast(r.message);
        await _load();
      } catch (e) {
        if (!mounted) return;
        _toast('Seed failed: $e', error: true);
      } finally {
        if (mounted) setState(() => _seeding = false);
      }
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? kErrorRed : kInfo,
    ));
  }

  // ─── Tab: Deductions ───────────────────────────────────────────────────────
  Future<void> _loadSummary() async {
    setState(() => _summaryLoading = true);
    try {
      final s = await AnnexureBillingRepository.summary(
        widget.contractId,
        billingStart: _fromCtrl.text,
        billingEnd: _toCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _summary = s;
        _summaryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _summaryLoading = false);
      _toast('Summary failed: $e', error: true);
    }
  }

  Future<void> _calculate() async {
    setState(() => _deductionsLoading = true);
    try {
      final r = await AnnexureBillingRepository.calculateDeductions(
        widget.contractId,
        billingStart: _fromCtrl.text,
        billingEnd: _toCtrl.text,
      );
      if (!mounted) return;
      _toast(r.message);
      await _loadSummary();
    } catch (e) {
      if (!mounted) return;
      _toast('Calculation failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _deductionsLoading = false);
    }
  }

  Future<void> _finalizeDeductions() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize deductions?'),
        content: Text(
          'This makes the deductions for ${_fromCtrl.text} → ${_toCtrl.text} '
          'IMMUTABLE. Any existing final bill for this period cannot be recalculated.\n\n'
          'Historical bills are locked by design. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalize')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _finalizing = true);
    try {
      final r = await AnnexureBillingRepository.finalizeDeductions(
        widget.contractId,
        billingStart: _fromCtrl.text,
        billingEnd: _toCtrl.text,
      );
      if (!mounted) return;
      _toast(r.message);
      await _loadSummary();
    } catch (e) {
      if (!mounted) return;
      _toast('Finalize failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  Future<void> _loadTransfers() async {
    try {
      final t = await AnnexureBillingRepository.transfers(widget.contractId);
      if (!mounted) return;
      setState(() => _transfers = t);
    } catch (e) {
      if (!mounted) return;
      _toast('Transfers failed: $e', error: true);
    }
  }

  // ─── Item actions ──────────────────────────────────────────────────────────
  Future<void> _addArea(AnnexureContractItem item) async {
    final area = await _areaDialog(item, null);
    if (area == null) return;
    try {
      final r = await AnnexureBillingRepository.addArea(
        item.uid.isEmpty ? item.id : item.uid,
        areaName: area['name'],
        allocatedWeightage: area['weightage'],
        areaCode: area['code'],
        unit: area['unit'],
        quantity: area['quantity'],
        rate: area['rate'],
        frequencyOverride: area['frequency'],
        remarks: area['remarks'],
      );
      if (!mounted) return;
      _toast(r.message);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Add area failed: $e', error: true);
    }
  }

  Future<void> _editArea(AnnexureContractItem item, AnnexureAreaComponent a) async {
    final area = await _areaDialog(item, a);
    if (area == null) return;
    try {
      final r = await AnnexureBillingRepository.updateArea(
        a.uid.isEmpty ? a.id : a.uid,
        areaName: area['name'],
        allocatedWeightage: area['weightage'],
        areaCode: area['code'],
        unit: area['unit'],
        quantity: area['quantity'],
        rate: area['rate'],
        frequencyOverride: area['frequency'],
        remarks: area['remarks'],
      );
      if (!mounted) return;
      _toast(r.message);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Update area failed: $e', error: true);
    }
  }

  Future<void> _deleteArea(AnnexureAreaComponent a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate area?'),
        content: Text('Deactivate "${a.areaName}"? Its weightage frees up for re-allocation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await AnnexureBillingRepository.deleteArea(a.uid.isEmpty ? a.id : a.uid);
      if (!mounted) return;
      _toast(r.message);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Deactivate failed: $e', error: true);
    }
  }

  Future<void> _markUnavailable(AnnexureContractItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark Item ${item.itemNumber} unavailable?'),
        content: Text(
          'Its weightage (${item.effectiveWeightage}%) transfers to Item 1 exactly '
          'as per the contract rule. This is audit-logged. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Transfer to Item 1')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await AnnexureBillingRepository.markUnavailable(item.uid.isEmpty ? item.id : item.uid);
      if (!mounted) return;
      _toast(r.message);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e', error: true);
    }
  }

  Future<void> _addNewItem() async {
    final name = TextEditingController();
    final weight = TextEditingController();
    final freq = TextEditingController();
    final newWeightage = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New contractual item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Description *')),
            TextField(controller: weight, decoration: const InputDecoration(labelText: 'Weightage % *'), keyboardType: TextInputType.number),
            TextField(controller: freq, decoration: const InputDecoration(labelText: 'Frequency')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(weight.text.trim());
              if (name.text.trim().isEmpty || w == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Description and weightage required')));
                return;
              }
              Navigator.pop(ctx, w);
            },
            child: const Text('Add (reduces Item 1)'),
          ),
        ],
      ),
    );
    if (newWeightage == null) return;
    try {
      final r = await AnnexureBillingRepository.addNewItem(
        widget.contractId,
        description: name.text.trim(),
        weightage: newWeightage,
        frequency: freq.text.trim().isEmpty ? null : freq.text.trim(),
        remarks: 'Added manually with authorized confirmation',
      );
      if (!mounted) return;
      _toast(r.message);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Add item failed: $e', error: true);
    }
  }

  Future<Map<String, dynamic>?> _areaDialog(AnnexureContractItem item, AnnexureAreaComponent? a) async {
    final name = TextEditingController(text: a?.areaName ?? '');
    final code = TextEditingController(text: a?.areaCode ?? '');
    final unit = TextEditingController(text: a?.unit ?? '');
    final qty = TextEditingController(text: a?.quantity?.toString() ?? '');
    final rate = TextEditingController(text: a?.rate?.toString() ?? '');
    final freq = TextEditingController(text: a?.frequencyOverride ?? '');
    final remarks = TextEditingController(text: a?.remarks ?? '');
    final weight = TextEditingController(text: a?.allocatedWeightage.toString() ?? '');

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final double liveTotal = (item.allocatedWeightage - (a?.allocatedWeightage ?? 0));
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final parsed = double.tryParse(weight.text.trim());
            final effective = parsed ?? 0;
            final projected = liveTotal + effective;
            final remaining = item.effectiveWeightage - projected;
            final blocked = projected > item.effectiveWeightage + 0.0001;
            return AlertDialog(
              title: Text(a == null ? 'Add area under Item ${item.itemNumber}' : 'Edit area'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Area name * (e.g. PF-01)')),
                    TextField(controller: code, decoration: const InputDecoration(labelText: 'Area code')),
                    Row(children: [
                      Expanded(
                        child: TextField(controller: weight,
                          decoration: const InputDecoration(labelText: 'Weightage % *'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setLocal(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit (sqft/m/nos)')),
                      ),
                    ]),
                    Row(children: [
                      Expanded(
                        child: TextField(controller: qty, decoration: const InputDecoration(labelText: 'Quantity / As available'), keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(controller: rate, decoration: const InputDecoration(labelText: 'Rate ₹'), keyboardType: TextInputType.number),
                      ),
                    ]),
                    TextField(controller: freq, decoration: const InputDecoration(labelText: 'Frequency override')),
                    TextField(controller: remarks, decoration: const InputDecoration(labelText: 'Remarks')),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: blocked ? kErrorRed.withOpacity(0.08) : Colors.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        blocked
                            ? '⛔ Area-wise weightage cannot exceed the contractual weightage. '
                                'Item limit: ${item.effectiveWeightage.toStringAsFixed(2)}%'
                            : 'Item ${item.itemNumber} limit: ${item.effectiveWeightage.toStringAsFixed(2)}%  •  '
                                'Areas: ${_fmtPct(liveTotal)}  +  New: ${_fmtPct(effective)}  =  ${_fmtPct(projected)}   '
                                'Remaining: ${_fmtPct(remaining)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: blocked ? kErrorRed : kInfo,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    if (blocked) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Area-wise weightage cannot exceed the contractual weightage of this item.', backgroundColor: kErrorRed)),
                      );
                      return;
                    }
                    if (name.text.trim().isEmpty || weight.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Area name and weightage are required')));
                      return;
                    }
                    Navigator.pop(ctx, {
                      'name': name.text.trim(),
                      'weightage': double.tryParse(weight.text.trim()) ?? 0,
                      'code': code.text.trim().isEmpty ? null : code.text.trim(),
                      'unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
                      'quantity': double.tryParse(qty.text.trim()),
                      'rate': double.tryParse(rate.text.trim()),
                      'frequency': freq.text.trim().isEmpty ? null : freq.text.trim(),
                      'remarks': remarks.text.trim().isEmpty ? null : remarks.text.trim(),
                    });
                  },
                  child: Text(a == null ? 'Add Area' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmtPct(double v) => '${_pct.format(v)}%';

  // ─── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Annexure-4B — ${widget.contractNumber ?? 'Contract'}'),
        backgroundColor: kRailwayBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _heroBanner(),
          if (_result.warnings.isNotEmpty)
            Container(
              width: double.infinity,
              color: kWarningOrange.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                _result.warnings.first,
                style: const TextStyle(color: kWarningOrange, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search item / area…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          _tabSelector(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _tab,
                    children: [_itemsTab(), _deductionsTab(), _transfersTab()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kRailwayBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _tabButton(0, 'Items', Icons.list_alt),
          _tabButton(1, 'Deductions', Icons.calculate_outlined),
          _tabButton(2, 'Transfers', Icons.swap_horiz),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    final active = _tab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _tab = index);
          if (index == 1) _loadSummary();
          if (index == 2) _loadTransfers();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? kRailwayBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? Colors.white : kTextSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: kRailwayBannerGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.stationName != null ? 'Station: ${widget.stationName}' : 'Contractual rule engine',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statChip('${_result.count} items', Icons.list_alt),
              _statChip('Effective: ${_fmtPct(_result.totalWeightage)}', Icons.percent),
              _statChip('Allocated: ${_fmtPct(_totalAllocated)}', Icons.tune),
            ],
          ),
          if ((_result.count > 0) && (_tab == 0))
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  TextButton.icon(
                    onPressed: _addNewItem,
                    icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                    label: const Text('New item', style: TextStyle(color: Colors.white)),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ─── Items tab ─────────────────────────────────────────────────────────────
  Widget _itemsTab() {
    final items = _visibleItems;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 48, color: kNeutralGrey),
              const SizedBox(height: 8),
              Text(
                _result.count == 0
                    ? 'No Annexure-4B items. Tap "Seed 40 items".'
                    : 'No items match your search.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextSecondary),
              ),
              if (_result.count == 0) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _seeding ? null : _promptSeed,
                  icon: const Icon(Icons.playlist_add),
                  label: Text(_seeding ? 'Seeding…' : 'Seed the 40 Annexure-4B items'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _seeding ? null : _promptSeed,
              icon: const Icon(Icons.playlist_add),
              label: Text(_seeding ? 'Seeding…' : 'Seed the 40 Annexure-4B items'),
            ),
          );
        }
        return _itemTile(items[index]);
      },
    );
  }

  Widget _itemTile(AnnexureContractItem item) {
    final isOpen = _expanded.contains(item.uid) || _expanded.contains(item.id);
    final unavailable = item.status == 'NOT_AVAILABLE';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: kDivider)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          final key = item.uid.isNotEmpty ? item.uid : item.id;
          isOpen ? _expanded.remove(key) : _expanded.add(key);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kRailwayBlue, borderRadius: BorderRadius.circular(6)),
                    child: Text('${item.itemNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.contractualDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: unavailable ? TextDecoration.lineThrough : null,
                            color: unavailable ? kNeutralGrey : kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _chip('W: ${_fmtPct(item.contractualWeightage)}', kRailwayBlue),
                            if (item.effectiveWeightage != item.contractualWeightage)
                              _chip('Effective: ${_fmtPct(item.effectiveWeightage)}', kWarningOrange),
                            _chip('Alloc: ${_fmtPct(item.allocatedWeightage)}', kSuccessGreen),
                            if (item.remainingWeightage > 0)
                              _chip('Rem: ${_fmtPct(item.remainingWeightage)}', kNeutralGrey),
                            _chip(item.frequency, kTextSecondary),
                            if (unavailable)
                              _chip('NOT AVAILABLE → Item 1', kErrorRed),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more, color: kNeutralGrey),
                ],
              ),
              if (isOpen) ...[
                const Divider(height: 16),
                if (item.areas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('No area components configured yet.', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                  ),
                ...item.areas.map((a) => _areaRow(item, a)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: unavailable ? null : () => _addArea(item),
                      icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                      label: const Text('Add Area'),
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    if (!unavailable && item.itemNumber != 1)
                      OutlinedButton.icon(
                        onPressed: () => _markUnavailable(item),
                        icon: const Icon(Icons.link_off, size: 16),
                        label: const Text('Unavailable → Item 1'),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _areaRow(AnnexureContractItem item, AnnexureAreaComponent a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: kDivider)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.areaName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
                Text(
                  [a.areaCode, a.quantity != null ? _qty(a) : a.unit == null ? null : 'As available']
                      .whereType<String>()
                      .join('  •  '),
                  style: const TextStyle(fontSize: 11, color: kTextSecondary),
                ),
                if (a.rate != null)
                  Text('Rate: ${_fmt.format(a.rate)}/${a.unit ?? ''}', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
              ],
            ),
          ),
          _chip('${_fmtPct(a.allocatedWeightage)}', item.effectiveWeightage >= a.allocatedWeightage ? kSuccessGreen : kErrorRed),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _editArea(item, a),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, size: 18, color: a.status == 'INACTIVE' ? kDisabled : kErrorRed),
            onPressed: a.status == 'INACTIVE' ? null : () => _deleteArea(a),
          ),
        ],
      ),
    );
  }

  String _qty(AnnexureAreaComponent a) {
    final n = _pct.format(a.quantity);
    return a.unit != null ? '$n ${a.unit}' : '$n';
  }

  // ─── Deductions tab ────────────────────────────────────────────────────────
  Widget _deductionsTab() {
    final deductions = (_summary.deductionSummary['deductions'] ?? const []) as List;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: kDivider)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Billing period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _dateField(_fromCtrl, 'From')),
                    const SizedBox(width: 10),
                    Expanded(child: _dateField(_toCtrl, 'To')),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _deductionsLoading ? null : _calculate,
                      icon: const Icon(Icons.calculate_outlined, size: 16),
                      label: Text(_deductionsLoading ? 'Calculating…' : 'Calculate deductions'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _finalizing ? null : _finalizeDeductions,
                      icon: const Icon(Icons.lock_outline, size: 16),
                      label: Text(_finalizing ? 'Finalizing…' : 'Finalize (immutable)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_summaryLoading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else ...[
          _summaryCard('Contract',
            '${_summary.contract['contractName'] ?? ''}${(_summary.contract['contractNumber'] as String?)?.isNotEmpty == true ? ' (${_summary.contract['contractNumber']})' : ''}'),
          _summaryCard('Annual contract value', _fmt.format((_summary.contract['annualContractValue'] ?? 0) as num)),
          _summaryCard('Execution summary', _execText(_summary.executionSummary)),
          _summaryCard('Total deduction',
            _fmt.format((_summary.deductionSummary['totalDeduction'] ?? 0) as num), highlight: true),
          if (deductions.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Deduction lines', style: TextStyle(fontWeight: FontWeight.bold)),
            ...deductions.map((d) => _deductionLine(d)),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  String _execText(Map<String, dynamic> e) {
    return '${e['total'] ?? 0} recorded  •  ${e['completed'] ?? 0} completed  •  '
        '${e['notCompleted'] ?? 0} missed  •  ${e['partiallyCompleted'] ?? 0} partial  •  '
        '${e['waived'] ?? 0} waived  •  ${e['notApplicable'] ?? 0} N/A';
  }

  Widget _deductionLine(Map<String, dynamic> d) {
    final amount = (d['deductionAmount'] ?? 0) as num;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: kErrorRed.withOpacity(0.05), border: Border.all(color: kErrorRed.withOpacity(0.2))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Item ${d['itemNumber']}${d['areaName'] != null ? ' — ${d['areaName']}' : ''}: ${d['missedOccurrences'] ?? 0} missed',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(_fmt.format(amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kErrorRed)),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: highlight ? kWarningOrange.withOpacity(0.08) : kSurface,
        border: Border.all(color: highlight ? kWarningOrange.withOpacity(0.4) : kDivider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: highlight ? kWarningOrange : kTextPrimary))),
        ],
      ),
    );
  }

  Widget _dateField(TextEditingController ctrl, String label) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(ctrl.text) ?? DateTime.now(),
          firstDate: DateTime(2023),
          lastDate: DateTime(2030),
        );
        if (d != null) setState(() => ctrl.text = _ymd(d));
      },
      child: TextField(
        controller: ctrl,
        readOnly: true,
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 16)),
      ),
    );
  }

  // ─── Transfers tab ─────────────────────────────────────────────────────────
  Widget _transfersTab() {
    if (_transfers.isEmpty) {
      return const Center(child: Text('No weightage transfers recorded.', style: TextStyle(color: kTextSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _transfers.length,
      itemBuilder: (context, i) {
        final t = _transfers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: kDivider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _chip(t.type, t.type == 'NEW_ITEM_ADDED' ? kRailwayBlue : kWarningOrange),
                  const Spacer(),
                  Text(_fmtPct(t.weightage), style: const TextStyle(fontWeight: FontWeight.w700, color: kRailwayBlue)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Item ${t.fromItemNumber} → Item ${t.toItemNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(t.reason, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
              Text(t.createdAt, style: const TextStyle(fontSize: 10, color: kTextSecondary)),
            ],
          ),
        );
      },
    );
  }
}