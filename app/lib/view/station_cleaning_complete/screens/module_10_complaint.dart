import 'package:flutter/material.dart';
import 'package:crm_train/utills/app_colors.dart';

class CreateComplaintScreen extends StatelessWidget {
  final String stationId;
  final String stationName;
  const CreateComplaintScreen({super.key, required this.stationId, required this.stationName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CREATE COMPLAINT', style: TextStyle(color: Colors.white)), backgroundColor: kRailwayBlue, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COMPLAINT DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField(value: 'Toilet Cleanliness', decoration: const InputDecoration(labelText: 'Category', isDense: true), items: ['Toilet Cleanliness', 'Platform Cleanliness', 'Garbage', 'Smell', 'Water', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField(value: 'Bhopal Junction', decoration: const InputDecoration(labelText: 'Station', isDense: true), items: ['Bhopal Junction'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {})),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField(value: 'PF-1', decoration: const InputDecoration(labelText: 'Platform', isDense: true), items: ['PF-1', 'PF-2'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {})),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField(value: 'Toilet Block', decoration: const InputDecoration(labelText: 'Area', isDense: true), items: ['Toilet Block', 'Surface', 'Waiting Hall'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
            const SizedBox(height: 8),
            DropdownButtonFormField(value: 'High', decoration: const InputDecoration(labelText: 'Severity', isDense: true), items: ['Low', 'Medium', 'High', 'Critical'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: e == 'High' || e == 'Critical' ? kErrorRed : null)))).toList(), onChanged: (_) {}),
          ]))),
          const SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: 'Description', hintText: 'Describe the complaint in detail...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 4),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt, size: 18), label: const Text('Take Photo', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.photo_library, size: 18), label: const Text('Gallery', style: TextStyle(fontSize: 12))),
            const Spacer(),
            const Chip(label: Text('2 photos', style: TextStyle(fontSize: 11))),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TARGET CLOSURE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Target Closure', isDense: true), initialValue: '15-01-2024 05:00 PM')),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: kWarningOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Text('SLA: 2 hours', style: TextStyle(fontSize: 11, color: kWarningOrange))),
            ]),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ASSIGN TO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField(value: 'Rajesh Sharma', decoration: const InputDecoration(labelText: 'Supervisor', isDense: true), items: ['Rajesh Sharma', 'Suresh Singh'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
            const SizedBox(height: 8),
            DropdownButtonFormField(value: 'Suresh Patel', decoration: const InputDecoration(labelText: 'Worker', isDense: true), items: ['Suresh Patel', 'Amit Kumar'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
          ]))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.send), label: const Text('SUBMIT COMPLAINT'))),
        ]),
      ),
    );
  }
}

class ComplaintTrackingScreen extends StatelessWidget {
  final String stationId;
  final String stationName;
  final String complaintId;
  const ComplaintTrackingScreen({super.key, required this.stationId, required this.stationName, this.complaintId = 'CMP-2024-001'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('COMPLAINT TRACKING', style: TextStyle(color: Colors.white)), backgroundColor: kRailwayBlue, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kWarningOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: kWarningOrange)), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Complaint #: $complaintId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Text('Severity: HIGH  |  SLA: 2 hours', style: TextStyle(fontSize: 12)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: kWarningOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Text('IN PROGRESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kWarningOrange))),
          ])),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COMPLAINT DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Category: Toilet Cleanliness', style: TextStyle(fontSize: 12)),
            const Text('Location: Bhopal Junction > PF-1 > Toilet Block', style: TextStyle(fontSize: 12)),
            const Text('Reported: 15-01-2024 03:00 PM', style: TextStyle(fontSize: 12)),
            const Text('Assigned: Suresh Patel', style: TextStyle(fontSize: 12)),
            const Text('Target: 15-01-2024 05:00 PM', style: TextStyle(fontSize: 12)),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ACTION TAKEN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('Cleaned toilet, refilled soap, deodorized. Photos uploaded as proof.', style: TextStyle(fontSize: 12))),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            const Icon(Icons.photo_library, color: kRailwayBlue),
            const SizedBox(width: 8),
            const Text('Closure Proof (3 photos)', style: TextStyle(fontSize: 12)),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('View Photos', style: TextStyle(fontSize: 12))),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RAILWAY REVIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.check, size: 18), label: const Text('Accept', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.close, size: 18), label: const Text('Reject', style: TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(foregroundColor: kErrorRed)),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.replay, size: 18), label: const Text('Reopen', style: TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.send, size: 18), label: const Text('Resubmit', style: TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 8),
            TextField(decoration: InputDecoration(labelText: 'Remarks', hintText: 'Add review remarks...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true), maxLines: 2, controller: TextEditingController(text: 'Good work, maintain same standard.')),
          ]))),
          const SizedBox(height: 12),
          Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('STATUS HISTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _historyItem('03:00 PM', '✅ Reported'),
            _historyItem('03:10 PM', '📤 Assigned to Suresh Patel'),
            _historyItem('03:45 PM', '🔄 In Progress'),
            _historyItem('04:30 PM', '✅ Resolved - Awaiting Review'),
          ]))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.check_circle), label: const Text('CLOSE COMPLAINT'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.forward), label: const Text('Forward to Railways'))),
          ]),
        ]),
      ),
    );
  }

  Widget _historyItem(String time, String event) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Container(width: 80, child: Text(time, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey))),
      Text(event, style: const TextStyle(fontSize: 12)),
    ]));
  }
}
