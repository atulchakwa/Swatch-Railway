enum StationCategory { a1, a, b, c, d }
enum StationType { terminal, junction, regular, depot }
enum CleaningFrequency { daily, weekly, monthly, special, festival, vipVisit, emergency }
enum StationFormStatus { draft, submitted, approved, scored, locked, rejected }

class Station {
  String? uid;
  final String stationCode;
  final String stationName;
  final String zone;
  final String division;
  final StationCategory category;
  final StationType stationType;
  bool active;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime createdAt;
  DateTime? updatedAt;
  final String createdBy;

  Station({
    this.uid,
    required this.stationCode,
    required this.stationName,
    required this.zone,
    required this.division,
    this.category = StationCategory.b,
    this.stationType = StationType.regular,
    this.active = true,
    this.latitude = 0,
    this.longitude = 0,
    this.address = '',
    DateTime? createdAt,
    this.updatedAt,
    this.createdBy = '',
  }) : createdAt = createdAt ?? DateTime.now();

  String get categoryLabel {
    switch (category) {
      case StationCategory.a1: return 'A1';
      case StationCategory.a: return 'A';
      case StationCategory.b: return 'B';
      case StationCategory.c: return 'C';
      case StationCategory.d: return 'D';
    }
  }

  String get typeLabel {
    switch (stationType) {
      case StationType.terminal: return 'Terminal';
      case StationType.junction: return 'Junction';
      case StationType.regular: return 'Regular';
      case StationType.depot: return 'Depot';
    }
  }

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'stationCode': stationCode,
    'stationName': stationName,
    'zone': zone,
    'division': division,
    'category': category.name,
    'stationType': stationType.name,
    'active': active,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'createdBy': createdBy,
  };

  factory Station.fromJson(Map<String, dynamic> json) => Station(
    uid: json['uid'],
    stationCode: json['stationCode'] ?? '',
    stationName: json['stationName'] ?? '',
    zone: json['zone'] ?? '',
    division: json['division'] ?? '',
    category: StationCategory.values.firstWhere((e) => e.name == json['category'], orElse: () => StationCategory.b),
    stationType: StationType.values.firstWhere((e) => e.name == json['stationType'], orElse: () => StationType.regular),
    active: json['active'] ?? true,
    latitude: (json['latitude'] ?? 0).toDouble(),
    longitude: (json['longitude'] ?? 0).toDouble(),
    address: json['address'] ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    createdBy: json['createdBy'] ?? '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Station &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          stationCode == other.stationCode;

  @override
  int get hashCode => uid.hashCode ^ stationCode.hashCode;
}

class StationArea {
  String? uid;
  final String stationId;
  final String name;
  final int order;
  final String description;
  final bool active;
  final String? platformId;

  StationArea({
    this.uid,
    required this.stationId,
    required this.name,
    this.order = 0,
    this.description = '',
    this.active = true,
    this.platformId,
  });

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'stationId': stationId,
    'name': name,
    'order': order,
    'description': description,
    'active': active,
    if (platformId != null) 'platformId': platformId,
  };

  factory StationArea.fromJson(Map<String, dynamic> json) => StationArea(
    uid: json['uid'],
    stationId: json['stationId'] ?? '',
    name: (json['name'] != null && json['name'].toString().isNotEmpty) ? json['name'] : (json['areaName'] ?? ''),
    order: json['order'] ?? 0,
    description: json['description'] ?? '',
    active: json['active'] ?? true,
    platformId: json['platformId'],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationArea &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}

class StationZone {
  String? uid;
  final String stationId;
  final String areaId;
  final String areaName;
  final String name;
  final String description;
  final bool active;

