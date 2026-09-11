import 'package:crm_train/data/zone_database.dart';
import 'package:crm_train/model/user_model.dart';
import 'package:flutter/material.dart';

class ZoneDivisionDepotDropdowns extends StatefulWidget {
  final UserModel user;
  final Function(String? division, String? depot)? onChanged;
  final Function(String? zone, String? division, String? depot)? onChangedWithZone;
  final String? initialZone;
  final String? initialDivision;
  final String? initialDepot;

  const ZoneDivisionDepotDropdowns({
    super.key,
    required this.user,
    this.onChanged,
    this.onChangedWithZone,
    this.initialZone,
    this.initialDivision,
    this.initialDepot,
  });

  @override
  State<ZoneDivisionDepotDropdowns> createState() =>
      _ZoneDivisionDepotDropdownsState();
}

class _ZoneDivisionDepotDropdownsState
    extends State<ZoneDivisionDepotDropdowns> {
  String? selectedZone;
  String? selectedDivision;
  String? selectedDepot;

  @override
  void initState() {
    super.initState();

    // Initialize based on initial values if provided, otherwise use user's zone, division, depot
    selectedZone = widget.initialZone ?? widget.user.zone;
    selectedDivision = widget.initialDivision ?? widget.user.division;
    selectedDepot = widget.initialDepot ?? widget.user.depot;
  }

  bool _canChangeZone() {
    return widget.user.role == 'SUPER_ADMIN' || widget.user.role == 'Super Admin' || widget.user.role == 'Company Master';
  }

  bool _canChangeDivision() {
    final userRole = widget.user.role;
    final userZone = widget.user.zone;

    // Company Master can always change division
    if (userRole == 'SUPER_ADMIN' || userRole == 'Super Admin' || userRole == 'Company Master') return true;

    // Railway/Contractor Master can change division if they have a zone
    if ((userRole == 'Railway Master' || userRole == 'Contractor Master') && userZone != null) {
      return true;
    }

    return false;
  }

  bool _canChangeDepot() {
    final userRole = widget.user.role;
    final userZone = widget.user.zone;
    final userDivision = widget.user.division;

    // Company Master can always change depot
    if (userRole == 'SUPER_ADMIN' || userRole == 'Super Admin' || userRole == 'Company Master') return true;

    // Railway/Contractor Master can change depot if they have a zone (zone-level access)
    if ((userRole == 'Railway Master' || userRole == 'Contractor Master') && userZone != null) {
      return true;
    }

    // Railway/Contractor Admin can change depot if they have a division (division-level access)
    if ((userRole == 'Railway Admin' || userRole == 'Contractor Admin') && userDivision != null) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final userRole = widget.user.role;

    if (userRole == 'Railway Supervisor' || userRole == 'Contractor Supervisor') {
      return const SizedBox.shrink();
    }

    final zones = DepotDatabase.zoneData.keys.toList();
    final divisions = selectedZone != null
        ? (DepotDatabase.zoneData[selectedZone]?.keys.toList() ?? <String>[])
        : <String>[];
    final depots = selectedZone != null && selectedDivision != null
        ? (DepotDatabase.zoneData[selectedZone]?[selectedDivision] ?? <String>[])
        : <String>[];

    if (selectedZone != null && !zones.contains(selectedZone)) {
      selectedZone = null;
    }
    if (selectedDivision != null && !divisions.contains(selectedDivision)) {
      selectedDivision = null;
    }
    if (selectedDepot != null && !depots.contains(selectedDepot)) {
      selectedDepot = null;
    }

    final List<Widget> widgets = [];

    if (_canChangeZone() && zones.isNotEmpty) {
      widgets.add(_buildDropdown(
        title: "Zone",
        value: selectedZone,
        items: zones,
        onChanged: (val) {
          setState(() {
            selectedZone = val;
            // Reset division and depot when zone changes
            selectedDivision = null;
            selectedDepot = null;
          });
          _notifyChange();
        },
      ));
    } else if (!_canChangeZone() && selectedZone != null) {
      widgets.add(_buildFixedField("Zone", selectedZone!));
    }

    if (_canChangeDivision() && divisions.isNotEmpty) {
      widgets.add(_buildDropdown(
        title: "Division",
        value: selectedDivision,
        items: divisions,
        onChanged: (val) {
          setState(() {
            selectedDivision = val;
            selectedDepot = null;
          });
          _notifyChange();
        },
      ));
    } else if (!_canChangeDivision() && selectedDivision != null) {
      widgets.add(_buildFixedField("Division", selectedDivision!));
    }

    if (_canChangeDepot() && depots.isNotEmpty) {
      widgets.add(_buildDropdown(
        title: "Depot",
        value: selectedDepot,
        items: depots,
        onChanged: (val) {
          setState(() => selectedDepot = val);
          _notifyChange();
        },
      ));
    } else if (!_canChangeDepot() && selectedDepot != null) {
      widgets.add(_buildFixedField("Depot", selectedDepot!));
    }

    final List<Widget> rows = [];
    for (int i = 0; i < widgets.length; i += 2) {
      if (i + 1 < widgets.length) {
        rows.add(Row(
          children: [
            Expanded(child: widgets[i]),
            const SizedBox(width: 10),
            Expanded(child: widgets[i + 1]),
          ],
        ));
      } else {
        rows.add(Row(
          children: [
            Expanded(child: widgets[i]),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ));
      }
      if (i + 2 < widgets.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }

  void _notifyChange() {
    if (widget.onChangedWithZone != null) {
      widget.onChangedWithZone!(selectedZone, selectedDivision, selectedDepot);
    } else if (widget.onChanged != null) {
      widget.onChanged!(selectedDivision, selectedDepot);
    }
  }

  Widget _buildDropdown({
    required String title,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value != null && items.contains(value) ? value : null,
              hint: Text('Select $title', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: onChanged,
              icon:
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              isExpanded: true,
              style:
              const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFixedField(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
            ],
          ),
        ),
      ],
    );
  }
}
