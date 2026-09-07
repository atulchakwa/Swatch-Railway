import 'package:flutter/material.dart';
import 'package:crm_train/model/material_model.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/material_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:provider/provider.dart';
import 'material_form_screen.dart';

class MaterialListScreen extends StatefulWidget {
  final String? stationId;
  final String? stationName;
  const MaterialListScreen({super.key, this.stationId, this.stationName});

  @override
  State<MaterialListScreen> createState() => _MaterialListScreenState();
}

class _MaterialListScreenState extends State<MaterialListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<MaterialItem> _all = [];
  List<MaterialItem> _filtered = [];
  List<StockAlert> _alerts = [];
  List<MaterialTransaction> _logs = [];

  bool _isLoading = true;
  String? _error;
  String _query = '';

  String get _stationId {
    if (widget.stationId != null && widget.stationId!.isNotEmpty) return widget.stationId!;
    final user = context.read<AuthProvider>().currentUser;
    if (user?.stationId != null && user!.stationId!.isNotEmpty) return user.stationId!;
    if (user?.stations.isNotEmpty == true) return user!.stations.first;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        if (_tabCtrl.index == 1 && _alerts.isEmpty) _loadAlerts();
        if (_tabCtrl.index == 2 && _logs.isEmpty) _loadLogs();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _all = await MaterialRepository.getAll(stationId: _stationId);
      _applyFilter();
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        _error = 'AUTH_ERROR';
      } else {
        _error = e.toString();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAlerts() async {
    try {
      _alerts = await MaterialRepository.getAlerts(stationId: _stationId);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    try {
      _logs = await MaterialRepository.getLogs(stationId: _stationId);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all.where((m) {
        if (_query.isEmpty) return true;
        final q = _query.toLowerCase();
        return m.materialName.toLowerCase().contains(q) ||
            m.materialType.toLowerCase().contains(q);
      }).toList();
    });
  }

  Widget _buildMaterialList() {
    if (_filtered.isEmpty) return const Center(child: Text('No materials found'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filtered.length,
      itemBuilder: (context, i) {
        final m = _filtered[i];
        final lowStock = m.reorderLevel > 0 && m.currentStock <= m.reorderLevel;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(m.materialName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                    if (lowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: kErrorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Text('LOW STOCK', style: TextStyle(color: kErrorRed, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${m.materialType} | ${m.unit}', style: const TextStyle(color: kTextSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoChip('Stock', m.currentStock.toString(), kRailwayBlue),
                    const SizedBox(width: 8),
                    _infoChip('Reorder', m.reorderLevel.toString(), kWarningOrange),
                    if (m.unitPrice > 0) ...[const SizedBox(width: 8), _infoChip('₹/unit', m.unitPrice.toStringAsFixed(0), kSuccessGreen)],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (m.monthlyRequirement > 0) _infoChip('Monthly Req.', m.monthlyRequirement.toString(), Colors.teal),
                    if (m.monthlyRequirement > 0) const SizedBox(width: 8),
                    if (m.issuedQuantity > 0) _infoChip('Issued', m.issuedQuantity.toString(), Colors.indigo),
                    if (m.issuedQuantity > 0) const SizedBox(width: 8),
                    if (m.usedQuantity > 0) _infoChip('Used', m.usedQuantity.toString(), Colors.purple),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.outbox, size: 18),
                      label: const Text('Issue'),
                      onPressed: () => _showTransactionDialog(m, 'issue'),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      icon: const Icon(Icons.inbox, size: 18),
                      label: const Text('Receive'),
                      onPressed: () => _showTransactionDialog(m, 'receive'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                      onPressed: () async {
                        final r = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => MaterialFormScreen(existing: m, stationId: _stationId)),
                        );
                        if (r == true) _load();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: kErrorRed),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Material'),
                            content: Text('Delete "${m.materialName}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: kErrorRed),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && m.uid != null) {
                          try {
                            await MaterialRepository.delete(m.uid!);
                            _load();
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Material deleted'), backgroundColor: kSuccessGreen),
                            );
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $value', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  void _showTransactionDialog(MaterialItem material, String type) {
    final qtyCtrl = TextEditingController();
    final toCtrl = TextEditingController(text: type == 'issue' ? '' : 'Supplier');
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'issue' ? 'Issue ${material.materialName}' : 'Receive ${material.materialName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${material.currentStock} ${material.unit}'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity *',
                border: const OutlineInputBorder(),
                suffixText: material.unit,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: toCtrl,
              decoration: InputDecoration(
                labelText: type == 'issue' ? 'Issued To *' : 'Received From *',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (qtyCtrl.text.isEmpty || toCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final body = {'quantity': double.tryParse(qtyCtrl.text) ?? 0, 'remarks': remarkCtrl.text};
                if (type == 'issue') {
                  body['issuedTo'] = toCtrl.text.trim();
                  await MaterialRepository.issue(material.uid!, body);
                } else {
                  body['receivedFrom'] = toCtrl.text.trim();
                  await MaterialRepository.receive(material.uid!, body);
                }
                _load();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(type == 'issue' ? 'Material issued' : 'Material received'), backgroundColor: kSuccessGreen),
                );
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue),
            child: Text(type == 'issue' ? 'Issue' : 'Receive', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    if (_alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 48, color: kSuccessGreen),
            SizedBox(height: 12),
            Text('No stock alerts', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, i) {
        final a = _alerts[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: kErrorRed, child: Icon(Icons.warning, color: Colors.white)),
            title: Text(a.materialName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Stock: ${a.currentStock} / Reorder: ${a.reorderLevel} ${a.unit}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: kErrorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('Short by ${a.shortage.toStringAsFixed(0)}', style: const TextStyle(color: kErrorRed, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    if (_logs.isEmpty) return const Center(child: Text('No transactions yet'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, i) {
        final l = _logs[i];
        final isIssue = l.transactionType == 'issue';
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIssue ? kWarningOrange.withOpacity(0.1) : kSuccessGreen.withOpacity(0.1),
              child: Icon(isIssue ? Icons.outbox : Icons.inbox, color: isIssue ? kWarningOrange : kSuccessGreen),
            ),
            title: Text('${isIssue ? "Issued" : "Received"}: ${l.materialName}'),
            subtitle: Text('Qty: ${l.quantity} ${l.unit} | ${isIssue ? l.issuedTo ?? "" : l.receivedFrom ?? ""}'),
            trailing: Text(l.createdAt.length >= 10 ? l.createdAt.substring(0, 10) : l.createdAt, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.stationName != null ? 'Materials - ${widget.stationName}' : 'Materials', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Materials'),
            Tab(text: 'Alerts'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error == 'AUTH_ERROR'
              ? const Center(child: Text('Authentication error'))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: kErrorRed),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search materials...',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                onChanged: (v) { _query = v; _applyFilter(); },
                              ),
                            ),
                            Expanded(child: _buildMaterialList()),
                          ],
                        ),
                        _buildAlertsTab(),
                        _buildLogsTab(),
                      ],
                    ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kRailwayBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final r = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => MaterialFormScreen(stationId: _stationId)));
          if (r == true) _load();
        },
      ),
    );
  }
}