  StationZone({
    this.uid,
    required this.stationId,
    required this.areaId,
    this.areaName = '',
    required this.name,
    this.description = '',
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'stationId': stationId,
    'areaId': areaId,
    'areaName': areaName,
    'name': name,
    'description': description,
    'active': active,
  };

  factory StationZone.fromJson(Map<String, dynamic> json) => StationZone(
    uid: json['uid'] ?? json['id'] ?? '',
    stationId: json['stationId'] ?? '',
    areaId: json['areaId'] ?? '',
    areaName: json['areaName'] ?? '',
    name: json['name'] ?? json['zoneName'] ?? '',
    description: json['description'] ?? '',
    active: json['active'] ?? true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationZone &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}

class StationContractorMapping {
  String? uid;
  final String stationId;
  final String areaId;
  final String zoneId;
  final String entityId;
  final String entityName;
  final String serviceType;
  final DateTime startDate;
  final DateTime? endDate;
  final bool active;

  StationContractorMapping({
    this.uid,
    required this.stationId,
    this.areaId = '',
    this.zoneId = '',
    required this.entityId,
    this.entityName = '',
    this.serviceType = 'Station Cleaning',
    DateTime? startDate,
    this.endDate,
    this.active = true,
  }) : startDate = startDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'stationId': stationId,
    'areaId': areaId,
    'zoneId': zoneId,
    'entityId': entityId,
    'entityName': entityName,
    'serviceType': serviceType,
    'startDate': startDate.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    'active': active,
  };

  factory StationContractorMapping.fromJson(Map<String, dynamic> json) => StationContractorMapping(
    uid: json['uid'],
    stationId: json['stationId'] ?? '',
    areaId: json['areaId'] ?? '',
    zoneId: json['zoneId'] ?? '',
    entityId: json['entityId'] ?? '',
    entityName: json['entityName'] ?? '',
    serviceType: json['serviceType'] ?? 'Station Cleaning',
    startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    active: json['active'] ?? true,
  );
}

class StationCleaningSchedule {
  String? uid;
  final String stationId;
  final String areaId;
  final String zoneId;
  final CleaningFrequency frequency;
  final String shift;
  final String entityId;
  final String entityName;
  final String supervisorId;
  final String supervisorName;
  final String startTime;
  final String endTime;
  final List<String> daysOfWeek;
  final bool active;
  final DateTime createdAt;

