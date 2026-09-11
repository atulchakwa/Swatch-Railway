import 'package:crm_train/model/contracts_model.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/model/billing_models.dart';
import 'package:flutter/material.dart';

class ContractBillingConfigScreen extends StatefulWidget {
  const ContractBillingConfigScreen({super.key});

  @override
  State<ContractBillingConfigScreen> createState() => _ContractBillingConfigScreenState();
}

class _ContractBillingConfigScreenState extends State<ContractBillingConfigScreen> {
  List<ContractBillingRule> configs = [];
  List<ContractModel> contracts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { isLoading = true; });
    try {
      final results = await Future.wait([
        ApiService.getAllBillingConfigs(),
        ApiService.getActiveContracts(),
      ]);
      if (mounted) {
        setState(() {
          configs = results[0] as List<ContractBillingRule>;
          contracts = results[1] as List<ContractModel>;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; });
    }
  }

  ContractBillingRule? _findConfig(String contractId) {
    try {
      return configs.firstWhere((c) => c.contractId == contractId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showConfigDialog(), tooltip: 'Add New Configuration'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh'),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Contract Billing Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Configure billing rules and penalties for each contract', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                ...configs.map((c) => _buildContractCard(c)),
                if (configs.isEmpty)
                  Center(child: Column(children: [
                    const SizedBox(height: 40),
                    Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No billing configurations yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: () => _showConfigDialog(), child: const Text('Add Configuration')),
                  ])),
              ],
            ),
    );
  }

  Widget _buildContractCard(ContractBillingRule config) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: kRailwayBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.receipt_long, color: kRailwayBlue),
        ),
        title: Text(config.contractNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${config.entityName} • ₹${_formatAmount(config.contractValue)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Division', config.division),
                _infoRow('Billing Cycle', config.billingCycle),
                _infoRow('Status', config.status),
                const Divider(),
                const Text('Score Weightages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                _weightageBar('Coach Cleaning', config.coachWeightage, Colors.blue),
                _weightageBar('Premise Cleaning', config.premiseWeightage, Colors.green),
                _weightageBar('Passenger Feedback', config.passengerFeedbackWeightage, Colors.purple),
                _weightageBar('AI Verification', config.aiVerificationWeightage, Colors.teal),
                const Divider(),
                const Text('Performance Deduction Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                _penaltyRule('Score ≥ 90', '${config.penaltyScore90Plus}%'),
                _penaltyRule('Score 80 - 89', '${config.penaltyScore80To89}%'),
                _penaltyRule('Score 70 - 79', '${config.penaltyScore70To79}%'),
                _penaltyRule('Score < 70', '${config.penaltyScoreBelow70}%'),
                const Divider(),
                const Text('Additional Penalties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                _penaltyRule('Manpower Shortage', '₹${config.manpowerShortagePenalty.toInt()}'),
                _penaltyRule('Machine Shortage', '₹${config.machineShortagePenalty.toInt()}'),
                _penaltyRule('Late Task Completion', '₹${config.lateTaskCompletionPenalty.toInt()}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showConfigDialog(existing: config),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _generateBill(config),
                        icon: const Icon(Icons.calculate, size: 16),
                        label: const Text('Generate Bill'),
                        style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateBill(ContractBillingRule config) async {
    final now = DateTime.now();
    try {
await ApiService.generateBill(
         contractId: config.contractId,
         month: now.month,
         year: now.year,
         overallScore: 85,
         scoreBreakdown: {'Coach': 88, 'Premise': 82, 'Feedback': 90, 'AI': 92},
        machineShortageCount: 0,
        manpowerShortageCount: 0,
        missedObhsCount: 0,
        otherPenalties: 0,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill generated'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showConfigDialog({ContractBillingRule? existing}) {
    final contractIdCtrl = TextEditingController(text: existing?.contractId ?? '');
    final contractNumCtrl = TextEditingController(text: existing?.contractNumber ?? '');
    final entityNameCtrl = TextEditingController(text: existing?.entityName ?? '');
    final divCtrl = TextEditingController(text: existing?.division ?? '');
    final zoneCtrl = TextEditingController(text: existing?.zone ?? '');
    final valCtrl = TextEditingController(text: existing?.contractValue.toString() ?? '');
final coachWtCtrl = TextEditingController(text: existing?.coachWeightage.toString() ?? '35');
     final premiseWtCtrl = TextEditingController(text: existing?.premiseWeightage.toString() ?? '35');
    final fbWtCtrl = TextEditingController(text: existing?.passengerFeedbackWeightage.toString() ?? '10');
    final aiWtCtrl = TextEditingController(text: existing?.aiVerificationWeightage.toString() ?? '5');
    final p90Ctrl = TextEditingController(text: existing?.penaltyScore90Plus.toString() ?? '0');
    final p89Ctrl = TextEditingController(text: existing?.penaltyScore80To89.toString() ?? '2');
    final p79Ctrl = TextEditingController(text: existing?.penaltyScore70To79.toString() ?? '5');
    final p70Ctrl = TextEditingController(text: existing?.penaltyScoreBelow70.toString() ?? '10');
final mpCtrl = TextEditingController(text: existing?.manpowerShortagePenalty.toString() ?? '500');
     final mcCtrl = TextEditingController(text: existing?.machineShortagePenalty.toString() ?? '1000');
     final ltCtrl = TextEditingController(text: existing?.lateTaskCompletionPenalty.toString() ?? '500');
    final ncCtrl = TextEditingController(text: existing?.nonCompliancePenalty.toString() ?? '1000');

    String? selectedContractId = existing?.contractId;
    String? selectedContractNum = existing?.contractNumber;
    String? selectedEntityId = existing?.entityId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Billing Rules' : 'New Billing Configuration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Active Contract', border: OutlineInputBorder()),
                    items: contracts.map((c) => DropdownMenuItem(value: c.uid, child: Text('${c.contractNumber} - ${c.contractName ?? ""}'))).toList(),
                    onChanged: (v) {
                      final c = contracts.firstWhere((c) => c.uid == v);
                      setDialogState(() {
                        selectedContractId = v;
                        selectedContractNum = c.contractNumber;
                        selectedEntityId = c.entityId;
                        contractIdCtrl.text = v!;
                        contractNumCtrl.text = c.contractNumber ?? '';
                        entityNameCtrl.text = c.entityName ?? c.contractName ?? '';
                        divCtrl.text = c.division ?? '';
                        zoneCtrl.text = c.zone ?? '';
                        valCtrl.text = '';
                      });
                    },
                  ),
                const SizedBox(height: 12),
                TextFormField(controller: contractNumCtrl, decoration: const InputDecoration(labelText: 'Contract Number', border: OutlineInputBorder(), isDense: true), enabled: existing != null),
                const SizedBox(height: 8),
                TextFormField(controller: entityNameCtrl, decoration: const InputDecoration(labelText: 'Entity Name', border: OutlineInputBorder(), isDense: true), enabled: existing != null),
                const SizedBox(height: 8),
                TextFormField(controller: divCtrl, decoration: const InputDecoration(labelText: 'Division', border: OutlineInputBorder(), isDense: true), enabled: existing != null),
                const SizedBox(height: 8),
                TextFormField(controller: valCtrl, decoration: const InputDecoration(labelText: 'Contract Value (₹)', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                const Text('Score Weightages', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(controller: coachWtCtrl, decoration: const InputDecoration(labelText: 'Coach Weightage (%)', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
const SizedBox(height: 8),
                 TextFormField(controller: premiseWtCtrl, decoration: const InputDecoration(labelText: 'Premise Weightage (%)', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                const Text('Performance Deduction (%)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(controller: p90Ctrl, decoration: const InputDecoration(labelText: 'Score ≥ 90 Deduction %', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextFormField(controller: p89Ctrl, decoration: const InputDecoration(labelText: 'Score 80-89 Deduction %', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextFormField(controller: p79Ctrl, decoration: const InputDecoration(labelText: 'Score 70-79 Deduction %', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextFormField(controller: p70Ctrl, decoration: const InputDecoration(labelText: 'Score < 70 Deduction %', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                const Text('Additional Penalties (₹)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(controller: mpCtrl, decoration: const InputDecoration(labelText: 'Manpower Shortage (₹)', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
const SizedBox(height: 8),
                 TextFormField(controller: mcCtrl, decoration: const InputDecoration(labelText: 'Machine Shortage (₹)', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
                 const SizedBox(height: 8),
                 TextFormField(controller: ltCtrl, decoration: const InputDecoration(labelText: 'Late Task Completion (₹)', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number),
               ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedContractId == null && existing == null) return;
                Navigator.pop(ctx);
                try {
                  await ApiService.saveBillingConfig(
                    contractId: existing?.contractId ?? selectedContractId!,
                    contractNumber: contractNumCtrl.text,
                    entityId: existing?.entityId ?? selectedEntityId ?? '',
                    entityName: entityNameCtrl.text,
                    division: divCtrl.text,
                    zone: zoneCtrl.text,
                    contractValue: double.tryParse(valCtrl.text) ?? 0,
                    billingCycle: 'Monthly',
                    serviceTypes: [],
coachWeightage: double.tryParse(coachWtCtrl.text) ?? 35,
                     premiseWeightage: double.tryParse(premiseWtCtrl.text) ?? 35,
                     passengerFeedbackWeightage: double.tryParse(fbWtCtrl.text) ?? 10,
                    aiVerificationWeightage: double.tryParse(aiWtCtrl.text) ?? 5,
                    penaltyScore90Plus: double.tryParse(p90Ctrl.text) ?? 0,
                    penaltyScore80To89: double.tryParse(p89Ctrl.text) ?? 2,
                    penaltyScore70To79: double.tryParse(p79Ctrl.text) ?? 5,
                    penaltyScoreBelow70: double.tryParse(p70Ctrl.text) ?? 10,
manpowerShortagePenalty: double.tryParse(mpCtrl.text) ?? 500,
                     machineShortagePenalty: double.tryParse(mcCtrl.text) ?? 1000,
                     lateTaskCompletionPenalty: double.tryParse(ltCtrl.text) ?? 500,
                    nonCompliancePenalty: double.tryParse(ncCtrl.text) ?? 1000,
                  );
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration saved'), backgroundColor: Colors.green));
                  _loadData();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Save Configuration'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ],
    ));
  }

  Widget _weightageBar(String label, double pct, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(
      children: [
        SizedBox(width: 130, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct / 100, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8))),
        const SizedBox(width: 8),
        SizedBox(width: 35, child: Text('${pct.toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
      ],
    ));
  }

  Widget _penaltyRule(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(
      children: [
        Icon(Icons.circle, size: 6, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
      ],
    ));
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(2)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}