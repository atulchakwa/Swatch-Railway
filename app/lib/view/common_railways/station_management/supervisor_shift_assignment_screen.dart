import 'package:flutter/material.dart';
import 'package:crm_train/model/area_cleaning_models.dart';
import 'package:crm_train/repositories/area_cleaning_repository.dart';
import 'package:crm_train/utills/app_colors.dart';

const List<String> _shiftOptions = ['morning', 'evening', 'night'];

String _shiftLabel(String shift) {
  switch (shift) {
    case 'evening':
      return 'Evening';
    case 'night':
      return 'Night';
    case 'morning':
    default:
      return 'Morning';
  }
}

Color _shiftColor(String? shift) {
  switch (shift) {
    case 'evening':
      return kWarningOrange;
    case 'night':
      return kErrorRed;
    case 'morning':
    default:
      return kSuccessGreen;
  }
}

String _shiftWindow(String shift) {
  switch (shift) {
    case 'evening':
      return '12:00 – 19:59';
    case 'night':
      return '20:00 – 03:59';
    case 'morning':
    default:
      return '04:00 – 11:59';
  }
}

class SupervisorShiftAssignmentScreen extends StatefulWidget {
  final String stationId;
  final String stationName;

  const SupervisorShiftAssignmentScreen({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<SupervisorShiftAssignmentScreen> createState() => _SupervisorShiftAssignmentScreenState();
}

class _SupervisorShiftAssignmentScreenState extends State<SupervisorShiftAssignmentScreen> {
  bool _isLoading = true;
  bool _hasContract = true;

  List<SupervisorShift> _supervisors = [];
  final Map<String, String> _pendingShift = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final supervisors = await AreaCleaningRepository.getSupervisorShifts(stationId: widget.stationId);
      if (!mounted) return;
      setState(() {
        _supervisors = supervisors;
        _hasContract = true;
        _pendingShift.clear();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasContract = false;
      });
    }
  }

  Future<void> _applyShift(SupervisorShift sup, String shift) async {
    final previous = sup.shift;
    setState(() {
      _supervisors = _supervisors.map((s) {
        if (s.uid == sup.uid) {
          return SupervisorShift(
            uid: s.uid,
            fullName: s.fullName,
            email: s.email,
            mobile: s.mobile,
            shift: shift,
          );
        }
        return s;
      }).toList();
      _pendingShift.remove(sup.uid);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assigning ${_shiftLabel(shift)} to ${sup.fullName.isEmpty ? 'supervisor' : sup.fullName}...')),
    );
    try {
      await AreaCleaningRepository.assignSupervisorShift(
        supervisorId: sup.uid,
        shift: shift,
        stationId: widget.stationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${sup.fullName.isEmpty ? 'Supervisor' : sup.fullName} → ${_shiftLabel(shift)} saved'),
        backgroundColor: kSuccessGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _supervisors = _supervisors.map((s) {
          if (s.uid == sup.uid) {
            return SupervisorShift(
              uid: s.uid,
              fullName: s.fullName,
              email: s.email,
              mobile: s.mobile,
              shift: previous,
            );
          }
          return s;
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save shift: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: kErrorRed,
      ));
    }
  }

  List<SupervisorShift> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _supervisors;
    return _supervisors.where((s) {
      final name = s.fullName.toLowerCase();
      final email = s.email.toLowerCase();
      return name.contains(q) || email.contains(q) || s.mobile.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Shifts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kRailwayBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasContract) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 56, color: kWarningOrange),
              const SizedBox(height: 12),
              const Text(
                'No station-cleaning contract linked to this station.\nShift assignment is only available for station-cleaning contracts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_supervisors.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No contractor supervisors found for this station'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Refresh')),
          ],
        ),
      );
    }
    final filtered = _filtered;
    return Column(
      children: [
        _buildLegend(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by name, email or mobile',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Choose the shift for each supervisor — it is saved and reused by task auto-generation until changed.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No supervisor matches your search'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _buildSupervisorRow(filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Card(
      margin: const EdgeInsets.all(12),
      color: kRailwayBlue.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shift windows', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendChip(Icons.wb_sunny, 'Morning', '04:00 – 11:59', kSuccessGreen),
                _legendChip(Icons.wb_twilight, 'Evening', '12:00 – 19:59', kWarningOrange),
                _legendChip(Icons.nights_stay, 'Night', '20:00 – 03:59', kErrorRed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(IconData icon, String label, String window, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(window, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildSupervisorRow(SupervisorShift sup) {
    final effective = sup.shift ?? 'morning';
    final isPending = _pendingShift.containsKey(sup.uid);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: kRailwayBlue.withValues(alpha: 0.12),
              child: const Icon(Icons.person, color: kRailwayBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sup.fullName.isEmpty ? 'Unnamed supervisor' : sup.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sup.mobile.isNotEmpty)
                    Text(sup.mobile, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _shiftColor(sup.shift).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          sup.shift == null ? 'Morning (default)' : _shiftLabel(sup.shift!),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _shiftColor(sup.shift)),
                        ),
                      ),
                      if (isPending)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: isPending ? _pendingShift[sup.uid] : effective,
              underline: const SizedBox(),
              iconEnabledColor: kRailwayBlue,
              style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
              items: _shiftOptions.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: _shiftColor(s)),
                      const SizedBox(width: 6),
                      Text('${_shiftLabel(s)} · ${_shiftWindow(s)}'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (s) {
                if (s == null || (s == sup.shift)) return;
                setState(() => _pendingShift[sup.uid] = s);
                _applyShift(sup, s);
              },
            ),
          ],
        ),
      ),
    );
  }
}