  StationCleaningSchedule({
    this.uid,
    required this.stationId,
    this.areaId = '',
    this.zoneId = '',
    this.frequency = CleaningFrequency.daily,
    this.shift = 'Morning',
    this.entityId = '',
    this.entityName = '',
    this.supervisorId = '',
    this.supervisorName = '',
    this.startTime = '',
    this.endTime = '',
    this.daysOfWeek = const [],
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get frequencyLabel {
    switch (frequency) {
      case CleaningFrequency.daily: return 'Daily';
      case CleaningFrequency.weekly: return 'Weekly';
      case CleaningFrequency.monthly: return 'Monthly';
      case CleaningFrequency.special: return 'Special';
      case CleaningFrequency.festival: return 'Festival';
      case CleaningFrequency.vipVisit: return 'VIP Visit';
      case CleaningFrequency.emergency: return 'Emergency';
    }
  }

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'stationId': stationId,
    'areaId': areaId,
    'zoneId': zoneId,
    'frequency': frequency.name,
    'shift': shift,
    'entityId': entityId,
    'entityName': entityName,
    'supervisorId': supervisorId,
    'supervisorName': supervisorName,
    'startTime': startTime,
    'endTime': endTime,
    'daysOfWeek': daysOfWeek,
    'active': active,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StationCleaningSchedule.fromJson(Map<String, dynamic> json) => StationCleaningSchedule(
    uid: json['uid'],
    stationId: json['stationId'] ?? '',
    areaId: json['areaId'] ?? '',
    zoneId: json['zoneId'] ?? '',
    frequency: CleaningFrequency.values.firstWhere((e) => e.name == json['frequency'], orElse: () => CleaningFrequency.daily),
    shift: json['shift'] ?? 'Morning',
    entityId: json['entityId'] ?? '',
    entityName: json['entityName'] ?? '',
    supervisorId: json['supervisorId'] ?? '',
    supervisorName: json['supervisorName'] ?? '',
    startTime: json['startTime'] ?? '',
    endTime: json['endTime'] ?? '',
    daysOfWeek: List<String>.from(json['daysOfWeek'] ?? []),
    active: json['active'] ?? true,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

class StationCleaningForm {
  String? uid;
  final String formId;
  final String stationId;
  final String stationName;
  final String areaId;
  final String areaName;
  final String zoneId;
  final String zoneName;
  final String division;
  final String depot;
  final String contractId;
  final String contractNumber;
  final String entityId;
  final String entityName;
  final String submittedBy;
  final String submittedByName;
  StationFormStatus status;
  final String cleaningDate;
  final String shift;
  final String startTime;
  final String endTime;
  final int manpowerCount;
  final int machineCount;
  final double areaCovered;
  final double areaUncleaned;
  final double garbageCollected;
  final String remarks;
  final double latitude;
  final double longitude;
  final String deviceId;
  final String gpsAddress;
  final DateTime createdAt;
  DateTime? updatedAt;
  String? approvedBy;
  String? approvedByName;
  DateTime? approvedAt;
  String? rejectedBy;
  String? rejectedByName;
  DateTime? rejectedAt;
  String? rejectionReason;
  double? score;
  String? grade;
  DateTime? scoringAt;
  String? scoredBy;
  String? scoredByName;
  DateTime? lockedAt;
  final List<StationCleaningPhoto> photos;
  final List<StationAuditLog> auditLog;
  List<String> activities;
  Map<String, dynamic>? scoringData;

  StationCleaningForm({
    this.uid,
    required this.formId,
    required this.stationId,
    this.stationName = '',
    this.areaId = '',
    this.areaName = '',
    this.zoneId = '',
    this.zoneName = '',
    required this.division,
    this.depot = '',
    this.contractId = '',
    this.contractNumber = '',
    this.entityId = '',
    this.entityName = '',
    required this.submittedBy,
    required this.submittedByName,
    this.status = StationFormStatus.draft,
    required this.cleaningDate,
    this.shift = '',
    this.startTime = '',
    this.endTime = '',
    this.manpowerCount = 0,
    this.machineCount = 0,
    this.areaCovered = 0,
    this.areaUncleaned = 0,
    this.garbageCollected = 0,
    this.remarks = '',
    this.latitude = 0,
    this.longitude = 0,
    this.deviceId = '',
    this.gpsAddress = '',
    DateTime? createdAt,
    this.updatedAt,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedByName,
    this.rejectedAt,
    this.rejectionReason,
    this.score,
    this.grade,
    this.scoringAt,
    this.scoredBy,
    this.scoredByName,
    this.lockedAt,
    this.photos = const [],
    this.auditLog = const [],
    this.activities = const [],
    this.scoringData,
  }) : createdAt = createdAt ?? DateTime.now();

  String get statusLabel {
    switch (status) {
      case StationFormStatus.draft: return 'Draft';
      case StationFormStatus.submitted: return 'Submitted';
      case StationFormStatus.approved: return 'Approved';
      case StationFormStatus.scored: return 'Scored';
      case StationFormStatus.locked: return 'Locked';
      case StationFormStatus.rejected: return 'Rejected';
    }
  }

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'formId': formId,
    'stationId': stationId,
    'stationName': stationName,
    'areaId': areaId,
    'areaName': areaName,
    'zoneId': zoneId,
    'zoneName': zoneName,
    'division': division,
    'depot': depot,
    'contractId': contractId,
    'contractNumber': contractNumber,
    'entityId': entityId,
    'entityName': entityName,
    'submittedBy': submittedBy,
    'submittedByName': submittedByName,
    'status': status.name,
    'cleaningDate': cleaningDate,
    'shift': shift,
    'startTime': startTime,
    'endTime': endTime,
    'manpowerCount': manpowerCount,
    'machineCount': machineCount,
    'areaCovered': areaCovered,
    'areaUncleaned': areaUncleaned,
    'garbageCollected': garbageCollected,
    'remarks': remarks,
    'latitude': latitude,
    'longitude': longitude,
    'deviceId': deviceId,
    'gpsAddress': gpsAddress,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (approvedBy != null) 'approvedBy': approvedBy,
    if (approvedByName != null) 'approvedByName': approvedByName,
    if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    if (rejectedBy != null) 'rejectedBy': rejectedBy,
    if (rejectedByName != null) 'rejectedByName': rejectedByName,
    if (rejectedAt != null) 'rejectedAt': rejectedAt!.toIso8601String(),
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
    if (score != null) 'score': score,
    if (grade != null) 'grade': grade,
    if (scoringAt != null) 'scoringAt': scoringAt!.toIso8601String(),
    if (scoredBy != null) 'scoredBy': scoredBy,
    if (scoredByName != null) 'scoredByName': scoredByName,
    if (lockedAt != null) 'lockedAt': lockedAt!.toIso8601String(),
    'photos': photos.map((p) => p.toJson()).toList(),
    'auditLog': auditLog.map((a) => a.toJson()).toList(),
    'activities': activities,
    if (scoringData != null) 'scoringData': scoringData,
  };

  factory StationCleaningForm.fromJson(Map<String, dynamic> json) => StationCleaningForm(
    uid: json['uid'],
    formId: json['formId'] ?? '',
    stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    areaId: json['areaId'] ?? '',
    areaName: json['areaName'] ?? '',
    zoneId: json['zoneId'] ?? '',
    zoneName: json['zoneName'] ?? '',
    division: json['division'] ?? '',
    depot: json['depot'] ?? '',
    contractId: json['contractId'] ?? '',
    contractNumber: json['contractNumber'] ?? '',
    entityId: json['entityId'] ?? '',
    entityName: json['entityName'] ?? '',
    submittedBy: json['submittedBy'] ?? '',
    submittedByName: json['submittedByName'] ?? '',
    status: StationFormStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => StationFormStatus.draft),
    cleaningDate: json['cleaningDate'] ?? '',
    shift: json['shift'] ?? '',
    startTime: json['startTime'] ?? '',
    endTime: json['endTime'] ?? '',
    manpowerCount: json['manpowerCount'] ?? 0,
    machineCount: json['machineCount'] ?? 0,
    areaCovered: (json['areaCovered'] ?? 0).toDouble(),
    areaUncleaned: (json['areaUncleaned'] ?? 0).toDouble(),
    garbageCollected: (json['garbageCollected'] ?? 0).toDouble(),
    remarks: json['remarks'] ?? '',
    latitude: (json['latitude'] ?? 0).toDouble(),
    longitude: (json['longitude'] ?? 0).toDouble(),
    deviceId: json['deviceId'] ?? '',
    gpsAddress: json['gpsAddress'] ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    approvedBy: json['approvedBy'],
    approvedByName: json['approvedByName'],
    approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
    rejectedBy: json['rejectedBy'],
    rejectedByName: json['rejectedByName'],
    rejectedAt: json['rejectedAt'] != null ? DateTime.parse(json['rejectedAt']) : null,
    rejectionReason: json['rejectionReason'],
    score: (json['score'] as num?)?.toDouble(),
    grade: json['grade'],
    scoringAt: json['scoringAt'] != null ? DateTime.parse(json['scoringAt']) : null,
    scoredBy: json['scoredBy'],
    scoredByName: json['scoredByName'],
    lockedAt: json['lockedAt'] != null ? DateTime.parse(json['lockedAt']) : null,
    photos: (json['photos'] as List?)?.map((p) => StationCleaningPhoto.fromJson(p)).toList() ?? [],
    auditLog: (json['auditLog'] as List?)?.map((a) => StationAuditLog.fromJson(a)).toList() ?? [],
    activities: List<String>.from(json['activities'] ?? []),
    scoringData: json['scoringData'] as Map<String, dynamic>?,
  );
}

class StationCleaningPhoto {
  final String url;
  final String type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  StationCleaningPhoto({required this.url, required this.type, DateTime? timestamp, this.latitude = 0, this.longitude = 0})
    : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'url': url, 'type': type, 'timestamp': timestamp.toIso8601String(), 'latitude': latitude, 'longitude': longitude,
  };

  factory StationCleaningPhoto.fromJson(Map<String, dynamic> json) => StationCleaningPhoto(
    url: json['url'] ?? '', type: json['type'] ?? 'before',
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    latitude: (json['latitude'] ?? 0).toDouble(), longitude: (json['longitude'] ?? 0).toDouble(),
  );
}

class StationAuditLog {
  final String action;
  final String performedBy;
  final String performedByName;
  final DateTime timestamp;
  final String details;

