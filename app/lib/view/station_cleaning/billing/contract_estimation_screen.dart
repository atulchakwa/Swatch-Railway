import 'package:crm_train/model/estimation_models.dart';
import 'package:crm_train/repositories/estimation_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class ContractEstimationScreen extends StatefulWidget {
  final String contractId;
  final String stationId;
  final String stationName;
  const ContractEstimationScreen({
    super.key,
    required this.contractId,
    this.stationId = '',
    this.stationName = '',
  });

  @override
  State<ContractEstimationScreen> createState() => _ContractEstimationScreenState();
}

class _ContractEstimationScreenState extends State<ContractEstimationScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  EstimateSummary? _estimate;
  VariationSet? _variations;
  SwoSet? _swos;
  AmendedValue? _amended;
  PeriodContribution? _contribution;

  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      final estimate = await EstimationRepository.getEstimate(widget.contractId, stationId: widget.stationId);
      final variations = await EstimationRepository.getVariations(widget.contractId);
      final swos = await EstimationRepository.getSwos(widget.contractId);
      final amended = await EstimationRepository.getAmended(widget.contractId);
      final contribution = await EstimationRepository.getPeriodContribution(
        widget.contractId,
        stationId: widget.stationId,
        month: _month,
        year: _year,
      );
      if (!mounted) return;
      setState(() {
        _estimate = estimate;
        _variations = variations;
        _swos = swos;
        _amended = amended;
        _contribution = contribution;
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contracts & Estimation'),
          backgroundColor: kRailwayBlue,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            tabs: [
              Tab(text: 'Items'),
              Tab(text: 'Period'),
              Tab(text: 'Variations'),
              Tab(text: 'SWOs'),
              Tab(text: 'Amended'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: TabBarView(
                  children: [
                    _itemsTab(),
                    _periodTab(),
                    _variationsTab(),
                    _swosTab(),
                    _amendedTab(),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── Items ───────────────────────────────────────────────────────────────
  Widget _itemsTab() {
    final e = _estimate;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_status.isNotEmpty) _statusText(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimated Items', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (e != null) ...[
                  Text('Total estimated value: ₹${e.totalEstimatedCost.toStringAsFixed(2)} (${e.count} items)', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  if (e.categoryTotals.isNotEmpty)
                    for (final entry in e.categoryTotals.entries)
                      Text('  • ${entry.key}: ₹${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final it in e?.items ?? <EstimateItem>[])
          Card(
            child: ListTile(
              dense: true,
              title: Text('${it.itemNo == 0 ? '' : '#${it.itemNo} '}${it.description}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${it.category} · ${it.quantity.toStringAsFixed(0)} ${it.unit} · ${it.rate.toStringAsFixed(3)}/unit\n${it.startDate} → ${it.endDate}${it.nsRef.isNotEmpty ? ' · NS:${it.nsRef}' : ''}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹${it.estimatedCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editItem(it)),
                ],
              ),
            ),
          ),
        if ((e?.items ?? []).isEmpty)
          const Text('No active estimate items for this contract.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add),
          label: const Text('Add Estimate Item'),
        ),
      ],
    );
  }

  Future<void> _addItem() => _itemDialog();

  Future<void> _editItem(EstimateItem it) => _itemDialog(existing: it);

  Future<void> _itemDialog({EstimateItem? existing}) async {
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? 'cleaning');
    final areaCtrl = TextEditingController(text: existing?.quantity == 0 ? '' : existing!.quantity.toString());
    final rateCtrl = TextEditingController(text: existing?.rate == 0 ? '' : existing!.rate.toString());
    final startCtrl = TextEditingController(text: existing?.startDate ?? '');
    final endCtrl = TextEditingController(text: existing?.endDate ?? '');
    final nsCtrl = TextEditingController(text: existing?.nsRef ?? '');
    final timesCtrl = TextEditingController(
      text: existing == null
          ? '1'
          : ((existing.frequency['timesPerDay'] ?? existing.frequency['timesPerWeek'] ?? existing.frequency['timesPerMonth'] ?? 1)).toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Estimate Item' : 'Update Estimate Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(descCtrl, 'Description *'),
              _field(catCtrl, 'Category (cleaning/pest_control/system) *'),
              _field(areaCtrl, 'Area / quantity (sq.ft. or units) *'),
              _field(rateCtrl, 'Rate per unit per visit (₹) *'),
              _field(timesCtrl, 'Times per day / week / month'),
              _field(startCtrl, 'Start date (YYYY-MM-DD)'),
              _field(endCtrl, 'End date (YYYY-MM-DD)'),
              _field(nsCtrl, 'NS reference / additional item ref'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final payload = <String, dynamic>{
        'description': descCtrl.text.trim(),
        'category': catCtrl.text.trim(),
        'quantity': double.tryParse(areaCtrl.text) ?? 0,
        'rate': double.tryParse(rateCtrl.text) ?? 0,
        'frequency': {'type': 'daily', 'timesPerDay': int.tryParse(timesCtrl.text) ?? 1},
        if (startCtrl.text.trim().isNotEmpty) 'startDate': startCtrl.text.trim(),
        if (endCtrl.text.trim().isNotEmpty) 'endDate': endCtrl.text.trim(),
        if (nsCtrl.text.trim().isNotEmpty) 'nsRef': nsCtrl.text.trim(),
        if (existing != null && widget.stationId.isNotEmpty) 'stationId': widget.stationId,
        if (widget.stationName.isNotEmpty) 'stationName': widget.stationName,
      };
      if (existing == null) {
        await EstimationRepository.createItem(widget.contractId, payload);
      } else {
        await EstimationRepository.updateItem(existing.uid, payload);
      }
      _status = 'Estimate item saved.';
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    }
  }

  // ─── Period contribution ─────────────────────────────────────────────────
  Widget _periodTab() {
    final c = _contribution;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
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
                      icon: const Icon(Icons.chevron_right, size: 20),
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
                if (c != null) ...[
                  Text(
                    'Period: ${c.periodStart?.toString().split(' ').first ?? ''} → ${c.periodEnd?.toString().split(' ').first ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text('Contract contribution: ₹${c.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (c != null)
          for (final r in c.rows)
            Card(
              child: ListTile(
                dense: true,
                title: Text('${r['description'] ?? ''}${r['isAdditional'] == true ? ' (additional)' : ''}', style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${r['category'] ?? ''} · ${r['periodDays'] ?? 0} days @ ₹${(r['costPerDay'] ?? 0).toStringAsFixed(2)}/day${(r['nsRef'] ?? '').toString().isNotEmpty ? ' · NS:${r['nsRef']}' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text('₹${(r['amount'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        if (c == null || (c.rows.isEmpty && c.total == 0))
          const Text('No estimate items active in this period.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ─── Variations ──────────────────────────────────────────────────────────
  Widget _variationsTab() {
    final v = _variations;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_status.isNotEmpty) _statusText(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Variation Statements (${v?.count ?? 0})', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Text('amended = original − savings + additional work + excess − recovery', style: TextStyle(fontSize: 11, color: Colors.grey)),
                if (v?.latest != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Latest rev #${v!.latest!.revisionNo}: amended ₹${v.latest!.amendedContractValue.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final rev in v?.revisions ?? <VariationRevision>[])
          Card(
            child: ListTile(
              dense: true,
              title: Text('Rev #${rev.revisionNo} — ${rev.description.isNotEmpty ? rev.description : 'Variation'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${rev.effectiveDate}\noriginal ${rev.originalContractValue.toStringAsFixed(0)} → revised ${rev.revisedScopeValue.toStringAsFixed(0)} · savings ₹${rev.reductionValue.toStringAsFixed(2)} · +₹${rev.additionalWorkValue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: true,
              trailing: Text('₹${rev.amendedContractValue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        if ((v?.revisions ?? []).isEmpty)
          const Text('No variation statements yet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addVariation,
          icon: const Icon(Icons.add),
          label: const Text('Create Variation Revision'),
        ),
      ],
    );
  }

  Future<void> _addVariation() async {
    final descCtrl = TextEditingController();
    final reductionCtrl = TextEditingController();
    final additionalCtrl = TextEditingController();
    final excessCtrl = TextEditingController();
    final recoveryCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Variation Revision'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(descCtrl, 'Description'),
              _field(reductionCtrl, 'Reduction in scope (₹)'),
              _field(additionalCtrl, 'Additional work (₹)'),
              _field(excessCtrl, 'Excess execution (₹)'),
              _field(recoveryCtrl, 'Recovery deductions (₹)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      setState(() => _loading = true);
      await EstimationRepository.createVariation(widget.contractId, {
        'description': descCtrl.text.trim(),
        'reductionValue': double.tryParse(reductionCtrl.text) ?? 0,
        'additionalWorkValue': double.tryParse(additionalCtrl.text) ?? 0,
        'excessExecutionValue': double.tryParse(excessCtrl.text) ?? 0,
        'recoveryDeductions': double.tryParse(recoveryCtrl.text) ?? 0,
      });
      _status = 'Variation created.';
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    }
  }

  // ─── SWOs ────────────────────────────────────────────────────────────────
  Widget _swosTab() {
    final s = _swos;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_status.isNotEmpty) _statusText(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Supplementary Work Orders (${s?.count ?? 0})', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (s != null)
                  Text('Total SWO value: ₹${s.totalSwoValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final w in s?.swos ?? <Swo>[])
          Card(
            child: ListTile(
              dense: true,
              title: Text('SWO ${w.swoNumber}${w.description.isNotEmpty ? ' — ${w.description}' : ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${w.startDate} → ${w.endDate} (${w.contractDays}d) · ${w.items.length} items',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹${w.totalValue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: kErrorRed),
                    onPressed: () => _deleteSwo(w.uid),
                  ),
                ],
              ),
            ),
          ),
        if ((s?.swos ?? []).isEmpty)
          const Text('No SWOs yet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addSwo,
          icon: const Icon(Icons.add),
          label: const Text('Create SWO'),
        ),
      ],
    );
  }

  Future<void> _addSwo() async {
    final noCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final lineCtrl = TextEditingController(text: 'Cleaning work');
    final qtyCtrl = TextEditingController();
    final rateCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create SWO'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(noCtrl, 'SWO number * (unique for contract)'),
              _field(descCtrl, 'Description'),
              _field(lineCtrl, 'Line item description'),
              _field(qtyCtrl, 'Quantity'),
              _field(rateCtrl, 'Rate (₹)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      setState(() => _loading = true);
      await EstimationRepository.createSwo(widget.contractId, {
        'swoNumber': noCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'items': [
          {
            'description': lineCtrl.text.trim(),
            'quantity': double.tryParse(qtyCtrl.text) ?? 0,
            'rate': double.tryParse(rateCtrl.text) ?? 0,
          }
        ],
      });
      _status = 'SWO created.';
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    }
  }

  Future<void> _deleteSwo(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete SWO'),
        content: const Text('Backend status will be soft-deleted. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await EstimationRepository.deleteSwo(uid);
      _status = 'SWO deleted.';
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    }
  }

  // ─── Amended ─────────────────────────────────────────────────────────────
  Widget _amendedTab() {
    final a = _amended;
    if (a == null) return const Center(child: Text('No data', style: TextStyle(color: Colors.grey)));
    final t = a.trace ?? const <String, dynamic>{};
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amended Contract Value', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _kv('Original contract value', '₹${a.contractValue.toStringAsFixed(2)}'),
                _kv('Latest variation (rev #${a.latestRevision?['revisionNo'] ?? '—'})', '₹${(t['variations'] ?? 0).toStringAsFixed(2)}'),
                _kv('Total SWO value', '₹${a.totalSwoValue.toStringAsFixed(2)}'),
                _kv('Amended contract value', '₹${a.amendedContractValue.toStringAsFixed(2)}', emphasize: true),
                if (a.estimateValue > 0) _kv('Current estimate vs contract', '₹${a.estimateValue.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String label, String value, {bool emphasize = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: emphasize ? kRailwayBlue : Colors.black, fontWeight: emphasize ? FontWeight.w700 : FontWeight.normal)),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        ),
      );

  Widget _statusText() => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(_status, style: const TextStyle(fontSize: 12, color: kErrorRed)),
      );
}