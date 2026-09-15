import 'package:flutter/material.dart';
import 'package:crm_train/utills/app_colors.dart';

class MaterialTrackingScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const MaterialTrackingScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<StatefulWidget> createState() => _MaterialTrackingScreenState();
}

class _MaterialTrackingScreenState extends State<MaterialTrackingScreen> {
  bool _showIssueForm = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MATERIAL TRACKING', style: TextStyle(color: Colors.white)), backgroundColor: kRailwayBlue, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: DropdownButtonFormField(value: 'Bhopal Junction', decoration: const InputDecoration(labelText: 'Station', isDense: true), items: ['Bhopal Junction'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {})),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField(value: 'All', decoration: const InputDecoration(labelText: 'Stock', isDense: true), items: ['All', 'In Stock', 'Low Stock', 'Out of Stock'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {})),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _matStat('Total', '8', kRailwayBlue),
            _matStat('In Stock', '5', Colors.green),
            _matStat('Low Stock', '2', kWarningOrange),
            _matStat('Out Stock', '1', kErrorRed),
            _matStat('Shortage', '2', kErrorRed),
          ]),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MATERIAL LIST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Table(columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(0.8), 2: FlexColumnWidth(0.8), 3: FlexColumnWidth(0.8), 4: FlexColumnWidth(1)}, children: [
              const TableRow(children: [Text('Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Req.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))]),
              _matRow('Floor Cleaner', 'L', '82', '100', '⚠️ Shortage', kWarningOrange),
              _matRow('Toilet Cleaner', 'L', '30', '50', '🔴 Critical', kErrorRed),
              _matRow('Disinfectant', 'L', '20', '30', '⚠️ Shortage', kWarningOrange),
              _matRow('Soap', 'Pcs', '45', '50', '✅ OK', Colors.green),
            ]),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ISSUE CONSUMABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField(value: 'Floor Cleaner', decoration: const InputDecoration(labelText: 'Material', isDense: true), items: ['Floor Cleaner', 'Toilet Cleaner', 'Disinfectant', 'Soap'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Quantity', isDense: true), initialValue: '10')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: DropdownButtonFormField(value: 'Liters', decoration: const InputDecoration(labelText: 'Unit', isDense: true), items: ['Liters', 'Kg', 'Pcs'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {})),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField(value: 'Amit Kumar', decoration: const InputDecoration(labelText: 'Issued To', isDense: true), items: ['Amit Kumar', 'Rohit Sharma', 'Suresh Patel'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
            const SizedBox(height: 8),
            TextField(decoration: InputDecoration(labelText: 'Purpose', hintText: 'Enter purpose...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true), controller: TextEditingController(text: 'Cleaning PF-1 Toilet')),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.check), label: const Text('ISSUE MATERIAL')),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SHORTAGE REMARKS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kErrorRed.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: const Text('Toilet Cleaner shortage. Reorder request submitted.', style: TextStyle(fontSize: 12))),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NON-AVAILABILITY ALERTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kErrorRed)),
            const SizedBox(height: 8),
            ListTile(dense: true, leading: const Icon(Icons.warning, color: kErrorRed), title: const Text('Toilet Cleaner - Critical Shortage', style: TextStyle(fontSize: 12)), subtitle: const Text('Order placed. Expected delivery: 2 days', style: TextStyle(fontSize: 11))),
          ]))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.assessment), label: const Text('Stock Report'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.replay), label: const Text('Reorder'))),
          ]),
        ]),
      ),
    );
  }

  Widget _matStat(String label, String value, Color color) {
    return Expanded(child: Container(margin: const EdgeInsets.all(2), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Column(children: [Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)), Text(label, style: TextStyle(fontSize: 10, color: color))])));
  }

  TableRow _matRow(String name, String unit, String balance, String req, String status, Color color) {
    return TableRow(children: [Text(name, style: const TextStyle(fontSize: 11)), Text(unit, style: const TextStyle(fontSize: 11)), Text(balance, style: const TextStyle(fontSize: 11)), Text(req, style: const TextStyle(fontSize: 11)), Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))]);
  }
}
