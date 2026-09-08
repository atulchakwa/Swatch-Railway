import 'package:crm_train/model/passenger_feedback_model.dart';
import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/repositories/passenger_feedback_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'passenger_feedback_form_screen.dart';

class PassengerFeedbackListScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const PassengerFeedbackListScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<PassengerFeedbackListScreen> createState() => _PassengerFeedbackListScreenState();
}

class _PassengerFeedbackListScreenState extends State<PassengerFeedbackListScreen> {
  final _pnrCtrl = TextEditingController();
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  List<PassengerFeedback> _feedbacks = [];
  PassengerFeedbackSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSummary();
  }

  @override
  void dispose() {
    _pnrCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final formattedDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final query = {
        'stationId': widget.stationId,
        'date': formattedDate,
        if (_pnrCtrl.text.trim().isNotEmpty) 'pnr': _pnrCtrl.text.trim(),
      };
      final list = await PassengerFeedbackRepository.list(query);
      setState(() => _feedbacks = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load feedback: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await PassengerFeedbackRepository.getSummary(widget.stationId);
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      // Summary is optional; ignore load failures (e.g. missing permissions).
    }
  }

  Color _ratingColor(double r) {
    if (r >= 8) return kSuccessGreen;
    if (r >= 6) return kWarningOrange;
    return kErrorRed;
  }

  Color _statusColor(String status) {
    if (status == 'CANCELLED') return kErrorRed;
    return kSuccessGreen;
  }

  void _openForm([PassengerFeedback? feedback]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerFeedbackFormScreen(
          feedback: feedback,
          stationId: widget.stationId,
          stationName: widget.stationName,
        ),
      ),
    ).then((changed) {
      if (changed == true) {
        _load();
        _loadSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Passenger Feedback - ${widget.stationName}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            _load();
            _loadSummary();
          }),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pnrCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Search PNR',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => _load(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: kRailwayBlue),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            _load();
                          }
                        },
                      ),
                    ],
                  ),
                  if (_summary != null) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryTile('Total', _summary!.totalFeedback.toString(), Icons.feedback, kRailwayBlue),
                        _summaryTile('Avg', _summary!.averageRating.toStringAsFixed(1), Icons.star, kWarningOrange),
                        _summaryTile('Negative', _summary!.negativeCount.toString(), Icons.thumb_down, kErrorRed),
                        _summaryTile('Unique PNR', _summary!.uniquePnrCount.toString(), Icons.confirmation_number, Colors.teal),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _feedbacks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('No feedback found for this date', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _feedbacks.length,
                          itemBuilder: (context, idx) {
                            final fb = _feedbacks[idx];
                            final rating = fb.overallScore; // or gradeScore avg
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _openForm(fb),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: kRailwayBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: kRailwayBlue.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              fb.pnr,
                                              style: const TextStyle(color: kRailwayBlue, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _ratingColor(rating).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: _ratingColor(rating)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star, size: 14),
                                                const SizedBox(width: 2),
                                                Text('${rating.toStringAsFixed(1)}/10',
                                                    style: TextStyle(color: _ratingColor(rating), fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _statusColor(fb.status).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: _statusColor(fb.status)),
                                            ),
                                            child: Text(
                                              fb.status,
                                              style: TextStyle(color: _statusColor(fb.status), fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.confirmation_number, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('PNR', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.rate_review, size: 14, color: kWarningOrange),
                                          const SizedBox(width: 4),
                                          Text('${fb.ratings.length} rated',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          const Spacer(),
                                          Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(fb.takenByName, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      ),
                                      if (fb.overallGrade.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text('Grade: ${gradeDisplayNames[fb.overallGrade] ?? fb.overallGrade}',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _ratingColor(rating))),
                                      ],
                                      if (fb.ratings.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: fb.ratings.entries.take(6).map((e) {
                                            final grade = e.value;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${paramDisplayNames[e.key] ?? e.key}: ${gradeDisplayNames[grade] ?? grade}',
                                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                      if (fb.comments.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(fb.comments, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(fb.date, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                                          const Spacer(),
                                          if (fb.createdAt.isNotEmpty)
                                            Text(fb.createdAt.substring(0, 10),
                                                style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kRailwayBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _openForm(),
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
      ],
    );
  }
}