  StationAuditLog({required this.action, required this.performedBy, required this.performedByName, DateTime? timestamp, this.details = ''})
    : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'action': action, 'performedBy': performedBy, 'performedByName': performedByName,
    'timestamp': timestamp.toIso8601String(), 'details': details,
  };

  factory StationAuditLog.fromJson(Map<String, dynamic> json) => StationAuditLog(
    action: json['action'] ?? '', performedBy: json['performedBy'] ?? '',
    performedByName: json['performedByName'] ?? '',
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    details: json['details'] ?? '',
  );
}

class StationDashboardSummary {
  final int totalStations;
  final int activeStations;
  final int totalAreas;
  final int totalZones;
  final int draftForms;
  final int submittedForms;
  final int approvedForms;
  final int scoredForms;
  final int lockedForms;
  final int rejectedForms;
  final int pendingReview;
  final int schedules;
  final int contractorMappings;
  final double averageScore;

  StationDashboardSummary({
    this.totalStations = 0, this.activeStations = 0, this.totalAreas = 0, this.totalZones = 0,
    this.draftForms = 0, this.submittedForms = 0, this.approvedForms = 0, this.scoredForms = 0,
    this.lockedForms = 0, this.rejectedForms = 0, this.pendingReview = 0,
    this.schedules = 0, this.contractorMappings = 0, this.averageScore = 0,
  });

  factory StationDashboardSummary.fromJson(Map<String, dynamic> json) => StationDashboardSummary(
    totalStations: json['totalStations'] ?? 0, activeStations: json['activeStations'] ?? 0,
    totalAreas: json['totalAreas'] ?? 0, totalZones: json['totalZones'] ?? 0,
    draftForms: json['draftForms'] ?? 0, submittedForms: json['submittedForms'] ?? 0,
    approvedForms: json['approvedForms'] ?? 0, scoredForms: json['scoredForms'] ?? 0,
    lockedForms: json['lockedForms'] ?? 0, rejectedForms: json['rejectedForms'] ?? 0,
    pendingReview: json['pendingReview'] ?? 0, schedules: json['schedules'] ?? 0,
    contractorMappings: json['contractorMappings'] ?? 0, averageScore: (json['averageScore'] ?? 0).toDouble(),
  );
}

const List<String> stationCleaningActivities = [
  'Platform Cleaning',
  'Waiting Hall Cleaning',
  'Washroom Cleaning',
  'Office Cleaning',
  'Track Cleaning',
  'Parking Cleaning',
  'Escalator Cleaning',
  'Lift Cleaning',
  'Garbage Disposal',
  'Dustbin Cleaning',
  'Drainage Cleaning',
];
