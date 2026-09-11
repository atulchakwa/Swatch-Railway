import 'package:crm_train/controller/cts_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../data/zone_database.dart';

class CTSStep4Submit extends GetView<CTSFormController> {
  const CTSStep4Submit({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submit To',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Obx(
            () => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: (controller.currentStep.value + 1) / 4,
                backgroundColor: Colors.grey.shade300,
                color: Colors.blue,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (controller.isResubmit) ...[
            _buildRejectionReasonSection(),
            const SizedBox(height: 16),
            _buildContractorRemarksSection(),
            const SizedBox(height: 16),
          ],
          _buildSupervisorSelection(),
          const SizedBox(height: 16),
          _buildSignatureSection(),
          const SizedBox(height: 16),
          _buildFormSummary(),
        ],
      ),
    );
  }

  Widget _buildRejectionReasonSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.orange.shade900),
              const SizedBox(width: 8),
              Text(
                'Rejection Reason',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Get.find<CTSFormController>().contractorRemarks ?? 'No rejection reason provided',
            style: TextStyle(color: Colors.orange.shade900),
          ),
        ],
      ),
    );
  }

  Widget _buildContractorRemarksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Response (Contractor Remarks) *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller.contractorRemarksController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Explain what changes you made to address the rejection...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupervisorSelection() {
    return Obx(
      () => controller.isLoadingSupervisors.value
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.userRole.value == 'SUPER_ADMIN') ...[
                  const Text('Select Zone (Super Admin)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: 'Select Zone',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: controller.selectedZone.value,
                    onChanged: (v) {
                      controller.selectedZone.value = v;
                      controller.selectedDivision.value = null;
                      controller.selectedSupervisor.value = null;
                      controller.supervisors.clear();
                    },
                    items: DepotDatabase.zoneData.keys
                        .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Select Division (Super Admin)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: 'Select Division',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: controller.selectedDivision.value,
                    onChanged: controller.selectedZone.value == null
                        ? null
                        : (v) {
                            controller.selectedDivision.value = v;
                            controller.selectedSupervisor.value = null;
                            controller.supervisors.clear();
                            if (v != null) {
                              controller.fetchSupervisors(zone: controller.selectedZone.value, division: v);
                            }
                          },
                    items: controller.selectedZone.value == null
                        ? []
                        : DepotDatabase.zoneData[controller.selectedZone.value]!.keys
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                if (controller.supervisors.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No Railway Employee found for your Division. Please ensure supervisors exist for your division before submitting.',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const Text(
                    'Railway Employee',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 5),
                DropdownButtonFormField(
                  decoration: InputDecoration(
                    hintText: 'Select Railway Employee',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  value: controller.selectedSupervisor.value,
                  onChanged: (v) {
                    controller.selectedSupervisor.value = v;
                  },
                  items: controller.supervisors
                      .map(
                        (sup) => DropdownMenuItem(
                          value: sup,
                          child: Text(sup.fullName),
                        ),
                      )
                      .toList(),
                ),
                ],
                const SizedBox(height: 20),
                if (controller.userRole.value != 'SUPER_ADMIN') ...[
                  const Text(
                    'Division *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Auto populated Division',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    controller: TextEditingController(
                      text: controller.selectedSupervisor.value?.division ?? '',
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                const Text(
                  'Auto-populated from your assignment',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (controller.selectedSupervisor.value?.depot != null &&
                    controller.selectedSupervisor.value!.depot!
                        .trim()
                        .isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Depot (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Auto populated Depot',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        controller: TextEditingController(
                          text:
                              controller.selectedSupervisor.value?.depot ?? '',
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Auto-populated from your assignment',
                        style: TextStyle(color: Colors.blue, fontSize: 13),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  Widget _buildSignatureSection() {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digital Signature',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            if (controller.signedBy.value == null) ...[
              const Text(
                'Click "Sign & Submit" button to provide your digital signature',
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(30),
                child: const Column(
                  children: [
                    Icon(Icons.draw, size: 40, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'No Signature Yet',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      textAlign: TextAlign.center,
                      'Signature will be recorded upon\nsubmission',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 40,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Signed by: ${controller.signedBy.value}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Date: ${controller.signedAt.value!.toIso8601String().split('T')[0]}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormSummary() {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Form Summary',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildSummaryRow(
              'Train:',
              '${controller.selectedTrain.value?.trainNo ?? 'N/A'} - ${controller.selectedTrain.value?.trainName ?? 'Not selected'}',
            ),
            _buildSummaryRow(
              'Date:',
              '${controller.selectedDate.value.day}/${controller.selectedDate.value.month}/${controller.selectedDate.value.year}',
            ),
            _buildSummaryRow('Platform:', '${controller.platformNumber.value}'),
            _buildSummaryRow(
              'Coaches Attended:',
              '${controller.selectedCoachesAttended.value} / ${controller.selectedCoachesInRake.value}',
            ),
            _buildSummaryRow(
              'Staff Members:',
              '${controller.staffMembers.length}',
            ),
            _buildSummaryRow(
              'Garbage Disposed:',
              controller.garbageDisposed.value ? 'Yes' : 'No',
            ),
            _buildSummaryRow(
              'Submit to:',
              controller.selectedSupervisor.value?.fullName ?? 'Not selected',
            ),
            _buildSummaryRow(
              'Signed by:',
              controller.signedBy.value ?? 'Not signed yet',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
