class DailyTaskBillingResponse {
  final String uid;
  final String contractId;
  final String contractNumber;
  final String stationId;
  final String stationName;
  final String date;
  final String contractStartDate;
  final String contractEndDate;
  final int contractDays;
  final double ratePerSqft;

  // Value pipeline (AREA -> SQFT -> RATE -> EXECUTION).
  final double expectedWorkValue;
  final double actualExecutionValue;
  final double grossAmount;
  final double expectedSqFt;
  final double executedSqFt;
  final double? taskExecutionScore;

  // Performance summary (50 / 20 / 30).
  final double? inspectionScore;
  final double? feedbackScore;
  final List<Map<String, dynamic>> categories;
  final double overallScore;
  final String grade;

  // Financial pipeline (score NEVER multiplies the work value; it only picks
  // the configured penalty/deduction rule).
  final double grossEligibleWorkValue;
  final double performancePenaltyAmount;
  final double otherDeductions;
  final bool penaltyApplied;
  final double penalty;

  final double deduction;
  final double netAmount;
  final double gstRate;
  final double gstAmount;
  final double totalPayable;

  final List<Map<String, dynamic>> areaRows;
  final String status;
  final String generatedByName;

  DailyTaskBillingResponse({
    this.uid = '',
    this.contractId = '',
    this.contractNumber = '',
    this.stationId = '',
    this.stationName = '',
    this.date = '',
    this.contractStartDate = '',
    this.contractEndDate = '',
    this.contractDays = 0,
    this.ratePerSqft = 0,
    this.expectedWorkValue = 0,
    this.actualExecutionValue = 0,
    this.grossAmount = 0,
    this.expectedSqFt = 0,
    this.executedSqFt = 0,
    this.taskExecutionScore,
    this.inspectionScore,
    this.feedbackScore,
    this.categories = const [],
    this.overallScore = 0,
    this.grade = 'E',
    this.grossEligibleWorkValue = 0,
    this.performancePenaltyAmount = 0,
    this.otherDeductions = 0,
    this.penaltyApplied = false,
    this.penalty = 0,
    this.deduction = 0,
    this.netAmount = 0,
    this.gstRate = 0,
    this.gstAmount = 0,
    this.totalPayable = 0,
    this.areaRows = const [],
    this.status = '',
    this.generatedByName = '',
  });

  factory DailyTaskBillingResponse.fromJson(Map<String, dynamic> json) {
    final penalty = json['penalty'] is Map<String, dynamic>
        ? json['penalty'] as Map<String, dynamic>
        : const <String, dynamic>{};
    double num2(String key) => (json[key] as num?)?.toDouble() ?? 0;
    double? numOpt(String key) => json[key] == null ? null : (json[key] as num).toDouble();
    return DailyTaskBillingResponse(
      uid: (json['uid'] ?? json['id'] ?? '').toString(),
      contractId: (json['contractId'] ?? '').toString(),
      contractNumber: (json['contractNumber'] ?? '').toString(),
      stationId: (json['stationId'] ?? '').toString(),
      stationName: (json['stationName'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      contractStartDate: (json['contractStartDate'] ?? '').toString(),
      contractEndDate: (json['contractEndDate'] ?? '').toString(),
      contractDays: (json['contractDays'] ?? 0) as int,
      ratePerSqft: num2('ratePerSqft'),
      expectedWorkValue: num2('expectedWorkValue'),
      actualExecutionValue: num2('actualExecutionValue'),
      grossAmount: num2('grossAmount'),
      expectedSqFt: num2('expectedSqFt'),
      executedSqFt: num2('executedSqFt'),
      taskExecutionScore: numOpt('taskExecutionScore'),
      inspectionScore: numOpt('inspectionScore'),
      feedbackScore: numOpt('feedbackScore'),
      categories: (json['categories'] is List)
          ? (json['categories'] as List).map((e) => Map<String, dynamic>.from((e as Map))).toList()
          : const [],
      overallScore: num2('overallScore'),
      grade: (json['grade'] ?? 'E').toString(),
      grossEligibleWorkValue: num2('grossEligibleWorkValue'),
      performancePenaltyAmount: num2('performancePenaltyAmount'),
      otherDeductions: num2('otherDeductions'),
      penaltyApplied: penalty['applied'] == true,
      penalty: ((penalty['totalPenalty'] as num?) ?? 0).toDouble(),
      deduction: num2('deduction'),
      netAmount: num2('netAmount'),
      gstRate: num2('gstRate'),
      gstAmount: num2('gstAmount'),
      totalPayable: num2('totalPayable'),
      areaRows: (json['areaRows'] is List)
          ? (json['areaRows'] as List).map((e) => Map<String, dynamic>.from((e as Map))).toList()
          : const [],
      status: (json['status'] ?? '').toString(),
      generatedByName: (json['generatedByName'] ?? '').toString(),
    );
  }
}

class DailyBillingMonth {
  final int count;
  final double totalExpectedWorkValue;
  final double totalActualExecutionValue;
  final double totalGrossAmount;
  final double totalPerformancePenalty;
  final double totalOtherDeductions;
  final double totalDeduction;
  final double totalNetAmount;
  final double? avgTaskExecutionScore;
  final double? avgInspectionScore;
  final double? avgFeedbackScore;
  final double? avgFinalScore;
  final List<DailyTaskBillingResponse> bills;

  DailyBillingMonth({
    this.count = 0,
    this.totalExpectedWorkValue = 0,
    this.totalActualExecutionValue = 0,
    this.totalGrossAmount = 0,
    this.totalPerformancePenalty = 0,
    this.totalOtherDeductions = 0,
    this.totalDeduction = 0,
    this.totalNetAmount = 0,
    this.avgTaskExecutionScore,
    this.avgInspectionScore,
    this.avgFeedbackScore,
    this.avgFinalScore,
    this.bills = const [],
  });

  factory DailyBillingMonth.fromJson(Map<String, dynamic> json) {
    double num2(String key) => (json[key] as num?)?.toDouble() ?? 0;
    double? numOpt(String key) => json[key] == null ? null : (json[key] as num).toDouble();
    final list = (json['bills'] ?? []) as List;
    return DailyBillingMonth(
      count: (json['count'] ?? 0) as int,
      totalExpectedWorkValue: num2('totalExpectedWorkValue'),
      totalActualExecutionValue: num2('totalActualExecutionValue'),
      totalGrossAmount: num2('totalGrossAmount'),
      totalPerformancePenalty: num2('totalPerformancePenalty'),
      totalOtherDeductions: num2('totalOtherDeductions'),
      totalDeduction: num2('totalDeduction'),
      totalNetAmount: num2('totalNetAmount'),
      avgTaskExecutionScore: numOpt('avgTaskExecutionScore'),
      avgInspectionScore: numOpt('avgInspectionScore'),
      avgFeedbackScore: numOpt('avgFeedbackScore'),
      avgFinalScore: numOpt('avgFinalScore'),
      bills: list.map((e) => DailyTaskBillingResponse.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}