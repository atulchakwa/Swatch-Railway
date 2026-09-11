import 'package:flutter/material.dart';
import 'package:crm_train/utills/app_colors.dart';

class ScorecardScreen extends StatelessWidget {
  final String stationId;
  final String stationName;
  const ScorecardScreen({super.key, required this.stationId, required this.stationName});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SCORECARD', style: TextStyle(color: Colors.white)),
          backgroundColor: kRailwayBlue,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [Tab(text: 'Daily'), Tab(text: 'Monthly')],
          ),
        ),
        body: TabBarView(
          children: [
            _DailyScorecard(stationId: stationId, stationName: stationName),
            _MonthlyScorecard(stationId: stationId, stationName: stationName),
          ],
        ),
      ),
    );
  }
}

class _DailyScorecard extends StatelessWidget {
  final String stationId;
  final String stationName;
  const _DailyScorecard({required this.stationId, required this.stationName});

  @override
  Widget build(BuildContext context) {
    final areas = <Map<String, Object>>[
      {'area': 'PF-1 Toilet', 'score': '95%', 'grade': 'A', 'status': 'Excellent', 'color': Colors.green},
      {'area': 'PF-1 Surface', 'score': '88%', 'grade': 'B', 'status': 'Good', 'color': Colors.green},
      {'area': 'PF-2 Toilet', 'score': '82%', 'grade': 'B', 'status': 'Good', 'color': Colors.green},
      {'area': 'Waiting Hall', 'score': '75%', 'grade': 'C', 'status': 'Needs Attention', 'color': kWarningOrange},
      {'area': 'Station Toilet', 'score': '80%', 'grade': 'B', 'status': 'Good', 'color': Colors.green},
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bhopal Junction - Daily Scorecard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Text('Inspector: Rajesh Sharma  |  Date: 15-01-2024  |  Shift: Morning', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]))),
        const SizedBox(height: 12),
        Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AREA-WISE SCORES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Table(columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(0.8), 2: FlexColumnWidth(0.5), 3: FlexColumnWidth(1), 4: FlexColumnWidth(1.5)}, children: [
            const TableRow(children: [Text('Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))]),
            ...areas.map((a) => TableRow(children: [
              Text(a['area']!, style: const TextStyle(fontSize: 11)),
              Text(a['score']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: a['color'])),
              Text(a['grade']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Row(children: [Icon(a['color'] == Colors.green ? Icons.check_circle : Icons.warning, size: 14, color: a['color']), Text(a['status']!, style: TextStyle(fontSize: 11, color: a['color']))]),
              Text(a['color'] == Colors.green ? 'Excellent' : 'Needs Attention', style: const TextStyle(fontSize: 11)),
            ])),
          ]),
        ]))),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kRailwayBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Row(children: [
          Icon(Icons.assessment, color: kRailwayBlue, size: 32),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('OVERALL STATION SCORE: 84%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kRailwayBlue)),
            Text('Grade: B', style: TextStyle(fontSize: 14, color: kRailwayBlue)),
          ]),
        ])),
        const SizedBox(height: 12),
        Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('INSPECTOR REMARKS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('Overall cleanliness is good. Waiting Hall needs attention. Consumables in PF-1 Toilet need refilling.', style: TextStyle(fontSize: 12))),
        ]))),
        const SizedBox(height: 12),
        Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CERTIFICATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          const ListTile(dense: true, leading: Icon(Icons.verified, color: Colors.green), title: Text('Certified By: Rajesh Sharma (Railway Supervisor)', style: TextStyle(fontSize: 12)), subtitle: Text('Certification Date: 15-01-2024 10:30 AM', style: TextStyle(fontSize: 11))),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit, size: 16), label: const Text('Digital Signature', style: TextStyle(fontSize: 12))),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.verified), label: const Text('CERTIFY'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.forward), label: const Text('Forward to Commercial'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('Download PDF'))),
        ]),
      ]),
    );
  }
}

class _MonthlyScorecard extends StatelessWidget {
  final String stationId;
  final String stationName;
  const _MonthlyScorecard({required this.stationId, required this.stationName});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bhopal Junction - Monthly Scorecard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Text('Month: January 2024', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          _mStat('Days', '31', kRailwayBlue),
          _mStat('Avg Score', '82%', Colors.green),
          _mStat('Grade', 'B', Colors.teal),
          _mStat('Best', '95%', Colors.green),
          _mStat('Worst', '65%', kErrorRed),
        ]),
        const SizedBox(height: 12),
        Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DAILY SCORE TREND', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(height: 100, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _mBar('W1', 0.95, Colors.green),
            _mBar('W2', 0.88, Colors.green),
            _mBar('W3', 0.85, kRailwayBlue),
            _mBar('W4', 0.82, kWarningOrange),
          ])),
        ]))),
        const SizedBox(height: 12),
        Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AREA PERFORMANCE (Monthly)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Table(columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(0.5), 3: FlexColumnWidth(0.8)}, children: [
            const TableRow(children: [Text('Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Avg Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text('Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))]),
            _mAreaRow('PF-1 Toilet', '92%', 'A', '📈'),
            _mAreaRow('PF-1 Surface', '85%', 'B', '📈'),
            _mAreaRow('PF-2 Toilet', '80%', 'B', '📉'),
            _mAreaRow('Waiting Hall', '70%', 'C', '📉'),
          ]),
        ]))),
        const SizedBox(height: 12),
        Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CERTIFICATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField(value: 'Select Authority', decoration: const InputDecoration(labelText: 'Certified By', isDense: true), items: ['Select Authority', 'Railway Supervisor'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
          const SizedBox(height: 8),
          TextFormField(decoration: const InputDecoration(labelText: 'Date', isDense: true), initialValue: '31-01-2024'),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit, size: 16), label: const Text('Digital Signature', style: TextStyle(fontSize: 12))),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.verified), label: const Text('CERTIFY'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.forward), label: const Text('Forward'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('PDF'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.email), label: const Text('Send'))),
        ]),
      ]),
    );
  }

  Widget _mStat(String label, String value, Color color) {
    return Expanded(child: Container(margin: const EdgeInsets.all(2), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Column(children: [Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)), Text(label, style: TextStyle(fontSize: 10, color: color))])));
  }

  Widget _mBar(String label, double pct, Color color) {
    return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${(pct * 100).toInt()}%', style: const TextStyle(fontSize: 9)), Container(height: 80 * pct, width: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), Text(label, style: const TextStyle(fontSize: 9))]));
  }

  TableRow _mAreaRow(String area, String score, String grade, String trend) {
    return TableRow(children: [Text(area, style: const TextStyle(fontSize: 11)), Text(score, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: score.contains('9') || score.contains('8') ? Colors.green : kWarningOrange)), Text(grade, style: const TextStyle(fontSize: 11)), Text(trend, style: const TextStyle(fontSize: 13))]);
  }
}
