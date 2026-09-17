import 'package:crm_train/model/user_entity_model.dart';
import 'package:flutter/material.dart';

import '../../../services/api_services.dart';

class ApprovedEntityDropdown extends StatefulWidget {
  final Function(String name) onSelected;
  final String? initialValue;
  final void Function(String name)? onNameChanged;

  const ApprovedEntityDropdown({super.key, required this.onSelected, this.initialValue, this.onNameChanged});

  @override
  State<ApprovedEntityDropdown> createState() => _ApprovedEntityDropdownState();
}

class _ApprovedEntityDropdownState extends State<ApprovedEntityDropdown> {
  List<EntityModel> approvedEntities = [];
  EntityModel? selectedEntity;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEntities();
  }

  Future<void> _fetchEntities() async {
    try {
      final entities = await ApiService.getApprovedEntity();
      setState(() {
        approvedEntities = entities;
        if (widget.initialValue != null && entities.isNotEmpty) {
          try {
            selectedEntity = entities.firstWhere(
              (e) => e.uid == widget.initialValue,
            );
          } catch (e) {
            debugPrint("Entity with uid ${widget.initialValue} not found");
          }
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error fetching entities: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return DropdownButtonFormField<EntityModel>(
      value: selectedEntity,
      hint: const Text("Select Approved Contractor"),
      isExpanded: true,
      items: approvedEntities.map((entity) {
        return DropdownMenuItem(
          value: entity,
          child: Text(entity.contractorName ?? ''),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => selectedEntity = value);
        if (value != null) {
          widget.onSelected(value.uid ?? '');
          widget.onNameChanged?.call(value.contractorName ?? '');
        }
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
