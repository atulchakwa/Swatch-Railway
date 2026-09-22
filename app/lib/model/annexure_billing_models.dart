// Annexure-4B Billing rule-engine models.
// Mirrors backend/src/services/annexureBillingService.js payloads.

class AnnexureAreaComponent {
  final String id;
  final String uid;
  final String contractItemId;
  final String areaName;
  final String? areaCode;
  final String? unit;
  final double? quantity;
  final double? rate;
  final double allocatedWeightage;
  final String? frequencyOverride;
  final String status;
  final String? remarks;

  AnnexureAreaComponent({
    this.id = '',
    this.uid = '',
    this.contractItemId = '',
    this.areaName = '',
    this.areaCode,
    this.unit,
    this.quantity,
    this.rate,
    this.allocatedWeightage = 0,
    this.frequencyOverride,
    this.status = 'ACTIVE',
    this.remarks,
  });

  factory AnnexureAreaComponent.fromJson(Map<String, dynamic> json) {
    return AnnexureAreaComponent(
      id: (json['id'] ?? json['uid'] ?? '') as String,
      uid: (json['uid'] ?? json['id'] ?? '') as String,
      contractItemId: (json['contractItemId'] ?? '') as String,
      areaName: (json['areaName'] ?? '') as String,
      areaCode: json['areaCode'] as String?,
      unit: json['unit'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      rate: (json['rate'] as num?)?.toDouble(),
      allocatedWeightage: ((json['allocatedWeightage'] ?? 0) as num).toDouble(),
      frequencyOverride: json['frequencyOverride'] as String?,
      status: (json['status'] ?? 'ACTIVE') as String,
      remarks: json['remarks'] as String?,
    );
  }
}

class AnnexureContractItem {
  final String id;
  final String uid;
  final String contractId;
  final int itemNumber;
  final String contractualDescription;
  final double contractualWeightage;
  final double effectiveWeightage;
  final String frequency;
  final String quantityMode;
  final String status;
  final bool weightageTransferred;
  final int? transferredTo;
  final double allocatedWeightage;
  final double remainingWeightage;
  final int areaCount;
  final List<AnnexureAreaComponent> areas;
  final bool isAdditional;

  AnnexureContractItem({
    this.id = '',
    this.uid = '',
    this.contractId = '',
    this.itemNumber = 0,
    this.contractualDescription = '',
    this.contractualWeightage = 0,
    this.effectiveWeightage = 0,
    this.frequency = '',
    this.quantityMode = '',
    this.status = 'ACTIVE',
    this.weightageTransferred = false,
    this.transferredTo,
    this.allocatedWeightage = 0,
    this.remainingWeightage = 0,
    this.areaCount = 0,
    this.areas = const [],
    this.isAdditional = false,
  });

  factory AnnexureContractItem.fromJson(Map<String, dynamic> json) {
    final rawAreas = (json['areas'] ?? const []) as List;
    return AnnexureContractItem(
      id: (json['id'] ?? json['uid'] ?? '') as String,
      uid: (json['uid'] ?? json['id'] ?? '') as String,
      contractId: (json['contractId'] ?? '') as String,
      itemNumber: ((json['itemNumber'] ?? 0) as num).toInt(),
      contractualDescription: (json['contractualDescription'] ?? json['description'] ?? '') as String,
      contractualWeightage: ((json['contractualWeightage'] ?? 0) as num).toDouble(),
      effectiveWeightage: ((json['effectiveWeightage'] ?? json['contractualWeightage'] ?? 0) as num).toDouble(),
      frequency: (json['frequency'] ?? '') as String,
      quantityMode: (json['quantityMode'] ?? '') as String,
      status: (json['status'] ?? 'ACTIVE') as String,
      weightageTransferred: (json['weightageTransferred'] ?? false) as bool,
      transferredTo: (json['transferredTo'] as num?)?.toInt(),
      allocatedWeightage: ((json['allocatedWeightage'] ?? 0) as num).toDouble(),
      remainingWeightage: ((json['remainingWeightage'] ?? 0) as num).toDouble(),
      areaCount: ((json['areaCount'] ?? 0) as num).toInt(),
      areas: rawAreas
          .whereType<Map<String, dynamic>>()
          .map(AnnexureAreaComponent.fromJson)
          .toList(),
      isAdditional: (json['isAdditional'] ?? false) as bool,
    );
  }
}

class AnnexureContractItemsResult {
  final int count;
  final List<AnnexureContractItem> items;
  final double totalWeightage;
  final List<String> warnings;
  final int itemCount;
  final bool valid;

