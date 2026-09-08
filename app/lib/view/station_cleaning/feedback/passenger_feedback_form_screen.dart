import 'package:crm_train/model/passenger_feedback_model.dart';
import 'package:crm_train/model/station_cleaning_models.dart';
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
  final Map<String, String> _grades = {};
  DateTime? _journeyDate;
  bool _isLoading = false;

  bool get isEdit => widget.feedback != null;
  bool get isCancelled => widget.feedback?.status == 'CANCELLED';

  int get _totalParams => sectionConfig.values.fold<int>(0, (sum, s) => sum + (s['parameters'] as List).length);

  @override
  void initState() {
    super.initState();
    final r = widget.feedback;
    _pnrCtrl.text = r?.pnr ?? '';
    _passengerNameCtrl.text = r?.passengerName ?? '';
    _phoneCtrl.text = r?.passengerPhone ?? '';
    _commentsCtrl.text = r?.comments ?? '';
    _journeyDate = DateTime.tryParse(r?.journeyDate ?? '');
    if (r != null) _grades.addAll(r.ratings);
  }

  @override
  void dispose() {
    _pnrCtrl.dispose();
    _passengerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  double? get _overallScore {
    final scores = _grades.values.map((g) => gradeScores[g]).whereType<int>().toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  String get _overallGrade {
    final score = _overallScore;
    if (score == null) return '';
    return numericToGrade(score);
  }

  double? _sectionAvg(String sectionKey) {
    final params = (sectionConfig[sectionKey]!['parameters'] as List).cast<String>();
    final scores = params.map((p) => _grades[p]).map((g) => gradeScores[g]).whereType<int>().toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'stationId': widget.stationId,
      'pnr': _pnrCtrl.text.trim(),
      'passengerName': _passengerNameCtrl.text.trim(),
      'passengerPhone': _phoneCtrl.text.trim(),
      if (_journeyDate != null)
        'journeyDate': "${_journeyDate!.year}-${_journeyDate!.month.toString().padLeft(2, '0')}-${_journeyDate!.day.toString().padLeft(2, '0')}",
      'ratings': _grades,
      'comments': _commentsCtrl.text.trim(),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_grades.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rate at least 3 parameters to submit'), backgroundColor: kWarningOrange),
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

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'excellent':
      case 'very_good':
        return kSuccessGreen;
      case 'good':
      case 'average':
        return kWarningOrange;
      default:
        return kErrorRed;
    }
  }

  Color _scoreColor(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 8) return kSuccessGreen;
    if (score >= 6) return kWarningOrange;
    return kErrorRed;
  }

  IconData _sectionIcon(String sectionKey) {
    switch (sectionKey) {
      case 'stairs':
        return Icons.view_agenda;
      case 'wallCladdings':
        return Icons.dashboard;
      case 'steelWorks':
        return Icons.hardware;
      case 'glassWorks':
        return Icons.window;
      case 'escalators':
        return Icons.upgrade;
      case 'toilets':
        return Icons.wc;
      default:
        return Icons.grid_view;
    }
  }

  Widget _buildParamRow(String sectionKey, String paramKey) {
    final selected = _grades[paramKey];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(paramDisplayNames[paramKey] ?? paramKey,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (selected != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _gradeColor(selected).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _gradeColor(selected)),
                  ),
                  child: Text(gradeDisplayNames[selected] ?? selected,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _gradeColor(selected))),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: gradeLabels.map((g) {
              final isSelected = selected == g;
              return ChoiceChip(
                label: Text(gradeDisplayNames[g] ?? g, style: const TextStyle(fontSize: 11)),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: _gradeColor(g).withValues(alpha: 0.15),
                side: BorderSide(color: isSelected ? _gradeColor(g) : Colors.grey.shade300),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? _gradeColor(g) : Colors.black87,
                ),
                onSelected: isCancelled
                    ? null
                    : (sel) => setState(() {
                          if (sel) {
                            _grades[paramKey] = g;
                          } else {
                            _grades.remove(paramKey);
                          }
                        }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String sectionKey) {
    final config = sectionConfig[sectionKey]!;
    final params = (config['parameters'] as List).cast<String>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: kRailwayBlue.withValues(alpha: 0.12),
                  child: Icon(_sectionIcon(sectionKey), color: kRailwayBlue, size: 16),
                ),
                const SizedBox(width: 8),
                Text(config['displayName'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_sectionAvg(sectionKey) != null)
                  Text('${_sectionAvg(sectionKey)!.toStringAsFixed(1)}/10',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary)),
              ],
            ),
            const Divider(height: 16),
            ...params.map((p) => _buildParamRow(sectionKey, p)),
          ],
        ),
      ),
    );
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
                            const Text('Overall Score', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(_overallScore == null ? '-' : '${_overallScore!.toStringAsFixed(1)}/10',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _scoreColor(_overallScore))),
                            if (_overallGrade.isNotEmpty)
                              Text(gradeDisplayNames[_overallGrade] ?? _overallGrade,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _gradeColor(_overallGrade))),
                          ],
                        ),
                      ),
                      Text('${_grades.length}/$_totalParams rated',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _grades.length >= 3 ? kSuccessGreen : kWarningOrange)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Cleanliness Ratings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Rate at least 3 parameters', style: TextStyle(fontSize: 11, color: kTextSecondary)),
              const SizedBox(height: 8),
              ...sectionConfig.keys.map(_buildSectionCard),
              const SizedBox(height: 8),
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