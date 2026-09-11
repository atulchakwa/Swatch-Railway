import 'package:crm_train/data/zone_database.dart';
import 'package:flutter/material.dart';

import '../../../utills/app_colors.dart';

class FilterSection extends StatefulWidget {
  final String? fixedZone;
  final String? fixedDivision;
  final String? fixedDepot;
  final String? userRole;
  final Function(String? zone, String? division, String? depot)? onChanged;
  final VoidCallback? onClear;

  const FilterSection({
    super.key,
    this.fixedZone,
    this.fixedDivision,
    this.fixedDepot,
    this.userRole,
    this.onChanged,
    this.onClear,
  });

  @override
  State<FilterSection> createState() => _FilterSectionState();
}

class _FilterSectionState extends State<FilterSection> {
  String? tempZone;
  String? tempDivision;
  String? tempDepot;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    tempZone = widget.fixedZone;
    tempDivision = widget.fixedDivision;
    tempDepot = widget.fixedDepot;
  }

  @override
  Widget build(BuildContext context) {
    List<String> divisions = [];
    final zoneToUse = tempZone ?? widget.fixedZone;
    if (zoneToUse != null && DepotDatabase.zoneData.containsKey(zoneToUse)) {
      divisions = DepotDatabase.zoneData[zoneToUse]!.keys.toList();
    }

    List<String> depots = [];
    final divisionToUse = tempDivision ?? widget.fixedDivision;
    if (zoneToUse != null && divisionToUse != null &&
        DepotDatabase.zoneData.containsKey(zoneToUse) &&
        DepotDatabase.zoneData[zoneToUse]!.containsKey(divisionToUse)) {
      depots = DepotDatabase.zoneData[zoneToUse]![divisionToUse] ?? [];
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: kRailwayBlue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Filter',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: kRailwayBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, color: Colors.grey.shade200),
                        const SizedBox(height: 16),

                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: widget.fixedZone != null
                                      ? _readOnlyBox("Zone", widget.fixedZone!)
                                      : _buildDropdown(
                                          title: "Zone",
                                          value: tempZone,
                                          items: DepotDatabase.zoneData.keys.toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              tempZone = val;
                                              // Reset division and depot when zone changes
                                              tempDivision = null;
                                              tempDepot = null;
                                            });
                                          },
                                        ),
                                ),
                                const SizedBox(width: 10),

                                Expanded(
                                  child: widget.fixedDivision != null
                                      ? _readOnlyBox("Division", widget.fixedDivision!)
                                      : (tempZone == null
                                          ? _disabledBox("Division", "Select Zone first")
                                          : _buildDropdown(
                                              title: "Division",
                                              value: tempDivision,
                                              items: divisions,
                                              onChanged: (val) {
                                                setState(() {
                                                  tempDivision = val;
                                                  tempDepot = null;
                                                });
                                              },
                                            )),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: widget.fixedDepot != null
                                      ? _readOnlyBox("Depot", widget.fixedDepot!)
                                      : (tempDivision == null
                                          ? _disabledBox("Depot", "Select Division first")
                                          : _buildDropdown(
                                              title: "Depot",
                                              value: tempDepot,
                                              items: depots,
                                              onChanged: (val) {
                                                setState(() => tempDepot = val);
                                              },
                                            )),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(child: SizedBox()),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _clearFilters,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: Colors.red.shade400),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Clear All',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _applyFilters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kRailwayBlue,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                label: const Text(
                                  'Apply Filters',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
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
              hint: Text(
                'Select $title',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _readOnlyBox(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.lock, size: 13, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style:
                  const TextStyle(fontSize: 12, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _disabledBox(String title, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  placeholder,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _applyFilters() {
    // Only call API with the selected values (can be null if not selected)
    if (widget.onChanged != null) {
      widget.onChanged!(tempZone, tempDivision, tempDepot);
    }
  }

  void _clearFilters() {
    setState(() {
      // Reset to fixed values or null
      tempZone = widget.fixedZone;
      tempDivision = widget.fixedDivision;
      tempDepot = widget.fixedDepot;
    });

    // Apply the cleared filters
    _applyFilters();
    widget.onClear?.call();
  }
}
