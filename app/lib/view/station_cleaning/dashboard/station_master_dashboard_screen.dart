import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/station_cleaning_provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/view/common_railways/widgets/hierarchy_breadcrumb.dart';
import 'package:crm_train/view/station_cleaning/reporting/report_list_screen.dart';

class StationMasterDashboardScreen extends StatefulWidget {
  final String stationId;
  final String stationName;

  const StationMasterDashboardScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<StationMasterDashboardScreen> createState() => _StationMasterDashboardScreenState();
}

class _StationMasterDashboardScreenState extends State<StationMasterDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _dailyReport;
  Map<String, dynamic>? _scoreTrend;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<StationCleaningProvider>();
      final today = DateTime.now().toIso8601String().split('T')[0];
      _dailyReport = await provider.fetchDailyReport(widget.stationId, date: today);
      _scoreTrend = await provider.fetchScoreTrend(widget.stationId);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue, iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          HierarchyBreadcrumb(stationName: widget.stationName),
          Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12), Text(_error!), const SizedBox(height: 8),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : RefreshIndicator(onRefresh: _load, child: _buildContent())),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final dr = _dailyReport;
    final st = _scoreTrend;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (dr != null) ...[
          Card(
            color: kRailwayBlue.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('Today\'s Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kRailwayBlue)),
                const SizedBox(height: 12),
                _gradeCircle(dr['grade'] ?? 'N/A', dr['averageScore'] ?? 0),
                const SizedBox(height: 12),
                Text('Score: ${dr['averageScore'] ?? 0}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _kpiTile('Tasks', '${dr['totalTasks'] ?? 0}', Icons.assignment, Colors.blueGrey)),
            const SizedBox(width: 8),
            Expanded(child: _kpiTile('Completed', '${dr['completedTasks'] ?? 0}', Icons.check_circle, kSuccessGreen)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _kpiTile('Approved', '${dr['approvedTasks'] ?? 0}', Icons.thumb_up, Colors.teal)),
            const SizedBox(width: 8),
            Expanded(child: _kpiTile('Rejected', '${dr['rejectedTasks'] ?? 0}', Icons.cancel, kErrorRed)),
          ]),
          const SizedBox(height: 12),
          const Text('Area Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...(dr['areaBreakdown'] as List? ?? []).map((a) => Card(
            child: ListTile(
              title: Text(a['areaName'] ?? 'Unknown'),
              trailing: Text('Score: ${a['score'] ?? 0}', style: TextStyle(color: _scoreColor(a['score']), fontWeight: FontWeight.bold)),
            ),
          )),
        ],
        if (st != null && st['trend'] != null) ...[
          const SizedBox(height: 16),
          const Text('Score Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _buildTrendChart(st['trend'] as List),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.assessment),
            label: const Text('View Full Reports'),
            onPressed: () {
              final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '';
              Navigator.push(context, MaterialPageRoute(builder: (_) => ReportListScreen(stationId: widget.stationId, stationName: widget.stationName, role: role)));
            },
          ),
        ),
      ],
    );
  }

  Widget _gradeCircle(String grade, dynamic score) {
    final s = (score is int ? score : int.tryParse(score.toString())) ?? 0;
    final color = s >= 90 ? Colors.green : s >= 75 ? Colors.blue : s >= 60 ? Colors.orange : Colors.red;
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2), border: Border.all(color: color, width: 3)),
      child: Center(child: Text(grade, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color))),
    );
  }

  Widget _kpiTile(String label, String value, IconData icon, Color color) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    ));
  }

  Widget _buildTrendChart(List trend) {
    if (trend.isEmpty) return const Center(child: Text('No trend data'));
    final maxScore = 100.0;
    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _TrendChartPainter(trend.cast<Map<String, dynamic>>(), maxScore),
    );
  }

  Color _scoreColor(dynamic score) {
    final s = (score is int ? score : int.tryParse(score.toString())) ?? 0;
    return s >= 80 ? kSuccessGreen : s >= 60 ? kWarningOrange : kErrorRed;
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxScore;
  _TrendChartPainter(this.data, this.maxScore);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..color = kRailwayBlue..strokeWidth = 2..style = PaintingStyle.stroke;
    final fillPaint = Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [kRailwayBlue.withValues(alpha: 0.3), kRailwayBlue.withValues(alpha: 0.0)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final dotPaint = Paint()..color = kRailwayBlue..style = PaintingStyle.fill;

    final stepX = size.width / (data.length - 1);
    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final score = (data[i]['averageScore'] as num?)?.toDouble() ?? 0;
      final y = size.height - (score / maxScore) * size.height * 0.9;
      points.add(Offset(x, y));
    }

    for (int i = 0; i < points.length; i++) {
      if (i == 0) { path.moveTo(points[i].dx, points[i].dy); fillPath.moveTo(points[i].dx, size.height); fillPath.lineTo(points[i].dx, points[i].dy); }
      else { path.lineTo(points[i].dx, points[i].dy); fillPath.lineTo(points[i].dx, points[i].dy); }
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
    for (final p in points) { canvas.drawCircle(p, 3, dotPaint); }

    for (int i = 0; i < data.length; i++) {
      final tp = TextPainter(text: TextSpan(text: data[i]['label']?.toString().substring(5) ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 10)), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
