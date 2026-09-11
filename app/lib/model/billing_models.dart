class ContractBillingRule {
  String uid;
  String contractId;
  String contractNumber;
  String entityId;
  String entityName;
  String division;
  String zone;
  double contractValue;
  String billingCycle;
  List<String> serviceTypes;
  double coachWeightage;
double premiseWeightage;
   double passengerFeedbackWeightage;
   double aiVerificationWeightage;

  double penaltyScore90Plus;
  double penaltyScore80To89;
  double penaltyScore70To79;
double penaltyScoreBelow70;

   double manpowerShortagePenalty;
   double machineShortagePenalty;
   double lateTaskCompletionPenalty;
   double nonCompliancePenalty;

  String status;
  DateTime createdAt;
  String createdBy;
  DateTime? updatedAt;
  String? updatedBy;

  ContractBillingRule({
    required this.uid,
    required this.contractId,
    required this.contractNumber,
    required this.entityId,
    required this.entityName,
    required this.division,
    required this.zone,
    this.contractValue = 0,
    this.billingCycle = 'Monthly',
    this.serviceTypes = const [],
    this.coachWeightage = 35,
this.premiseWeightage = 35,
     this.passengerFeedbackWeightage = 10,
     this.aiVerificationWeightage = 5,
    this.penaltyScore90Plus = 0,
    this.penaltyScore80To89 = 2,
    this.penaltyScore70To79 = 5,
this.penaltyScoreBelow70 = 10,
     this.manpowerShortagePenalty = 500,
     this.machineShortagePenalty = 1000,
     this.lateTaskCompletionPenalty = 500,
     this.nonCompliancePenalty = 1000,
    this.status = 'Active',
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory ContractBillingRule.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      if (val is Map) return DateTime.fromMillisecondsSinceEpoch((val['_seconds'] ?? 0) * 1000);
      return null;
    }

    return ContractBillingRule(
      uid: json['uid'] ?? '',
      contractId: json['contractId'] ?? '',
      contractNumber: json['contractNumber'] ?? '',
      entityId: json['entityId'] ?? '',
      entityName: json['entityName'] ?? '',
      division: json['division'] ?? '',
      zone: json['zone'] ?? '',
      contractValue: (json['contractValue'] ?? 0).toDouble(),
      billingCycle: json['billingCycle'] ?? 'Monthly',
      serviceTypes: List<String>.from(json['serviceTypes'] ?? []),
      coachWeightage: (json['coachWeightage'] ?? 0).toDouble(),
premiseWeightage: (json['premiseWeightage'] ?? 0).toDouble(),
       passengerFeedbackWeightage: (json['passengerFeedbackWeightage'] ?? 0).toDouble(),
       aiVerificationWeightage: (json['aiVerificationWeightage'] ?? 0).toDouble(),
      penaltyScore90Plus: (json['penaltyScore90Plus'] ?? 0).toDouble(),
      penaltyScore80To89: (json['penaltyScore80To89'] ?? 0).toDouble(),
      penaltyScore70To79: (json['penaltyScore70To79'] ?? 0).toDouble(),
penaltyScoreBelow70: (json['penaltyScoreBelow70'] ?? 0).toDouble(),
       manpowerShortagePenalty: (json['manpowerShortagePenalty'] ?? 0).toDouble(),
       machineShortagePenalty: (json['machineShortagePenalty'] ?? 0).toDouble(),
       lateTaskCompletionPenalty: (json['lateTaskCompletionPenalty'] ?? 0).toDouble(),
       nonCompliancePenalty: (json['nonCompliancePenalty'] ?? 0).toDouble(),
      status: json['status'] ?? 'Active',
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      createdBy: json['createdBy'] is Map ? (json['createdBy']['name'] ?? json['createdBy']['uid']?.toString() ?? '') : (json['createdBy']?.toString() ?? ''),
      updatedAt: parseDate(json['updatedAt']),
      updatedBy: json['updatedBy'] is Map ? (json['updatedBy']['name'] ?? json['updatedBy']['uid']?.toString()) : json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'contractId': contractId,
    'contractNumber': contractNumber,
    'entityId': entityId,
    'entityName': entityName,
    'division': division,
    'zone': zone,
    'contractValue': contractValue,
    'billingCycle': billingCycle,
    'serviceTypes': serviceTypes,
    'coachWeightage': coachWeightage,
'premiseWeightage': premiseWeightage,
     'passengerFeedbackWeightage': passengerFeedbackWeightage,
     'aiVerificationWeightage': aiVerificationWeightage,
    'penaltyScore90Plus': penaltyScore90Plus,
    'penaltyScore80To89': penaltyScore80To89,
    'penaltyScore70To79': penaltyScore70To79,
    'penaltyScoreBelow70': penaltyScoreBelow70,
    'manpowerShortagePenalty': manpowerShortagePenalty,
'machineShortagePenalty': machineShortagePenalty,
     'lateTaskCompletionPenalty': lateTaskCompletionPenalty,
     'nonCompliancePenalty': nonCompliancePenalty,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
    'updatedAt': updatedAt?.toIso8601String(),
    'updatedBy': updatedBy,
  };
}

class BillingReport {
  String uid;
  String billingRuleId;
  String contractId;
  String contractNumber;
  String entityId;
  String entityName;
  String division;
  String zone;
  String period;
  int month;
  int year;
  double contractValue;
  double overallScore;
  String grade;
  double performanceDeductionPct;
  double performanceDeductionAmount;
  int machineShortageCount;
  double machineDeduction;
  int manpowerShortageCount;
  double manpowerDeduction;
  int missedObhsCount;
  double obhsDeduction;
  double otherPenalties;
  double totalDeduction;
  double finalPayable;
  String status;
  String? approvedBy;
  DateTime? approvedAt;
  String? rejectionReason;
  String? invoiceNumber;
  DateTime? invoiceGeneratedAt;
  DateTime createdAt;
  String generatedBy;
  Map<String, dynamic>? scoreBreakdown;
  List<BillingDeductionItem> deductions;
  List<BillingAuditEntry> auditLog;

  BillingReport({
    required this.uid,
    required this.billingRuleId,
    required this.contractId,
    required this.contractNumber,
    required this.entityId,
    required this.entityName,
    required this.division,
    required this.zone,
    required this.period,
    required this.month,
    required this.year,
    this.contractValue = 0,
    this.overallScore = 0,
    this.grade = 'D',
    this.performanceDeductionPct = 0,
    this.performanceDeductionAmount = 0,
    this.machineShortageCount = 0,
    this.machineDeduction = 0,
    this.manpowerShortageCount = 0,
    this.manpowerDeduction = 0,
    this.missedObhsCount = 0,
    this.obhsDeduction = 0,
    this.otherPenalties = 0,
    this.totalDeduction = 0,
    this.finalPayable = 0,
    this.status = 'PENDING',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.invoiceNumber,
    this.invoiceGeneratedAt,
    required this.createdAt,
    required this.generatedBy,
    this.scoreBreakdown,
    this.deductions = const [],
    this.auditLog = const [],
  });

  factory BillingReport.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      if (val is Map) return DateTime.fromMillisecondsSinceEpoch((val['_seconds'] ?? 0) * 1000);
      return null;
    }

    return BillingReport(
      uid: json['uid'] ?? '',
    billingRuleId: json['billingRuleId'] ?? '',
    contractId: json['contractId'] ?? '',
    contractNumber: json['contractNumber'] ?? '',
    entityId: json['entityId'] ?? '',
    entityName: json['entityName'] ?? '',
    division: json['division'] ?? '',
    zone: json['zone'] ?? '',
    period: json['period'] ?? '',
    month: json['month'] ?? 1,
    year: json['year'] ?? DateTime.now().year,
    contractValue: (json['contractValue'] ?? 0).toDouble(),
    overallScore: (json['overallScore'] ?? 0).toDouble(),
    grade: json['grade'] ?? 'D',
    performanceDeductionPct: (json['performanceDeductionPct'] ?? 0).toDouble(),
    performanceDeductionAmount: (json['performanceDeductionAmount'] ?? 0).toDouble(),
    machineShortageCount: json['machineShortageCount'] ?? 0,
    machineDeduction: (json['machineDeduction'] ?? 0).toDouble(),
    manpowerShortageCount: json['manpowerShortageCount'] ?? 0,
    manpowerDeduction: (json['manpowerDeduction'] ?? 0).toDouble(),
    missedObhsCount: json['missedObhsCount'] ?? 0,
    obhsDeduction: (json['obhsDeduction'] ?? 0).toDouble(),
    otherPenalties: (json['otherPenalties'] ?? 0).toDouble(),
    totalDeduction: (json['totalDeduction'] ?? 0).toDouble(),
    finalPayable: (json['finalPayable'] ?? 0).toDouble(),
    status: json['status']?.toString() ?? 'PENDING',
    approvedBy: json['approvedBy'] is Map ? (json['approvedBy']['name'] ?? json['approvedBy']['uid']?.toString()) : json['approvedBy']?.toString(),
    approvedAt: parseDate(json['approvedAt']),
    rejectionReason: json['rejectionReason'] is Map ? (json['rejectionReason']['reason'] ?? json['rejectionReason'].toString()) : json['rejectionReason']?.toString(),
    invoiceNumber: json['invoiceNumber'] is Map ? (json['invoiceNumber']['number'] ?? json['invoiceNumber'].toString()) : json['invoiceNumber']?.toString(),
    invoiceGeneratedAt: parseDate(json['invoiceGeneratedAt']),
    createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    generatedBy: json['generatedBy'] is Map ? (json['generatedBy']['name'] ?? json['generatedBy']['uid']?.toString() ?? '') : (json['generatedBy']?.toString() ?? ''),
    scoreBreakdown: json['scoreBreakdown'] is Map ? Map<String, dynamic>.from(json['scoreBreakdown']) : null,
    deductions: (json['deductions'] as List?)?.map((e) => BillingDeductionItem.fromJson(e)).toList() ?? [],
    auditLog: (json['auditLog'] as List?)?.map((e) => BillingAuditEntry.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'billingRuleId': billingRuleId,
    'contractId': contractId,
    'contractNumber': contractNumber,
    'entityId': entityId,
    'entityName': entityName,
    'division': division,
    'zone': zone,
    'period': period,
    'month': month,
    'year': year,
    'contractValue': contractValue,
    'overallScore': overallScore,
    'grade': grade,
    'performanceDeductionPct': performanceDeductionPct,
    'performanceDeductionAmount': performanceDeductionAmount,
    'machineShortageCount': machineShortageCount,
    'machineDeduction': machineDeduction,
    'manpowerShortageCount': manpowerShortageCount,
    'manpowerDeduction': manpowerDeduction,
    'missedObhsCount': missedObhsCount,
    'obhsDeduction': obhsDeduction,
    'otherPenalties': otherPenalties,
    'totalDeduction': totalDeduction,
    'finalPayable': finalPayable,
    'status': status,
    'approvedBy': approvedBy,
    'approvedAt': approvedAt?.toIso8601String(),
    'rejectionReason': rejectionReason,
    'invoiceNumber': invoiceNumber,
    'invoiceGeneratedAt': invoiceGeneratedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'generatedBy': generatedBy,
    'scoreBreakdown': scoreBreakdown,
    'deductions': deductions.map((e) => e.toJson()).toList(),
    'auditLog': auditLog.map((e) => e.toJson()).toList(),
  };
}

class BillingDeductionItem {
  String type;
  String description;
  int count;
  double rate;
  double amount;

  BillingDeductionItem({
    required this.type,
    required this.description,
    this.count = 0,
    this.rate = 0,
    this.amount = 0,
  });

  factory BillingDeductionItem.fromJson(Map<String, dynamic> json) => BillingDeductionItem(
    type: json['type'] ?? '',
    description: json['description'] ?? '',
    count: json['count'] ?? 0,
    rate: (json['rate'] ?? 0).toDouble(),
    amount: (json['amount'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'description': description,
    'count': count,
    'rate': rate,
    'amount': amount,
  };
}

class BillingAuditEntry {
  String action;
  String performedBy;
  String performedByName;
  DateTime timestamp;
  String details;

  BillingAuditEntry({
    required this.action,
    required this.performedBy,
    required this.performedByName,
    required this.timestamp,
    required this.details,
  });

  factory BillingAuditEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      if (val is Map) return DateTime.fromMillisecondsSinceEpoch((val['_seconds'] ?? 0) * 1000);
      return null;
    }

    return BillingAuditEntry(
      action: json['action'] ?? '',
      performedBy: json['performedBy'] is Map ? (json['performedBy']['uid']?.toString() ?? '') : (json['performedBy']?.toString() ?? ''),
      performedByName: json['performedByName'] is Map ? (json['performedByName']['name']?.toString() ?? '') : (json['performedByName']?.toString() ?? ''),
      timestamp: parseDate(json['timestamp']) ?? DateTime.now(),
      details: json['details'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'action': action,
    'performedBy': performedBy,
    'performedByName': performedByName,
    'timestamp': timestamp.toIso8601String(),
    'details': details,
  };
}

class BillingDashboardSummary {
  int pendingBills;
  int approvedBills;
  int rejectedBills;
  double totalContractValue;
  double totalDeductions;
  double totalPayable;
  int activeContracts;

  BillingDashboardSummary({
    this.pendingBills = 0,
    this.approvedBills = 0,
    this.rejectedBills = 0,
    this.totalContractValue = 0,
    this.totalDeductions = 0,
    this.totalPayable = 0,
    this.activeContracts = 0,
  });

  factory BillingDashboardSummary.fromJson(Map<String, dynamic> json) => BillingDashboardSummary(
    pendingBills: json['pendingBills'] ?? 0,
    approvedBills: json['approvedBills'] ?? 0,
    rejectedBills: json['rejectedBills'] ?? 0,
    totalContractValue: (json['totalContractValue'] ?? 0).toDouble(),
    totalDeductions: (json['totalDeductions'] ?? 0).toDouble(),
    totalPayable: (json['totalPayable'] ?? 0).toDouble(),
    activeContracts: json['activeContracts'] ?? 0,
  );
}

class BillingEngine {
  static double calculatePerformanceDeductionPct(double overallScore, ContractBillingRule rule) {
    if (overallScore >= 90) return rule.penaltyScore90Plus;
    if (overallScore >= 80) return rule.penaltyScore80To89;
    if (overallScore >= 70) return rule.penaltyScore70To79;
    return rule.penaltyScoreBelow70;
  }

  static String calculateGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    return 'D';
  }

static BillingReport generateBill({
     required String uid,
     required ContractBillingRule rule,
     required int month,
     required int year,
     required double overallScore,
     required String generatedBy,
     Map<String, dynamic>? scoreBreakdown,
     int machineShortageCount = 0,
     int manpowerShortageCount = 0,
     double otherPenalties = 0,
   }) {
     final period = '${_monthName(month)} $year';
     final grade = calculateGrade(overallScore);
     final perfDedPct = calculatePerformanceDeductionPct(overallScore, rule);
     final perfDedAmount = rule.contractValue * perfDedPct / 100;
     final machineDed = machineShortageCount * rule.machineShortagePenalty;
     final manpowerDed = manpowerShortageCount * rule.manpowerShortagePenalty;
     final obhsDed = 0;
     final totalDed = perfDedAmount + machineDed + manpowerDed + obhsDed + otherPenalties;
    final finalPayable = rule.contractValue - totalDed;

    List<BillingDeductionItem> deductions = [];
    if (perfDedAmount > 0) {
      deductions.add(BillingDeductionItem(
        type: 'Performance',
        description: 'Performance deduction at $perfDedPct% (Score: $overallScore%)',
        count: 1, rate: perfDedPct, amount: perfDedAmount,
      ));
    }
    if (machineDed > 0) {
      deductions.add(BillingDeductionItem(
        type: 'Machine Shortage',
        description: 'Machine shortage penalty',
        count: machineShortageCount, rate: rule.machineShortagePenalty, amount: machineDed,
      ));
    }
    if (manpowerDed > 0) {
      deductions.add(BillingDeductionItem(
        type: 'Manpower Shortage',
        description: 'Manpower shortage penalty',
        count: manpowerShortageCount, rate: rule.manpowerShortagePenalty, amount: manpowerDed,
      ));
    }
if (otherPenalties > 0) {
      deductions.add(BillingDeductionItem(
        type: 'Other Penalties', description: 'Other applicable penalties',
        count: 1, rate: otherPenalties, amount: otherPenalties,
      ));
    }

    return BillingReport(
      uid: uid,
      billingRuleId: rule.uid,
      contractId: rule.contractId,
      contractNumber: rule.contractNumber,
      entityId: rule.entityId,
      entityName: rule.entityName,
      division: rule.division,
      zone: rule.zone,
      period: period,
      month: month,
      year: year,
      contractValue: rule.contractValue,
      overallScore: overallScore,
      grade: grade,
      performanceDeductionPct: perfDedPct,
      performanceDeductionAmount: perfDedAmount,
      machineShortageCount: machineShortageCount,
      machineDeduction: machineDed,
      manpowerShortageCount: manpowerShortageCount,
      manpowerDeduction: manpowerDed,
missedObhsCount: 0,
       obhsDeduction: 0,
      otherPenalties: otherPenalties,
      totalDeduction: totalDed,
      finalPayable: finalPayable,
      status: 'PENDING',
      createdAt: DateTime.now(),
      generatedBy: generatedBy,
      scoreBreakdown: scoreBreakdown,
      deductions: deductions,
      auditLog: [
        BillingAuditEntry(
          action: 'GENERATED',
          performedBy: generatedBy,
          performedByName: 'System',
          timestamp: DateTime.now(),
          details: 'Bill generated for $period - Score: $overallScore%, Grade: $grade',
        ),
      ],
    );
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }
}
