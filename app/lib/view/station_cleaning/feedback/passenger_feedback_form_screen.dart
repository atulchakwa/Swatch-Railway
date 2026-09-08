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
  final Map<String, Map<String, String?>> _sectionGrades = {};
  DateTime? _journeyDate;
  bool _isLoading = false;

  bool get isEdit => widget.feedback != null;
  bool get isCancelled => widget.feedback?.status == 'CANCELLED';

  int get _ratedCount {
    var count = 0;
    for (final grades in _sectionGrades.values) {
      count += grades.values.where((g) => g != null).length;
    }
    return count;
  }

  Map<String, double?> get _sectionAverages {
    final result = <String, double?>{};
    for (final entry in _sectionGrades.entries) {
      final grades = entry.value.values.whereType<String>().toList();
      final scores = grades.map((g) => gradeScores[g] ?? 0).toList();
      result[entry.key] = scores.isEmpty ? null : (scores.reduce((a, b) => a + b) / scores.length);
    }
    return result;
  }

  double? get _overallAverage {
    final all = <double>[];
    for (final avg in _sectionAverages.values) {
      if (avg != null) all.add(avg);
    }
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a + b) / all.length;
  }

  int? get _overallScore => _overallAverage == null ? null : (_overallAverage! * 10).round();

  String get _overallGrade {
    final avg = _overallAverage;
    if (avg == null) return '';
    return numericToGrade(avg);
  }

  @override
  void initState() {
    super.initState();
    final r = widget.feedback;
    _pnrCtrl.text = r?.pnr ?? '';
    _passengerNameCtrl.text = r?.passengerName ?? '';
    _phoneCtrl.text = r?.passengerPhone ?? '';
    _commentsCtrl.text = r?.comments ?? '';
    _journeyDate = DateTime.tryParse(r?.journeyDate ?? '');
    for (final entry in sectionConfig.entries) {
      final paramKeys = (entry.value['parameters'] as List).cast<String>();
      _sectionGrades[entry.key] = {for (final pk in paramKeys) pk: null};
    }
    if (r != null) {
      r.sections.forEach((sectionKey, sec) {
        if (sec is Map && sec['parameters'] is Map) {
          (sec['parameters'] as Map).forEach((pk, val) {
            if (val is Map && val['grade'] != null) {
              _sectionGrades[sectionKey]?[pk.toString()] = val['grade'].toString();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pnrCtrl.dispose();
    _passengerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildSectionsPayload() {
    final sections = <String, dynamic>{};
    for (final entry in _sectionGrades.entries) {
      final params = <String, dynamic>{};
      entry.value.forEach((pk, grade) {
        if (grade != null) params[pk] = {'grade': grade, 'remark': ''};
      });
      sections[entry.key] = {'parameters': params};
    }
    return sections;
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'stationId': widget.stationId,
      'pnr': _pnrCtrl.text.trim(),
      'passengerName': _passengerNameCtrl.text.trim(),
      'passengerPhone': _phoneCtrl.text.trim(),
      if (_journeyDate != null)
        'journeyDate': "${_journeyDate!.year}-${_journeyDate!.month.toString().padLeft(2, '0')}-${_journeyDate!.day.toString().padLeft(2, '0')}",
      'sections': _buildSectionsPayload(),
      'comments': _commentsCtrl.text.trim(),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ratedCount < 3) {
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

  Widget _buildGradeChip(String? grade) {
    if (grade == null) return Container();
    final display = gradeDisplayNames[grade] ?? grade;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _gradeColor(grade).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gradeColor(grade)),
      ),
      child: Text(display, style: TextStyle(color: _gradeColor(grade), fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGradeSelector(String sectionKey, String paramKey, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: gradeLabels.contains(value) ? value : null,
          hint: const Text('Grade', style: TextStyle(fontSize: 12)),
          isExpanded: false,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: gradeLabels.map((g) => DropdownMenuItem(
            value: g,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: _gradeColor(g)),
                const SizedBox(width: 4),
                Text(gradeDisplayNames[g] ?? g, style: const TextStyle(fontSize: 12)),
              ],
            ),
          )).toList(),
          onChanged: isCancelled ? null : (v) => setState(() => _sectionGrades[sectionKey]![paramKey] = v),
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'excellent': return kSuccessGreen;
      case 'very_good': return Colors.teal;
      case 'good': return Colors.blue;
      case 'average': return kWarningOrange;
      case 'poor': return kErrorRed;
      default: return Colors.grey;
    }
  }

  IconData _sectionIcon(String sectionKey) {
    switch (sectionKey) {
      case 'floor': return Icons.view_in_ar;
      case 'stairs': return Icons.stairs;
      case 'wallCladdings': return Icons.wallpaper;
      case 'steelWorks': return Icons.handyman;
      case 'glassWorks': return Icons.window;
      case 'escalators': return Icons.upgrade;
      case 'toilets': return Icons.wc;
      default: return Icons.checklist;
    }
  }

  Widget _buildSectionCard(String sectionKey) {
    final config = sectionConfig[sectionKey]!;
    final displayName = config['displayName'] as String;
    final paramKeys = (config['parameters'] as List).cast<String>();
    final avg = _sectionAverages[sectionKey];
    final sectionGrade = avg != null ? numericToGrade(avg) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: _gradeColor(sectionGrade ?? 'none').withValues(alpha: 0.15),
          child: Icon(_sectionIcon(sectionKey), size: 20, color: _gradeColor(sectionGrade ?? 'none')),
        ),
        title: Row(
          children: [
            Expanded(child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            _buildGradeChip(sectionGrade),
          ],
        ),
        subtitle: avg != null
            ? Text('Score: ${(avg * 10).round()} / 100', style: TextStyle(fontSize: 11, color: Colors.grey[600]))
            : Text('Not graded', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: paramKeys.map((pk) {
                final grade = _sectionGrades[sectionKey]?[pk];
                final hint = paramHints[pk] ?? '';
                final paramDisplay = paramDisplayNames[pk] ?? pk;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(paramDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            if (hint.isNotEmpty) Text(hint, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildGradeSelector(sectionKey, pk, grade),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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

              if (_overallAverage != null) ...[
                const SizedBox(height: 8),
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
                              const Text('Overall Grade', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(gradeDisplayNames[_overallGrade] ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Score', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${_overallScore ?? '-'} / 100', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kRailwayBlue)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Section-wise Grading', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${sectionConfig.length} sections', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 4),
              Text('Rate at least 3 parameters',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ratedCount >= 3 ? kSuccessGreen : kWarningOrange)),
              const SizedBox(height: 8),
              ...sectionConfig.keys.map(_buildSectionCard),

              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _commentsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Comments',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.comment),
                    ),
                    maxLines: 3,
                    readOnly: isCancelled,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _ratedCount < 3 ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccessGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(_ratedCount < 3 ? 'Rate 3 or more parameters first' : (isEdit ? 'Update Feedback' : 'Submit Feedback')),
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