  AnnexureContractItemsResult({
    this.count = 0,
    this.items = const [],
    this.totalWeightage = 0,
    this.warnings = const [],
    this.itemCount = 0,
    this.valid = true,
  });

  factory AnnexureContractItemsResult.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] ?? const []) as List;
    return AnnexureContractItemsResult(
      count: ((json['count'] ?? rawItems.length) as num).toInt(),
      items: rawItems.whereType<Map<String, dynamic>>().map(AnnexureContractItem.fromJson).toList(),
      totalWeightage: ((json['totalWeightage'] ?? 0) as num).toDouble(),
      warnings: ((json['warnings'] ?? const []) as List).map((e) => e.toString()).toList(),
      itemCount: ((json['itemCount'] ?? rawItems.length) as num).toInt(),
      valid: (json['valid'] ?? true) as bool,
    );
  }
}

class AnnexureOpResult {
  final String message;
  final String uid;
  final int itemNumber;
  final double allocatedTotal;
  final double remaining;
  final double totalDeduction;
  final int deductionCount;

  AnnexureOpResult({
    this.message = '',
    this.uid = '',
    this.itemNumber = 0,
    this.allocatedTotal = 0,
    this.remaining = 0,
    this.totalDeduction = 0,
    this.deductionCount = 0,
  });

  factory AnnexureOpResult.fromJson(Map<String, dynamic> json) {
    return AnnexureOpResult(
      message: (json['message'] ?? '') as String,
      uid: (json['uid'] ?? '') as String,
      itemNumber: ((json['itemNumber'] ?? 0) as num).toInt(),
      allocatedTotal: ((json['allocatedTotal'] ?? 0) as num).toDouble(),
      remaining: ((json['remaining'] ?? 0) as num).toDouble(),
      totalDeduction: ((json['totalDeduction'] ?? 0) as num).toDouble(),
      deductionCount: ((json['deductionCount'] ?? 0) as num).toInt(),
    );
  }
}

class AnnexureBillingSummary {
  final Map<String, dynamic> contract;
  final Map<String, dynamic> period;
  final double totalWeightage;
  final List<String> warnings;
  final Map<String, dynamic> executionSummary;
  final Map<String, dynamic> deductionSummary;
  final List<Map<String, dynamic>> items;

  AnnexureBillingSummary({
    this.contract = const {},
    this.period = const {},
    this.totalWeightage = 0,
    this.warnings = const [],
    this.executionSummary = const {},
    this.deductionSummary = const {},
    this.items = const [],
  });

  factory AnnexureBillingSummary.fromJson(Map<String, dynamic> json) {
    return AnnexureBillingSummary(
      contract: (json['contract'] ?? const {}) as Map<String, dynamic>,
      period: (json['period'] ?? const {}) as Map<String, dynamic>,
      totalWeightage: ((json['totalWeightage'] ?? 0) as num).toDouble(),
      warnings: ((json['warnings'] ?? const []) as List).map((e) => e.toString()).toList(),
      executionSummary: (json['executionSummary'] ?? const {}) as Map<String, dynamic>,
      deductionSummary: (json['deductionSummary'] ?? const {}) as Map<String, dynamic>,
      items: ((json['items'] ?? const []) as List).whereType<Map<String, dynamic>>().toList(),
    );
  }
}

class AnnexureWeightageTransfer {
  final String id;
  final String uid;
  final String type;
  final int fromItemNumber;
  final int toItemNumber;
  final double weightage;
  final String reason;
  final String createdAt;

  AnnexureWeightageTransfer({
    this.id = '',
    this.uid = '',
    this.type = '',
    this.fromItemNumber = 0,
    this.toItemNumber = 0,
    this.weightage = 0,
    this.reason = '',
    this.createdAt = '',
  });

  factory AnnexureWeightageTransfer.fromJson(Map<String, dynamic> json) {
    return AnnexureWeightageTransfer(
      id: (json['id'] ?? json['uid'] ?? '') as String,
      uid: (json['uid'] ?? json['id'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      fromItemNumber: ((json['fromItemNumber'] ?? 0) as num).toInt(),
      toItemNumber: ((json['toItemNumber'] ?? 0) as num).toInt(),
      weightage: ((json['weightage'] ?? 0) as num).toDouble(),
      reason: (json['reason'] ?? '') as String,
      createdAt: (json['createdAt'] ?? '') as String,
    );
  }
}