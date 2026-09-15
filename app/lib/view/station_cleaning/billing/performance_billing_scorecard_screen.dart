import 'package:crm_train/model/performance_billing_models.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class PerformanceBillingScorecardScreen extends StatefulWidget {
  final String contractId;
  final String stationId;
  final String stationName;
  final int? initialMonth;
  final int? initialYear;
  const PerformanceBillingScorecardScreen({super.key, required this.contractId, required this.stationId, required this.stationName, this.initialMonth, this.initialYear});

  @override
  State<PerformanceBillingScorecardScreen> createState() => _PerformanceBillingScorecardScreenState();
}

class _PerformanceBillingScorecardScreenState extends State<PerformanceBillingScorecardScreen> {
  late int _month = widget.initialMonth ?? DateTime.now().month;
  late int _year = widget.initialYear ?? DateTime.now().year;
  bool _loading = true;
  String? _error;
  PerformanceScorecard? _sc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final sc = await ApiService.getPerformanceScorecard(
        contractId: widget.contractId,
        stationId: widget.stationId,
        month: _month,
        year: _year,
      );
      if (!mounted) return;
      setState(() { _sc = sc; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Performance Scorecard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('Month ${i + 1}'))),
                    onChanged: (v) { if (v != null) { setState(() => _month = v); _load(); } },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: List.generate(5, (i) => DateTime.now().year - 1 + i)
                        .map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                    onChanged: (v) { if (v != null) { setState(() => _year = v); _load(); } },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _load,
                    style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                    child: const Text('Go'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.error_outline, size: 48, color: kErrorRed),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kErrorRed)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _load, child: const Text('Retry')),
                        ]),
                      ))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          children: [
                            _buildOverview(),
                            const SizedBox(height: 10),
                            _buildCategories(),
                            const SizedBox(height: 10),
                            _buildValuePipeline(),
                            const SizedBox(height: 10),
                            _buildAmountSummary(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Color _achievementColor(double v) => v >= 80 ? kSuccessGreen : v >= 60 ? kWarningOrange : kErrorRed;

  Widget _buildOverview() {
    final sc = _sc!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sc.contractNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${sc.month}/${sc.year}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${sc.stationName}  •  ${sc.contractorName}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text('Period: ${sc.periodStart}  to  ${sc.periodEnd}  (${sc.applicableDays} days)',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _scoreCircle(sc.overallScore, sc.grade),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ovRow('Rate', '₹${sc.ratePerSqft.toStringAsFixed(2)} / sqft'),
                      _ovRow('Scheduled Work Value', '₹${sc.scheduledWorkValue.round()}'),
                      _ovRow('Gross Work Value', '₹${sc.grossWorkValue.round()}'),
                      _ovRow('Overall Score', '${sc.overallScore.toStringAsFixed(1)} / 100',
                          color: _achievementColor(sc.overallScore)),
                      _ovRow('Less Execution',
                          '${sc.lessExecutionPercent.toStringAsFixed(1)}%  (₹${sc.lessExecutionAmount.round()})',
                          color: kErrorRed),
                      _ovRow('Eligible Amount', '₹${sc.eligibleAmount.round()}', color: kSuccessGreen),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreCircle(double score, String grade) {
    final color = _achievementColor(score);
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 4)),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${score.toStringAsFixed(1)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text('OUT OF 100', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
          Text('Grade $grade', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _ovRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 124, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final sc = _sc!;
    return _sectionCard('Performance Categories (maxMarks = 100)', [
      for (final c in sc.categories)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${c.name}  (${c.maxMarks} marks)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  if (c.notApplicable && c.count == 0)
                    Text('No data in period', style: TextStyle(fontSize: 10, color: Colors.grey[500]))
                  else
                    Text('${c.achievement.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _achievementColor(c.achievement))),
                  const SizedBox(width: 8),
                  Text('→ ${c.marks.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (c.achievement / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.grey[200],
                  color: _achievementColor(c.achievement),
                ),
              ),
              if (c.dataSource == 'execution')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('verified ${c.verified} / ${c.required} executions',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('${c.count} record(s)', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ),
                ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildValuePipeline() {
    final sc = _sc!;
    return _sectionCard('Cleaning Execution — AREA × SQFT × RATE (value-weighted)',
        [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Per execution of an area worth ₹${sc.ratePerSqft.toStringAsFixed(2)} × sqft. '
              'Scheduled value uses all required passes; Actual value uses only verified passes.',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('Area / Size', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 6),
                const SizedBox(width: 40, child: Text('Req', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 6),
                const SizedBox(width: 40, child: Text('Ver', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 6),
                const SizedBox(width: 62, child: Text('Scheduled ₹', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 6),
                const SizedBox(width: 62, child: Text('Actual ₹', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
              ],
            ),
          ),
          for (final r in sc.areaRows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.areaName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                            Text('${r.sqft.round()} sqft  •  ₹${r.rate.toStringAsFixed(2)}/sqft  •  ${r.frequency}',
                                style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(width: 40, child: Text('${r.required}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10))),
                      const SizedBox(width: 6),
                      SizedBox(width: 40, child: Text('${r.verified}', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: r.verified < r.required ? kErrorRed : kSuccessGreen))),
                      const SizedBox(width: 6),
                      SizedBox(width: 62, child: Text('${r.scheduledValue.round()}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10))),
                      const SizedBox(width: 6),
                      SizedBox(width: 62, child: Text('${r.actualValue.round()}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: r.required > 0 ? (r.verified / r.required).clamp(0.0, 1.0) : 0,
                      minHeight: 2,
                      backgroundColor: Colors.grey[200],
                      color: _achievementColor(r.achievement ?? 0),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Scheduled Work Value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('₹${sc.scheduledWorkValue.round()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gross Work Value (verified)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('₹${sc.grossWorkValue.round()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kSuccessGreen)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Execution Achievement', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('${sc.executionAchievement.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _achievementColor(sc.executionAchievement))),
                  ],
                ),
              ],
            ),
          ),
        ]);
  }

  Widget _buildAmountSummary() {
    final sc = _sc!;
    return _sectionCard('Billing Summary', [
      _amtRow('Scheduled Work Value', '₹${sc.scheduledWorkValue.round()}'),
      _amtRow('Less Execution (${sc.lessExecutionPercent.toStringAsFixed(1)}%)', '− ₹${sc.lessExecutionAmount.round()}', color: kErrorRed),
      _amtRow('Gross Work Value (verified)', '₹${sc.grossWorkValue.round()}', color: kSuccessGreen),
      _amtRow('Eligible Amount', '₹${sc.eligibleAmount.round()}', color: kSuccessGreen, bold: true),
      const Padding(
        padding: EdgeInsets.fromLTRB(12, 2, 12, 2),
        child: Text('Eligible = min(Gross Work Value, Scheduled − Less Execution). Penalty is added separately in the bill (per configured penalty slabs).',
            style: TextStyle(fontSize: 10, color: Colors.grey)),
      ),
    ]);
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: kRailwayBlue,
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _amtRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}