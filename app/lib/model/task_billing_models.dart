class AreaWeightage {
  final String uid;
  final String areaName;
  final String areaId;
  final String mainArea;
  final double weightage;
  final double tenderedAreaSqFt;
  final String cleaningFrequency;
  final int boqTimesPerPeriod;
  final double? ratePerSqFt;
  final int version;
  final int? annexureItemNo;

  AreaWeightage({
    required this.uid,
    required this.areaName,
    this.areaId = '',
    this.mainArea = '',
    this.weightage = 0,
    this.tenderedAreaSqFt = 0,
    this.cleaningFrequency = 'daily',
    this.boqTimesPerPeriod = 0,
    this.ratePerSqFt,
    this.version = 1,
    this.annexureItemNo,
  });

  factory AreaWeightage.fromJson(Map<String, dynamic> json) => AreaWeightage(
        uid: (json['id'] ?? json['uid'] ?? '').toString(),
        areaName: (json['areaName'] ?? '').toString(),
        areaId: (json['areaId'] ?? '').toString(),
        mainArea: (json['mainArea'] ?? '').toString(),
        weightage: (json['weightage'] ?? 0).toDouble(),
        tenderedAreaSqFt: (json['tenderedAreaSqFt'] ?? 0).toDouble(),
        cleaningFrequency: (json['cleaningFrequency'] ?? 'daily').toString(),
        boqTimesPerPeriod: (json['boqTimesPerPeriod'] ?? 0) as int,
        ratePerSqFt: json['ratePerSqFt'] == null ? null : (json['ratePerSqFt'] as num).toDouble(),
        version: (json['version'] ?? 1) as int,
        annexureItemNo: json['annexureItemNo'] == null ? null : (json['annexureItemNo'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'areaName': areaName,
        'mainArea': mainArea,
        'weightage': weightage,
        'tenderedAreaSqFt': tenderedAreaSqFt,
        'cleaningFrequency': cleaningFrequency,
        'boqTimesPerPeriod': boqTimesPerPeriod,
        if (ratePerSqFt != null) 'ratePerSqFt': ratePerSqFt,
      };
}

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
  final double dailyBaseTask;
  final double expectedSqFt;
  final double executedSqFt;
  final double? dayExecutionRate;
  final double grossAmount;
  final double deduction;
  final double netAmount;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? weighted;
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
    this.dailyBaseTask = 0,
    this.expectedSqFt = 0,
    this.executedSqFt = 0,
    this.dayExecutionRate,
    this.grossAmount = 0,
    this.deduction = 0,
    this.netAmount = 0,
    this.rows = const [],
    this.weighted,
    this.status = '',
    this.generatedByName = '',
  });

  factory DailyTaskBillingResponse.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map<String, dynamic>
        ? json['summary'] as Map<String, dynamic>
        : json;
    final rows = (summary['rows'] ?? []) as List;
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
      dailyBaseTask: (summary['dailyBaseTask'] ?? 0).toDouble(),
      expectedSqFt: (summary['expectedSqFt'] ?? 0).toDouble(),
      executedSqFt: (summary['executedSqFt'] ?? 0).toDouble(),
      dayExecutionRate: summary['dayExecutionRate'] == null
          ? null
          : (summary['dayExecutionRate'] as num).toDouble(),
      grossAmount: (summary['grossAmount'] ?? 0).toDouble(),
      deduction: (summary['deduction'] ?? 0).toDouble(),
      netAmount: (summary['netAmount'] ?? 0).toDouble(),
      rows: rows.map((e) => Map<String, dynamic>.from((e as Map))).toList(),
      weighted: json['weighted'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['weighted'] as Map<String, dynamic>)
          : null,
      status: (json['status'] ?? '').toString(),
      generatedByName: (json['generatedByName'] ?? '').toString(),
    );
  }
}