import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crm_train/providers/auth_provider.dart';
import 'package:crm_train/services/api_services.dart';
import 'package:crm_train/utills/app_colors.dart';
import 'package:crm_train/model/station_models.dart';
import 'attendance/station_supervisor_attendance_screen.dart';
import 'billing/billing_support_pack_screen.dart';
import 'feedback/feedback_qr_screen.dart';
import 'feedback/passenger_feedback_form_screen.dart';
import 'feedback/passenger_feedback_list_screen.dart';
import 'inspection/inspection_list_screen.dart';
import 'reporting/report_list_screen.dart';
import 'supervisor_log/supervisor_daily_log_screen.dart';
import '../common_railways/station_management/area_config_screen.dart';
import '../common_railways/station_management/station_feedback_list_screen.dart';
import '../common_railways/station_management/task_generation_screen.dart';

class StationCleaningHubScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String? contractId;

  const StationCleaningHubScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    this.contractId,
  });

  @override
  State<StationCleaningHubScreen> createState() => _StationCleaningHubScreenState();
}

class _StationCleaningHubScreenState extends State<StationCleaningHubScreen> {
  String _selectedStationId = '';
  String _selectedStationName = '';
  List<Station> _availableStations = [];
  bool _loadingStations = true;

  @override
  void initState() {
    super.initState();
    _selectedStationId = widget.stationId;
    _selectedStationName = widget.stationName;
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _loadingStations = true);
    try {
      final all = await ApiService.getStations();
      setState(() {
        _availableStations = all;
        _loadingStations = false;
      });
    } catch (e) {
      setState(() => _loadingStations = false);
    }
  }

  void _onStationChanged(String? uid) {
    if (uid == null) return;
    final station = _availableStations.firstWhere((s) => s.uid == uid, orElse: () => Station(stationCode: '', stationName: '', zone: '', division: ''));
    setState(() {
      _selectedStationId = uid;
      _selectedStationName = station.stationName;
    });
  }

  bool _canSwitchStation(String role) {
    final r = role.toUpperCase().replaceAll(' ', '_');
    const switchable = {'SUPER_ADMIN', 'ADMIN', 'RAILWAY_ADMIN', 'COMPANY_MASTER', 'RAILWAY_MASTER', 'CONTRACTOR_MASTER'};
    return switchable.contains(r);
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context).currentUser?.role ?? '';

    final cards = <Widget>[
      _moduleCard(context, Icons.assignment, 'Generate\nTask', Colors.deepPurple, () => _openTaskGen(context)),
      _moduleCard(context, Icons.badge, 'Supervisor\nAttendance', kRailwayBlue, () => _openSupervisorAttendance(context)),
      _moduleCard(context, Icons.search, 'Inspection', Colors.indigo, () => _openInspection(context)),
      _moduleCard(context, Icons.assessment, 'Reports', Colors.purple, () => _openReports(context)),
      _moduleCard(context, Icons.receipt, 'Billing', Colors.deepOrange, () => _openBilling(context)),
      _moduleCard(context, Icons.book, 'Daily\nAudit Log', Colors.blue, () => _openDailyLog(context)),
      _moduleCard(context, Icons.map, 'Area\nArrangement', Colors.lightGreen, () => _openAreaConfig(context)),
      _moduleCard(context, Icons.feedback, 'Passenger\nFeedback', Colors.amber.shade700, () => _openFeedback(context)),
    ];

    final titleWidget = _loadingStations
        ? Text(_selectedStationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        : _canSwitchStation(role)
            ? DropdownButton<String>(
                value: _availableStations.any((s) => s.uid == _selectedStationId) ? _selectedStationId : null,
                dropdownColor: kRailwayBlue,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: _availableStations.map((s) => DropdownMenuItem(
                  value: s.uid,
                  child: Text(s.stationName, style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: _onStationChanged,
              )
            : Text(_selectedStationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));

    return Scaffold(
      appBar: AppBar(
        title: titleWidget,
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(12),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
        children: cards,
      ),
    );
  }

  Widget _moduleCard(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), radius: 24, child: Icon(icon, color: color, size: 26)),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _openSupervisorAttendance(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StationSupervisorAttendanceScreen(
      stationId: _selectedStationId,
      stationName: _selectedStationName,
    )));
  }

  void _openBilling(BuildContext context) {
    if (widget.contractId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => BillingSupportPackScreen(contractId: widget.contractId!, stationId: _selectedStationId, stationName: _selectedStationName)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contract linked to this station')));
    }
  }

  void _openReports(BuildContext context) {
    final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role ?? '';
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReportListScreen(stationId: _selectedStationId, stationName: _selectedStationName, role: role)));
  }

  void _openDailyLog(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorDailyLogScreen()));
  }

  void _openInspection(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => InspectionListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openAreaConfig(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AreaConfigScreen()));
  }

  void _openTaskGen(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskGenerationScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
  }

  void _openFeedback(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Feedback Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.edit_note, color: Colors.white)),
              title: const Text('Submit Passenger Feedback'),
              subtitle: const Text('Ask a passenger, record PNR + ratings'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerFeedbackFormScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.list_alt, color: Colors.white)),
              title: const Text('View PNR Feedback'),
              subtitle: const Text('Browse feedback recorded against PNRs'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerFeedbackListScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.qr_code, color: Colors.white)),
              title: const Text('Generate QR Code'),
              subtitle: const Text('Print & display for passenger feedback'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackQrScreen(stationId: _selectedStationId, stationName: _selectedStationName)));
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.list, color: Colors.white)),
              title: const Text('View Feedback'),
              subtitle: const Text('Browse submitted passenger feedback'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => StationFeedbackListScreen(stationId: _selectedStationId)));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}