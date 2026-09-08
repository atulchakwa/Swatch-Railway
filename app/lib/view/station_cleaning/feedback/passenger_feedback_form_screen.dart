import 'package:crm_train/model/passenger_feedback_model.dart';
import 'package:crm_train/model/station_feedback_model.dart';
import 'package:crm_train/repositories/passenger_feedback_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';

class PassengerFeedbackFormScreen extends StatefulWidget {
  final PassengerFeedback? feedback;
  final String stationId;
  final String stationName;
  const PassengerFeedbackFormScreen({
    super.key,
    this.feedback,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<PassengerFeedbackFormScreen> createState() => _PassengerFeedbackFormScreenState();
}

class _PassengerFeedbackFormScreenState extends State<PassengerFeedbackFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pnrCtrl = TextEditingController();
  final _passengerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
  final Map<String, int> _ratings = {};
  DateTime? _journeyDate;
  bool _isLoading = false;

  bool get isEdit => widget.feedback != null;
  bool get isCancelled => widget.feedback?.status == 'CANCELLED';

  @override
  void initState() {
    super.initState();
    final r = widget.feedback;
    _pnrCtrl.text = r?.pnr ?? '';
    _passengerNameCtrl.text = r?.passengerName ?? '';
    _phoneCtrl.text = r?.passengerPhone ?? '';
    _commentsCtrl.text = r?.comments ?? '';
    _journeyDate = DateTime.tryParse(r?.journeyDate ?? '');
    if (r != null) _ratings.addAll(r.ratings);
  }

  @override
  void dispose() {
    _pnrCtrl.dispose();
    _passengerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  double? get _overallAverage {
    final values = _ratings.values.toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'stationId': widget.stationId,
      'pnr': _pnrCtrl.text.trim(),
      'passengerName': _passengerNameCtrl.text.trim(),
      'passengerPhone': _phoneCtrl.text.trim(),
      if (_journeyDate != null)
        'journeyDate': "${_journeyDate!.year}-${_journeyDate!.month.toString().padLeft(2, '0')}-${_journeyDate!.day.toString().padLeft(2, '0')}",
      'ratings': _ratings,
      'comments': _commentsCtrl.text.trim(),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ratings.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rate at least 3 categories to submit'), backgroundColor: kWarningOrange),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (isEdit) {
        await PassengerFeedbackRepository.update(widget.feedback!.uid!, _buildPayload());
      } else {
        await PassengerFeedbackRepository.create(_buildPayload());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Feedback'),
        content: const Text('Mark this feedback as cancelled?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes', style: TextStyle(color: kErrorRed))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await PassengerFeedbackRepository.remove(widget.feedback!.uid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback cancelled'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStarRow(String category) {
    final current = _ratings[category] ?? 0;
    return Row(
      children: [
        Expanded(
          child: Text(feedbackCategoryLabel(category), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        ...List.generate(5, (i) {
          final star = i + 1;
          return IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: isCancelled ? null : () => setState(() => _ratings[category] = star),
            icon: Icon(
              star <= current ? Icons.star : Icons.star_border,
              color: kWarningOrange,
              size: 30,
            ),
          );
        }),
      ],
    );
  }

  Color _summaryColor(double? avg) {
    if (avg == null) return Colors.grey;
    if (avg >= 4) return kSuccessGreen;
    if (avg >= 3) return kWarningOrange;
    return kErrorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Passenger Feedback' : 'New Passenger Feedback', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _pnrCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'PNR Number *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.confirmation_number),
                          hintText: 'e.g. 1234567890',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'PNR number is required' : null,
                        readOnly: isCancelled,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passengerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Passenger Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        readOnly: isCancelled,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          counterText: '',
                        ),
                        readOnly: isCancelled,
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: isCancelled
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _journeyDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 30)),
                                );
                                if (picked != null) setState(() => _journeyDate = picked);
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Journey Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _journeyDate == null
                                ? 'Select date'
                                : "${_journeyDate!.year}-${_journeyDate!.month.toString().padLeft(2, '0')}-${_journeyDate!.day.toString().padLeft(2, '0')}",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Cleanliness Ratings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${_ratings.length}/${feedbackCategories.length} rated',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _ratings.length >= 3 ? kSuccessGreen : kWarningOrange)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Rate at least 3 categories', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                      const Divider(height: 16),
                      ...feedbackCategories.map(_buildStarRow),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: kRailwayBlue.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Overall Rating', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(_overallAverage == null ? '-' : _overallAverage!.toStringAsFixed(1),
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _summaryColor(_overallAverage))),
                          ],
                        ),
                      ),
                      ...List.generate(5, (i) {
                        final star = i + 1;
                        return Icon(
                          _overallAverage != null && star <= _overallAverage!.round() ? Icons.star : Icons.star_border,
                          color: kWarningOrange,
                          size: 24,
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commentsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Comments',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 3,
                readOnly: isCancelled,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                    child: Text(isEdit ? 'Update Feedback' : 'Submit Feedback'),
                  ),
                ),
                if (isEdit && !isCancelled) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.cancel_outlined, color: kErrorRed),
                      label: const Text('Cancel Feedback', style: TextStyle(color: kErrorRed)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}