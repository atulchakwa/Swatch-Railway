import 'package:crm_train/model/station_cleaning_models.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/repositories/inspection_repository.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'inspection_form_screen.dart';

class InspectionListScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  const InspectionListScreen({super.key, required this.stationId, required this.stationName});

  @override
  State<InspectionListScreen> createState() => _InspectionListScreenState();
}

class _InspectionListScreenState extends State<InspectionListScreen> {
  bool _isLoading = false;
  String _selectedStatus = 'all';
  String? _selectedType;
  DateTime _selectedDate = DateTime.now();
  List<StationInspection> _inspections = [];

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  Future<void> _loadInspections() async {
    setState(() => _isLoading = true);
    try {
      final formattedDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final query = {
        'stationId': widget.stationId,
        'date': formattedDate,
        if (_selectedStatus != 'all') 'status': _selectedStatus,
        if (_selectedType != null) 'inspectionType': _selectedType!,
      };
      final list = await InspectionRepository.list(query);
      setState(() => _inspections = list);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load inspections: $e'), backgroundColor: kErrorRed),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SCHEDULED': return Colors.grey;
      case 'IN_PROGRESS': return Colors.blue;
      case 'COMPLETED': return Colors.teal;
      case 'APPROVED': return kSuccessGreen;
      case 'REJECTED': return kErrorRed;
      case 'RESUBMITTED': return kWarningOrange;
      default: return Colors.grey;
    }
  }

  Color _gradeColor(String? grade) {
    switch (grade) {
      case 'excellent': return kSuccessGreen;
      case 'very_good': return Colors.teal;
      case 'good': return Colors.blue;
      case 'average': return kWarningOrange;
      case 'poor': return kErrorRed;
      default: return Colors.grey;
    }
  }

  bool _canManage() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return false;
    final r = (user.role ?? '').toUpperCase().replaceAll(' ', '_');
    return ['SUPER_ADMIN', 'ADMIN', 'COMPANY_MASTER', 'RAILWAY_ADMIN', 'RAILWAY_INSPECTOR'].contains(r);
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManage();

    return Scaffold(
      appBar: AppBar(
        title: Text('Inspections - ${widget.stationName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInspections),
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
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Status')),
                            DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                            DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                            DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                            DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedStatus = val);
                              _loadInspections();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedType,
                          hint: const Text('Type', style: TextStyle(fontSize: 13)),
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All Types')),
                            DropdownMenuItem(value: 'schedule', child: Text('Schedule')),
                            DropdownMenuItem(value: 'surprise', child: Text('Surprise')),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedType = val);
                            _loadInspections();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: kRailwayBlue),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 90)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            _loadInspections();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _inspections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('No inspections found', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInspections,
                        child: ListView.builder(
                          itemCount: _inspections.length,
                          itemBuilder: (context, idx) {
                            final insp = _inspections[idx];
                            final grade = insp.overallGrade ?? insp.grade;
                            final gradeDisplay = gradeDisplayNames[grade] ?? '';
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InspectionFormScreen(
                                        inspection: insp,
                                        stationId: widget.stationId,
                                        stationName: widget.stationName,
                                      ),
                                    ),
                                  ).then((_) => _loadInspections());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              insp.inspectionType.toUpperCase(),
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _statusColor(insp.status).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: _statusColor(insp.status)),
                                            ),
                                            child: Text(
                                              insp.status,
                                              style: TextStyle(color: _statusColor(insp.status), fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const Spacer(),
                                          if (grade != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _gradeColor(grade).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: _gradeColor(grade)),
                                              ),
                                              child: Text(
                                                gradeDisplay,
                                                style: TextStyle(color: _gradeColor(grade), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(insp.inspectorName, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                          const SizedBox(width: 16),
                                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(insp.scheduledDate, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                        ],
                                      ),
                                      if (insp.deficiencies.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.warning_amber, size: 14, color: kWarningOrange),
                                            const SizedBox(width: 4),
                                            Text('${insp.deficiencies.length} deficiency(ies)', style: TextStyle(fontSize: 11, color: kWarningOrange)),
                                            if (insp.deficiencies.any((d) => d.closureStatus == DeficiencyStatus.closed)) ...[
                                              const SizedBox(width: 8),
                                              Text('Need verification', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                                            ],
                                          ],
                                        ),
                                      ],
                                      if (insp.overallScore != null) ...[
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (insp.overallScore! / 100).clamp(0, 1),
                                            backgroundColor: Colors.grey.shade200,
                                            color: _gradeColor(grade),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ],
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
      floatingActionButton: canManage
          ? FloatingActionButton(
              backgroundColor: kRailwayBlue,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InspectionFormScreen(
                      stationId: widget.stationId,
                      stationName: widget.stationName,
                    ),
                  ),
                ).then((_) => _loadInspections());
              },
            )
          : null,
    );
  }
}
