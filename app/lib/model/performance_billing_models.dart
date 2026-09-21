// Performance / weightage-based billing models (SRS Workflow 15).

class PerformanceBillingCategory {
  final String code;
  final String name;
  final String dataSource; // execution | inspection | feedback
  final int maxMarks;
  final bool enabled;
  final int order;

  const PerformanceBillingCategory({
    required this.code,
    required this.name,
    required this.dataSource,
    required this.maxMarks,
    required this.enabled,
    required this.order,
  });

  factory PerformanceBillingCategory.fromJson(Map<String, dynamic> json) {
    return PerformanceBillingCategory(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      dataSource: json['dataSource'] ?? 'execution',
      maxMarks: (json['maxMarks'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] == null || json['enabled'] == true,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'dataSource': dataSource,
        'maxMarks': maxMarks,
        'enabled': enabled,
        'order': order,
      };
}

class PenaltyRule {
  final String? uid;
  final String name;
  final double fromScore;
  final double toScore;
  final String action; // NONE | PERCENT_OF_ELIGIBLE | PERCENT_OF_MONTHLY_BASE | FIXED_AMOUNT
  final double value;
  final double? maxAmount;
  final bool enabled;

  const PenaltyRule({
    this.uid,
    required this.name,
    required this.fromScore,
    required this.toScore,
    required this.action,
    required this.value,
    this.maxAmount,
    required this.enabled,
  });

  factory PenaltyRule.fromJson(Map<String, dynamic> json) {
    return PenaltyRule(
      uid: json['uid'],
      name: json['name'] ?? '',
      fromScore: (json['fromScore'] as num?)?.toDouble() ?? 0,
      toScore: (json['toScore'] as num?)?.toDouble() ?? 100,
      action: json['action'] ?? 'NONE',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      maxAmount: (json['maxAmount'] as num?)?.toDouble(),
      enabled: json['enabled'] == null || json['enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (uid != null) 'uid': uid,
        'name': name,
        'fromScore': fromScore,
        'toScore': toScore,
        'action': action,
        'value': value,
        if (maxAmount != null) 'maxAmount': maxAmount,
        'enabled': enabled,
      };
}

class BillingConfig {
  final String id;
  final String contractId;
  final String stationId;
  final String billingMethod;
  final double? ratePerSqft;
  final Map<String, double> areaRateOverrides;
  final Map<String, double> areaWeightages;
  final int gstRate;
  final double otherDeductions;
  final List<String> verifiedStatuses;
  final List<PerformanceBillingCategory> categories;
  final List<PenaltyRule> penaltyRules;

  const BillingConfig({
    required this.id,
    required this.contractId,
    required this.stationId,
    required this.billingMethod,
    this.ratePerSqft,
    this.areaRateOverrides = const {},
    this.areaWeightages = const {},
    required this.gstRate,
    this.otherDeductions = 0,
    required this.verifiedStatuses,
    required this.categories,
    required this.penaltyRules,
  });

  factory BillingConfig.fromJson(Map<String, dynamic> json) {
    return BillingConfig(
      id: json['id'] ?? json['uid'] ?? '',
      contractId: json['contractId'] ?? '',
      stationId: json['stationId'] ?? '',
      billingMethod: json['billingMethod'] ?? 'PERFORMANCE_WEIGHTAGE',
      ratePerSqft: (json['ratePerSqft'] as num?)?.toDouble(),
      areaRateOverrides: (json['areaRateOverrides'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          const {},
      areaWeightages: (json['areaWeightages'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          const {},
      gstRate: (json['gstRate'] as num?)?.toInt() ?? 18,
      otherDeductions: (json['otherDeductions'] as num?)?.toDouble() ?? 0,
      verifiedStatuses: (json['verifiedStatuses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['approved'],
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => PerformanceBillingCategory.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      penaltyRules: (json['penaltyRules'] as List<dynamic>?)
          ?.map((e) => PenaltyRule.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class ScorecardCategory {
  final String code;
  final String name;
  final String dataSource;
  final int maxMarks;
  final bool enabled;
  final double achievement;
  final double marks;
  final bool notApplicable;
  final int count;
  final int required;
  final int verified;

  const ScorecardCategory({
    required this.code,
    required this.name,
    required this.dataSource,
    required this.maxMarks,
    required this.enabled,
    required this.achievement,
    required this.marks,
    required this.notApplicable,
    this.count = 0,
    this.required = 0,
    this.verified = 0,
  });

  factory ScorecardCategory.fromJson(Map<String, dynamic> json) {
    final exec = json['execution'] as Map<String, dynamic>?;
    return ScorecardCategory(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      dataSource: json['dataSource'] ?? '',
      maxMarks: (json['maxMarks'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] == null || json['enabled'] == true,
      achievement: (json['achievement'] as num?)?.toDouble() ?? 0,
      marks: (json['marks'] as num?)?.toDouble() ?? 0,
      notApplicable: json['notApplicable'] == true,
      count: (json['count'] as num?)?.toInt() ?? 0,
      required: (exec?['required'] as num?)?.toInt() ?? 0,
      verified: (exec?['verified'] as num?)?.toInt() ?? 0,
    );
  }
}

class AreaScoreRow {
  final String areaId;
  final String areaName;
  final double sqft;
  final double rate;
  final String frequency;
  final int required;
  final int verified;
  final double? achievement;
  final double scheduledValue;
  final double actualValue;

  const AreaScoreRow({
    required this.areaId,
    required this.areaName,
    required this.sqft,
    this.rate = 0,
    required this.frequency,
    required this.required,
    required this.verified,
    this.achievement,
    this.scheduledValue = 0,
    this.actualValue = 0,
  });

  factory AreaScoreRow.fromJson(Map<String, dynamic> json) {
    return AreaScoreRow(
      areaId: json['areaId'] ?? '',
      areaName: json['areaName'] ?? '',
      sqft: (json['sqft'] as num?)?.toDouble() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      frequency: json['frequency'] ?? '',
      required: (json['required'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      achievement: (json['achievement'] as num?)?.toDouble(),
      scheduledValue: (json['scheduledValue'] as num?)?.toDouble() ?? 0,
      actualValue: (json['actualValue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PerformanceScorecard {
  final String contractId;
  final String stationId;
  final String stationName;
  final String contractNumber;
  final String contractorName;
  final int month;
  final int year;
  final String periodStart;
  final String periodEnd;
  final int applicableDays;
  final double ratePerSqft;
  final double scheduledWorkValue;
  final double grossWorkValue;
  final double monthlyBase;
  final List<ScorecardCategory> categories;
  final double executionAchievement;
  final List<AreaScoreRow> areaRows;
  final double overallScore;
  final String grade;
  final double lessExecutionPercent;
  final double lessExecutionAmount;
  final double eligibleAmount;

  const PerformanceScorecard({
    required this.contractId,
    required this.stationId,
    required this.stationName,
    required this.contractNumber,
    required this.contractorName,
    required this.month,
    required this.year,
    required this.periodStart,
    required this.periodEnd,
    required this.applicableDays,
    this.ratePerSqft = 0,
    required this.scheduledWorkValue,
    required this.grossWorkValue,
    required this.monthlyBase,
    required this.categories,
    required this.executionAchievement,
    required this.areaRows,
    required this.overallScore,
    required this.grade,
    required this.lessExecutionPercent,
    required this.lessExecutionAmount,
    required this.eligibleAmount,
  });

  factory PerformanceScorecard.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? {};
    final exec = json['execution'] as Map<String, dynamic>? ?? {};
    return PerformanceScorecard(
      contractId: json['contractId'] ?? '',
      stationId: json['stationId'] ?? '',
      stationName: json['stationName'] ?? '',
      contractNumber: json['contractNumber'] ?? '',
      contractorName: json['contractorName'] ?? '',
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      periodStart: period['startDate'] ?? '',
      periodEnd: period['endDate'] ?? '',
      applicableDays: (period['applicableDays'] as num?)?.toInt() ?? 0,
      ratePerSqft: (json['ratePerSqft'] as num?)?.toDouble() ?? 0,
      scheduledWorkValue: (json['scheduledWorkValue'] as num?)?.toDouble() ?? 0,
      grossWorkValue: (json['grossWorkValue'] as num?)?.toDouble() ?? 0,
      monthlyBase: (json['monthlyBase'] as num?)?.toDouble() ?? 0,
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => ScorecardCategory.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      executionAchievement: (exec['achievement'] as num?)?.toDouble() ?? 0,
      areaRows: (exec['areaRows'] as List<dynamic>?)
          ?.map((e) => AreaScoreRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
      grade: json['grade'] ?? '',
      lessExecutionPercent: (json['lessExecutionPercent'] as num?)?.toDouble() ?? 0,
      lessExecutionAmount: (json['lessExecutionAmount'] as num?)?.toDouble() ?? 0,
      eligibleAmount: (json['eligibleAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PenaltyRow {
  final String name;
  final double value;
  final double amount;

  const PenaltyRow({required this.name, required this.value, required this.amount});

  factory PenaltyRow.fromJson(Map<String, dynamic> json) {
    return PenaltyRow(
      name: json['name'] ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RecoveryRow {
  final String label;
  final double amount;

  const RecoveryRow({required this.label, required this.amount});

  factory RecoveryRow.fromJson(Map<String, dynamic> json) {
    return RecoveryRow(
      label: json['label'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};
}

class AuditEntry {
  final String action;
  final String byName;
  final String message;
  final String at;

  const AuditEntry({required this.action, required this.byName, required this.message, required this.at});

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      action: json['action'] ?? '',
      byName: json['byName'] ?? '',
      message: json['message'] ?? '',
      at: json['at'] ?? '',
    );
  }
}

class PerformanceBill {
  final String uid;
  final String billNumber;
  final String contractId;
  final String stationId;
  final String stationName;
  final String contractNumber;
  final String contractorName;
  final int month;
  final int year;
  final double ratePerSqft;
  final double scheduledWorkValue;
  final double grossWorkValue;
  final double monthlyBase;
  final PerformanceScorecard scorecard;
  final double lessExecutionPercent;
  final double lessExecutionAmount;
  final double eligibleAmount;
  final double penaltyTotal;
  final List<PenaltyRow> penaltyRows;
  final List<RecoveryRow> otherRecoveries;
  final double otherRecoveriesAmount;
  final double netAmount;
  final double gstRate;
  final double gstAmount;
  final double totalPayable;
  final String status;
  final String paymentStatus;
  final double? paymentAmount;
  final String? paymentRef;
  final List<AuditEntry> auditTrail;
  final String createdAt;

  const PerformanceBill({
    required this.uid,
    required this.billNumber,
    required this.contractId,
    required this.stationId,
    required this.stationName,
    required this.contractNumber,
    required this.contractorName,
    required this.month,
    required this.year,
    this.ratePerSqft = 0,
    required this.scheduledWorkValue,
    required this.grossWorkValue,
    required this.monthlyBase,
    required this.scorecard,
    required this.lessExecutionPercent,
    required this.lessExecutionAmount,
    required this.eligibleAmount,
    required this.penaltyTotal,
    required this.penaltyRows,
    required this.otherRecoveries,
    required this.otherRecoveriesAmount,
    required this.netAmount,
    required this.gstRate,
    required this.gstAmount,
    required this.totalPayable,
    required this.status,
    required this.paymentStatus,
    required this.paymentAmount,
    required this.paymentRef,
    required this.auditTrail,
    required this.createdAt,
  });

  factory PerformanceBill.fromJson(Map<String, dynamic> json) {
    final penalty = json['penalty'] as Map<String, dynamic>? ?? {};
    return PerformanceBill(
      uid: json['uid'] ?? json['id'] ?? '',
      billNumber: json['billNumber'] ?? '',
      contractId: json['contractId'] ?? '',
      stationId: json['stationId'] ?? '',
      stationName: json['stationName'] ?? '',
      contractNumber: json['contractNumber'] ?? '',
      contractorName: json['contractorName'] ?? '',
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      ratePerSqft: (json['ratePerSqft'] as num?)?.toDouble() ?? 0,
      scheduledWorkValue: (json['scheduledWorkValue'] as num?)?.toDouble() ?? 0,
      grossWorkValue: (json['grossWorkValue'] as num?)?.toDouble() ?? 0,
      monthlyBase: (json['monthlyBase'] as num?)?.toDouble() ?? 0,
      scorecard: PerformanceScorecard.fromJson(json['scorecard'] as Map<String, dynamic>? ?? {}),
      lessExecutionPercent: (json['lessExecutionPercent'] as num?)?.toDouble() ?? 0,
      lessExecutionAmount: (json['lessExecutionAmount'] as num?)?.toDouble() ?? 0,
      eligibleAmount: (json['eligibleAmount'] as num?)?.toDouble() ?? 0,
      penaltyTotal: (penalty['totalPenalty'] as num?)?.toDouble() ?? 0,
      penaltyRows: (penalty['rows'] as List<dynamic>?)
          ?.map((e) => PenaltyRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      otherRecoveries: (json['otherRecoveries'] as List<dynamic>?)
          ?.map((e) => RecoveryRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      otherRecoveriesAmount: (json['otherRecoveriesAmount'] as num?)?.toDouble() ?? 0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0,
      totalPayable: (json['totalPayable'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'DRAFT',
      paymentStatus: json['paymentStatus'] ?? 'unpaid',
      paymentAmount: (json['paymentAmount'] as num?)?.toDouble(),
      paymentRef: json['paymentRef'],
      auditTrail: (json['auditTrail'] as List<dynamic>?)
          ?.map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class PerformanceBillingDashboard {
  final int totalBills;
  final Map<String, int> byStatus;
  final double totalBilled;
  final double totalPayable;
  final double totalPaid;

  const PerformanceBillingDashboard({
    required this.totalBills,
    required this.byStatus,
    required this.totalBilled,
    required this.totalPayable,
    required this.totalPaid,
  });

  factory PerformanceBillingDashboard.fromJson(Map<String, dynamic> json) {
    final byStatus = <String, int>{};
    (json['byStatus'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      byStatus[k] = (v as num?)?.toInt() ?? 0;
    });
    return PerformanceBillingDashboard(
      totalBills: (json['totalBills'] as num?)?.toInt() ?? 0,
      byStatus: byStatus,
      totalBilled: (json['totalBilled'] as num?)?.toDouble() ?? 0,
      totalPayable: (json['totalPayable'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0,
    );
  }
}