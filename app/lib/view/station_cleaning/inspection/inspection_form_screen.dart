import 'dart:convert';
import 'dart:io';
import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/inspection_repository.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InspectionFormScreen extends StatefulWidget {
  final StationInspection? inspection;
  final String stationId;
  final String stationName;
  const InspectionFormScreen({super.key, this.inspection, required this.stationId, required this.stationName});

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _inspectorNameCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _defDescCtrl;
  late TextEditingController _defAssignedToCtrl;
  late TextEditingController _closeProofCtrl;

  String _inspectionType = 'schedule';
  DateTime _scheduledDate = DateTime.now();
  String? _selectedDefArea;

  final Map<String, Map<String, String?>> _sectionGrades = {};
  final Map<String, Map<String, TextEditingController>> _sectionRemarks = {};

  bool _uploadingPhoto = false;

  bool get isEdit => widget.inspection != null;
  String get _currentStatus => widget.inspection?.status ?? '';

  @override
  void initState() {
    super.initState();
    final r = widget.inspection;
    _inspectorNameCtrl = TextEditingController(text: r?.inspectorName ?? '');
    _remarksCtrl = TextEditingController(text: r?.remarks ?? '');
    _defDescCtrl = TextEditingController();
    _defAssignedToCtrl = TextEditingController();
    _closeProofCtrl = TextEditingController();
    _scheduledDate = DateTime.tryParse(r?.scheduledDate ?? '') ?? DateTime.now();

    if (r != null) {
      _inspectionType = r.inspectionType;
    }

    for (final entry in sectionConfig.entries) {
      final sectionKey = entry.key;
      final paramKeys = (entry.value['parameters'] as List).cast<String>();
      _sectionGrades[sectionKey] = {};
      _sectionRemarks[sectionKey] = {};
      for (final pk in paramKeys) {
        final savedGrade = r?.sections[sectionKey]?['parameters']?[pk]?['grade'] as String?;
        final savedRemark = r?.sections[sectionKey]?['parameters']?[pk]?['remark'] as String? ?? '';
        _sectionGrades[sectionKey]![pk] = savedGrade;
        _sectionRemarks[sectionKey]![pk] = TextEditingController(text: savedRemark);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (r == null && user?.fullName != null && _inspectorNameCtrl.text.isEmpty) {
        _inspectorNameCtrl.text = user!.fullName!;
      }
    });
  }

  @override
  void dispose() {
    _inspectorNameCtrl.dispose();
    _remarksCtrl.dispose();
    _defDescCtrl.dispose();
    _defAssignedToCtrl.dispose();
    _closeProofCtrl.dispose();
    for (final map in _sectionRemarks.values) {
      for (final ctrl in map.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Map<String, double?> get _sectionAverages {
    final result = <String, double?>{};
    for (final entry in sectionConfig.entries) {
      final sectionKey = entry.key;
      double total = 0;
      int count = 0;
      final grades = _sectionGrades[sectionKey] ?? {};
      for (final grade in grades.values) {
        final score = gradeScores[grade];
        if (score != null) { total += score; count++; }
      }
      result[sectionKey] = count > 0 ? total / count : null;
    }
    return result;
  }

  double? get _overallAverage {
    double total = 0;
    int count = 0;
    for (final entry in sectionConfig.entries) {
      final sectionKey = entry.key;
      final paramKeys = (entry.value['parameters'] as List).cast<String>();
      for (final pk in paramKeys) {
        final grade = _sectionGrades[sectionKey]?[pk];
        final score = gradeScores[grade];
        if (score != null) { total += score; count++; }
      }
    }
    return count > 0 ? total / count : null;
  }

  int? get _overallScore {
    final avg = _overallAverage;
    return avg != null ? (avg * 10).round() : null;
  }

  String? get _overallGrade {
    final avg = _overallAverage;
    return avg != null ? numericToGrade(avg) : null;
  }

  Future<String?> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return null;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final token = await _getToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/evidence/upload/base64'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'image': base64Encode(bytes),
          'fileName': 'deficiency_${DateTime.now().millisecondsSinceEpoch}.jpg',
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] ?? data['imageUrl'] ?? '';
      }
    } catch (_) {}
    setState(() => _uploadingPhoto = false);
    return null;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Map<String, dynamic> _buildSectionsPayload() {
    final sections = <String, dynamic>{};
    for (final entry in sectionConfig.entries) {
      final sectionKey = entry.key;
      final paramKeys = (entry.value['parameters'] as List).cast<String>();
      final params = <String, dynamic>{};
      for (final pk in paramKeys) {
        params[pk] = {
          'grade': _sectionGrades[sectionKey]?[pk],
          'remark': _sectionRemarks[sectionKey]?[pk]?.text ?? '',
        };
      }
      sections[sectionKey] = {'parameters': params};
    }
    return sections;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final formattedDate = "${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}";
      final payload = {
        'stationId': widget.stationId,
        'inspectionType': _inspectionType,
        'scheduledDate': formattedDate,
        'inspectorName': _inspectorNameCtrl.text.trim(),
        'remarks': _remarksCtrl.text.trim(),
      };
      await InspectionRepository.create(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection created'), backgroundColor: kSuccessGreen),
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

  Future<void> _startInspection() async {
    setState(() => _isLoading = true);
    try {
      await InspectionRepository.start(widget.inspection!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection started'), backgroundColor: kSuccessGreen),
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

  Future<void> _submitRatings() async {
    setState(() => _isLoading = true);
    try {
      final sections = _buildSectionsPayload();
      await InspectionRepository.submitRatings(widget.inspection!.uid, {
        'sections': sections,
        'remarks': _remarksCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ratings submitted'), backgroundColor: kSuccessGreen),
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

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      await InspectionRepository.approveInspection(widget.inspection!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection approved'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final rejected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Inspection'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Rejection Reason *', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => reasonCtrl.text.trim().isEmpty ? null : Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (rejected == null || rejected.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await InspectionRepository.rejectInspection(widget.inspection!.uid, rejected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection rejected'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resubmit() async {
    setState(() => _isLoading = true);
    try {
      await InspectionRepository.resubmitInspection(widget.inspection!.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection resubmitted'), backgroundColor: kSuccessGreen),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyDeficiency(Deficiency def) async {
    try {
      await InspectionRepository.verifyDeficiency(widget.inspection!.uid, def.defId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deficiency verified'), backgroundColor: kSuccessGreen),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: kErrorRed),
        );
      }
    }
  }


  void _addDeficiency() {
    _defDescCtrl.clear();
    _defAssignedToCtrl.clear();
    _selectedDefArea = null;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Deficiency'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Area', border: OutlineInputBorder()),
                onChanged: (v) => _selectedDefArea = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _defDescCtrl,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _defAssignedToCtrl,
                decoration: const InputDecoration(labelText: 'Assigned To', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if ((_selectedDefArea == null || _selectedDefArea!.isEmpty) || _defDescCtrl.text.trim().isEmpty) return;
              try {
                await InspectionRepository.addDeficiency(widget.inspection!.uid, {
                  'area': _selectedDefArea,
                  'description': _defDescCtrl.text.trim(),
                  'severity': 'medium',
                  'assignedTo': _defAssignedToCtrl.text.trim(),
                });
                _defDescCtrl.clear();
                _defAssignedToCtrl.clear();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deficiency added'), backgroundColor: kSuccessGreen),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _closeDeficiency(Deficiency def) {
    _closeProofCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Deficiency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _closeProofCtrl,
              decoration: const InputDecoration(labelText: 'Proof Photo URL', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final url = await _pickAndUploadPhoto();
                if (url != null) _closeProofCtrl.text = url;
              },
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Capture Photo'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (_closeProofCtrl.text.trim().isEmpty) return;
              try {
                await InspectionRepository.closeDeficiency(widget.inspection!.uid, def.defId, _closeProofCtrl.text.trim());
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deficiency closed'), backgroundColor: kSuccessGreen),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: kErrorRed),
                  );
                }
              }
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _hasPermission(String permission) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return false;
    final role = (user.role ?? '').toUpperCase().replaceAll(' ', '_');
    const rolePerms = {
      'SUPER_ADMIN': {'MANAGE', 'VIEW', 'APPROVE', 'SCORE'},
      'COMPANY_MASTER': {'MANAGE', 'VIEW', 'APPROVE', 'SCORE'},
      'RAILWAY_MASTER': {'VIEW'},
      'ADMIN': {'MANAGE', 'VIEW', 'APPROVE', 'SCORE'},
      'RAILWAY_ADMIN': {'MANAGE', 'VIEW', 'APPROVE', 'SCORE'},
      'RAILWAY_INSPECTOR': {'MANAGE', 'VIEW', 'APPROVE', 'SCORE'},
      'RAILWAY_SUPERVISOR': {'VIEW', 'SCORE'},
      'CONTRACTOR_MASTER': {'VIEW'},
      'CONTRACTOR_ADMIN': {'VIEW'},
      'CONTRACTOR_SUPERVISOR': {'VIEW'},
      'RAILWAY_WORKER': {'VIEW', 'SCORE'},
      'WORKER': {'VIEW'},
      'JANITOR': {'VIEW'},
      'ATTENDANT': {'VIEW'},
    };
    return (rolePerms[role] ?? <String>{}).contains(permission);
  }

  Widget _buildGradeChip(String? grade) {
    if (grade == null) return Container();
    final display = gradeDisplayNames[grade] ?? grade;
    Color color;
    switch (grade) {
      case 'excellent': color = kSuccessGreen; break;
      case 'very_good': color = Colors.teal; break;
      case 'good': color = Colors.blue; break;
      case 'average': color = kWarningOrange; break;
      case 'poor': color = kErrorRed; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(display, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGradeSelector(String? value, ValueChanged<String?> onChanged) {
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
          onChanged: onChanged,
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

  Widget _buildSectionCard(String sectionKey, bool canScore) {
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
                final hint = paramHints[pk] as String? ?? '';
                final paramDisplay = paramDisplayNames[pk] as String? ?? pk;
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
                        child: canScore
                            ? _buildGradeSelector(grade, (v) {
                                setState(() => _sectionGrades[sectionKey]![pk] = v);
                              })
                            : _buildGradeChip(grade),
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
    final r = widget.inspection;
    final canManage = _hasPermission('MANAGE');
    final canApprove = _hasPermission('APPROVE');
    final canScore = _hasPermission('SCORE');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Inspection Detail' : 'New Inspection', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      DropdownButtonFormField<String>(
                        value: _inspectionType,
                        decoration: const InputDecoration(labelText: 'Inspection Type *', border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'schedule', child: Text('Schedule', style: TextStyle(fontWeight: FontWeight.w500))),
                          DropdownMenuItem(value: 'surprise', child: Text('Surprise', style: TextStyle(fontWeight: FontWeight.w500))),
                        ],
                        onChanged: isEdit ? null : (v) {
                          if (v != null) setState(() => _inspectionType = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: isEdit ? null : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _scheduledDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 7)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _scheduledDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Scheduled Date *', border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            "${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}",
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _inspectorNameCtrl,
                        decoration: const InputDecoration(labelText: 'Inspector Name *', border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        readOnly: isEdit,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarksCtrl,
                        decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 2,
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

              if (r != null && (_currentStatus == 'IN_PROGRESS' || _currentStatus == 'COMPLETED')) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Section-wise Grading', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${sectionConfig.length} sections', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 8),
                ...sectionConfig.keys.map((sk) => _buildSectionCard(sk, canScore && _currentStatus == 'IN_PROGRESS')),
              ],

              if (r != null && _currentStatus != 'IN_PROGRESS' && r.sections.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Grading Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _buildGradeChip(r.overallGrade ?? r.grade),
                  ],
                ),
                const SizedBox(height: 8),
                ...sectionConfig.keys.map((sk) => _buildSectionCard(sk, false)),
              ],

              if (r != null && _currentStatus == 'IN_PROGRESS' && canScore) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_overallAverage == null) ? null : _submitRatings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSuccessGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: Text(_overallAverage == null ? 'Grade all parameters first' : 'Submit Ratings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (r != null && r.deficiencies.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Deficiencies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...r.deficiencies.map((def) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(def.area, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${def.description}\nSeverity: ${def.severity.toUpperCase()}'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (def.closureStatus == DeficiencyStatus.open && canManage)
                          TextButton(
                            onPressed: () => _closeDeficiency(def),
                            child: const Text('Close'),
                          ),
                        if (def.closureStatus == DeficiencyStatus.closed && canApprove)
                          TextButton(
                            onPressed: () => _verifyDeficiency(def),
                            child: const Text('Verify', style: TextStyle(color: Colors.blue)),
                          ),
                        if (def.closureStatus == DeficiencyStatus.railwayVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kSuccessGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: kSuccessGreen),
                            ),
                            child: const Text('VERIFIED', style: TextStyle(color: kSuccessGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                )),
              ],

              if (r != null && (_currentStatus == 'IN_PROGRESS' || _currentStatus == 'COMPLETED') && canManage) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _addDeficiency,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Deficiency'),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (!isEdit && canManage)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(backgroundColor: kRailwayBlue, foregroundColor: Colors.white),
                      child: const Text('Create Inspection'),
                    ),
                  ),
                if (isEdit && _currentStatus == 'SCHEDULED' && canManage)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _startInspection,
                      style: ElevatedButton.styleFrom(backgroundColor: kWarningOrange, foregroundColor: Colors.white),
                      child: const Text('Start Inspection'),
                    ),
                  ),
                if (isEdit && _currentStatus == 'COMPLETED' && canApprove)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _approve,
                              style: ElevatedButton.styleFrom(backgroundColor: kSuccessGreen, foregroundColor: Colors.white),
                              child: const Text('Approve'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _reject,
                              style: ElevatedButton.styleFrom(backgroundColor: kErrorRed, foregroundColor: Colors.white),
                              child: const Text('Reject'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isEdit && _currentStatus == 'REJECTED' && canScore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _resubmit,
                        style: ElevatedButton.styleFrom(backgroundColor: kWarningOrange, foregroundColor: Colors.white),
                        child: const Text('Resubmit Inspection'),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
