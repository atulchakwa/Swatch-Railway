class AreaConfig {
  final String? id;
  final String areaName;
  final String areaCode;
  final String? stationId;
  final String? platformId;
  final String? supervisorId;
  final String cleaningFrequency;
  final List<String> frequencyTimes;
  final String defaultShift;
  final int defaultWorkers;
  final int priority;
  final String? qrCode;
  final String status;

  AreaConfig({
    this.id,
    required this.areaName,
    this.areaCode = '',
    this.stationId,
    this.platformId,
    this.supervisorId,
    this.cleaningFrequency = 'daily',
    this.frequencyTimes = const ['08:00'],
    this.defaultShift = 'morning',
    this.defaultWorkers = 1,
    this.priority = 3,
    this.qrCode,
    this.status = 'active',
  });

  factory AreaConfig.fromJson(Map<String, dynamic> json) => AreaConfig(
    id: json['uid'] ?? json['id'],
    areaName: json['areaName'] ?? json['name'] ?? '',
    areaCode: json['areaCode'] ?? '',
    stationId: json['stationId'],
    platformId: json['platformId'],
    supervisorId: json['supervisorId'],
    cleaningFrequency: json['cleaningFrequency'] ?? json['frequency'] ?? 'daily',
    frequencyTimes: (json['frequencyTimes'] as List<dynamic>?)?.cast<String>() ?? ['08:00'],
    defaultShift: json['defaultShift'] ?? 'morning',
    defaultWorkers: json['defaultWorkers'] ?? 1,
    priority: json['priority'] ?? 3,
    qrCode: json['qrCode'],
    status: json['status'] ?? 'active',
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'uid': id,
    'areaName': areaName,
    'areaCode': areaCode,
    'stationId': stationId,
    'platformId': platformId,
    'supervisorId': supervisorId,
    'cleaningFrequency': cleaningFrequency,
    'frequencyTimes': frequencyTimes,
    'defaultShift': defaultShift,
    'defaultWorkers': defaultWorkers,
    'priority': priority,
    'qrCode': qrCode,
    'status': status,
  };
}

class AreaWorkerAssignment {
  final String? uid;
  final String areaId;
  final String workerId;
  final String workerName;
  final String shift;
  final bool isPrimary;
  final String status;

  AreaWorkerAssignment({
    this.uid,
    required this.areaId,
    required this.workerId,
    required this.workerName,
    this.shift = 'morning',
    this.isPrimary = false,
    this.status = 'active',
  });

  factory AreaWorkerAssignment.fromJson(Map<String, dynamic> json) => AreaWorkerAssignment(
    uid: json['uid'] ?? json['id'],
    areaId: json['areaId'] ?? '',
    workerId: json['workerId'] ?? '',
    workerName: json['workerName'] ?? '',
    shift: json['shift'] ?? 'morning',
    isPrimary: json['isPrimary'] ?? false,
    status: json['status'] ?? 'active',
  );

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'areaId': areaId,
    'workerId': workerId,
    'workerName': workerName,
    'shift': shift,
    'isPrimary': isPrimary,
    'status': status,
  };
}

class CleaningTask {
  final String? uid;
  final String? stationId;
  final String? platformId;
  final String areaId;
  final String areaName;
  final String? areaCode;
  final String? workerId;
  final String? workerName;
  final String? supervisorId;
  final String? activityType;
  final String frequency;
  final String scheduledDate;
  final String scheduledTime;
  final int priority;
  final String shift;
  final String status;
  final String? startedAt;
  final String? completedAt;
  final String? approvedAt;
  final String? rejectedAt;
  final String? resubmittedAt;
  final String? beforePhoto;
  final String? afterPhoto;
  final double? gpsLat;
  final double? gpsLng;
  final String? supervisorNotes;
  final String? rejectionReason;
  final String? remarks;

  CleaningTask({
    this.uid,
    this.stationId,
    this.platformId,
    required this.areaId,
    this.areaName = '',
    this.areaCode,
    this.workerId,
    this.workerName,
    this.supervisorId,
    this.activityType,
    this.frequency = 'daily',
    required this.scheduledDate,
    required this.scheduledTime,
    this.priority = 3,
    this.shift = 'morning',
    this.status = 'pending',
    this.startedAt,
    this.completedAt,
    this.approvedAt,
    this.rejectedAt,
    this.resubmittedAt,
    this.beforePhoto,
    this.afterPhoto,
    this.gpsLat,
    this.gpsLng,
    this.supervisorNotes,
    this.rejectionReason,
    this.remarks,
  });

  factory CleaningTask.fromJson(Map<String, dynamic> json) => CleaningTask(
    uid: json['uid'] ?? json['id'],
    stationId: json['stationId'],
    platformId: json['platformId'],
    areaId: json['areaId'] ?? '',
    areaName: json['areaName'] ?? '',
    areaCode: json['areaCode'],
    workerId: json['workerId'],
    workerName: json['workerName'],
    supervisorId: json['supervisorId'],
    activityType: json['activityType'],
    frequency: json['frequency'] ?? 'daily',
    scheduledDate: json['scheduledDate'] ?? '',
    scheduledTime: json['scheduledTime'] ?? '08:00',
    priority: json['priority'] ?? 3,
    shift: json['shift'] ?? 'morning',
    status: json['status'] ?? 'pending',
    startedAt: json['startedAt'],
    completedAt: json['completedAt'],
    approvedAt: json['approvedAt'],
    rejectedAt: json['rejectedAt'],
    resubmittedAt: json['resubmittedAt'],
    beforePhoto: json['beforePhoto'],
    afterPhoto: json['afterPhoto'],
    gpsLat: (json['gpsLat'] as num?)?.toDouble(),
    gpsLng: (json['gpsLng'] as num?)?.toDouble(),
    supervisorNotes: json['supervisorNotes'],
    rejectionReason: json['rejectionReason'],
    remarks: json['remarks'],
  );

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'stationId': stationId,
    'platformId': platformId,
    'areaId': areaId,
    'areaName': areaName,
    'areaCode': areaCode,
    'workerId': workerId,
    'workerName': workerName,
    'supervisorId': supervisorId,
    'activityType': activityType,
    'frequency': frequency,
    'scheduledDate': scheduledDate,
    'scheduledTime': scheduledTime,
    'priority': priority,
    'shift': shift,
    'status': status,
    'beforePhoto': beforePhoto,
    'afterPhoto': afterPhoto,
    'gpsLat': gpsLat,
    'gpsLng': gpsLng,
    'supervisorNotes': supervisorNotes,
    'rejectionReason': rejectionReason,
  };
}

class PlatformSummary {
  final String platformId;
  final String platformName;
  final String platformNumber;

  PlatformSummary({
    required this.platformId,
    this.platformName = '',
    this.platformNumber = '',
  });

  factory PlatformSummary.fromJson(Map<String, dynamic> json) => PlatformSummary(
    platformId: json['platformId'] ?? '',
    platformName: json['platformName'] ?? '',
    platformNumber: json['platformNumber'] ?? '',
  );
}

class StationDashboard {
  final String level;
  final String stationId;
  final String stationName;
  final String stationCode;
  final Map<String, dynamic> period;
  final Map<String, dynamic> scorecard;
  final Map<String, dynamic> attendance;
  final Map<String, dynamic> feedback;
  final Map<String, dynamic> complaints;
  final Map<String, dynamic> machines;
  final Map<String, dynamic> activities;
  final Map<String, dynamic> plannedVsCompleted;
  final Map<String, dynamic> missedAlerts;
  final Map<String, dynamic> billingReadiness;
  final Map<String, dynamic> reportsSent;
  final Map<String, dynamic> cleaning;
  final List<PlatformSummary> platforms;

  StationDashboard({
    required this.level,
    required this.stationId,
    this.stationName = '',
    this.stationCode = '',
    this.period = const {},
    this.scorecard = const {},
    this.attendance = const {},
    this.feedback = const {},
    this.complaints = const {},
    this.machines = const {},
    this.activities = const {},
    this.plannedVsCompleted = const {},
    this.missedAlerts = const {},
    this.billingReadiness = const {},
    this.reportsSent = const {},
    this.cleaning = const {},
    this.platforms = const [],
  });

  factory StationDashboard.fromJson(Map<String, dynamic> json) => StationDashboard(
    level: json['level'] ?? 'station',
    stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    stationCode: json['stationCode'] ?? '',
    period: json['period'] ?? {},
    scorecard: json['scorecard'] ?? {},
    attendance: json['attendance'] ?? {},
    feedback: json['feedback'] ?? {},
    complaints: json['complaints'] ?? {},
    machines: json['machines'] ?? {},
    activities: json['activities'] ?? {},
    plannedVsCompleted: json['plannedVsCompleted'] ?? {},
    missedAlerts: json['missedAlerts'] ?? {},
    billingReadiness: json['billingReadiness'] ?? {},
    reportsSent: json['reportsSent'] ?? {},
    cleaning: json['cleaning'] ?? {},
    platforms: (json['platforms'] as List<dynamic>?)?.map((e) => PlatformSummary.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class PlatformDashboard {
  final String level;
  final String platformId;
  final String platformName;
  final String platformNumber;
  final String stationId;
  final String date;
  final int areaCount;
  final int runCount;
  final Map<String, dynamic> cleaning;
  final List<AreaConfig> areas;

  PlatformDashboard({
    required this.level,
    required this.platformId,
    this.platformName = '',
    this.platformNumber = '',
    this.stationId = '',
    this.date = '',
    this.areaCount = 0,
    this.runCount = 0,
    this.cleaning = const {},
    this.areas = const [],
  });

  factory PlatformDashboard.fromJson(Map<String, dynamic> json) => PlatformDashboard(
    level: json['level'] ?? 'platform',
    platformId: json['platformId'] ?? '',
    platformName: json['platformName'] ?? '',
    platformNumber: json['platformNumber'] ?? '',
    stationId: json['stationId'] ?? '',
    date: json['date'] ?? '',
    areaCount: json['areaCount'] ?? 0,
    runCount: json['runCount'] ?? 0,
    cleaning: json['cleaning'] ?? {},
    areas: (json['areas'] as List<dynamic>?)?.map((e) => AreaConfig.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class AreaDashboard {
  final String level;
  final String areaId;
  final String areaName;
  final String areaCode;
  final String stationId;
  final String platformId;
  final String cleaningFrequency;
  final List<String> frequencyTimes;
  final String defaultShift;
  final int defaultWorkers;
  final int priority;
  final String date;
  final Map<String, dynamic> cleaning;
  final int workerCount;
  final List<dynamic> workers;
  final int runs;
  final List<CleaningTask> scheduledTasks;

  AreaDashboard({
    required this.level,
    required this.areaId,
    this.areaName = '',
    this.areaCode = '',
    this.stationId = '',
    this.platformId = '',
    this.cleaningFrequency = 'daily',
    this.frequencyTimes = const [],
    this.defaultShift = 'morning',
    this.defaultWorkers = 1,
    this.priority = 3,
    this.date = '',
    this.cleaning = const {},
    this.workerCount = 0,
    this.workers = const [],
    this.runs = 0,
    this.scheduledTasks = const [],
  });

  factory AreaDashboard.fromJson(Map<String, dynamic> json) => AreaDashboard(
    level: json['level'] ?? 'area',
    areaId: json['areaId'] ?? '',
    areaName: json['areaName'] ?? '',
    areaCode: json['areaCode'] ?? '',
    stationId: json['stationId'] ?? '',
    platformId: json['platformId'] ?? '',
    cleaningFrequency: json['cleaningFrequency'] ?? 'daily',
    frequencyTimes: (json['frequencyTimes'] as List<dynamic>?)?.cast<String>() ?? [],
    defaultShift: json['defaultShift'] ?? 'morning',
    defaultWorkers: json['defaultWorkers'] ?? 1,
    priority: json['priority'] ?? 3,
    date: json['date'] ?? '',
    cleaning: json['cleaning'] ?? {},
    workerCount: json['workerCount'] ?? 0,
    workers: json['workers'] ?? [],
    runs: json['runs'] ?? 0,
    scheduledTasks: (json['scheduledTasks'] as List<dynamic>?)?.map((e) => CleaningTask.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class ZoneDashboard {
  final String level;
  final String zoneId;
  final String zoneName;
  final int stationCount;
  final List<StationSummary> stations;

  ZoneDashboard({
    required this.level,
    required this.zoneId,
    this.zoneName = '',
    this.stationCount = 0,
    this.stations = const [],
  });

  factory ZoneDashboard.fromJson(Map<String, dynamic> json) => ZoneDashboard(
    level: json['level'] ?? 'zone',
    zoneId: json['zoneId'] ?? '',
    zoneName: json['zoneName'] ?? '',
    stationCount: json['stationCount'] ?? 0,
    stations: (json['stations'] as List<dynamic>?)?.map((e) => StationSummary.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class StationSummary {
  final String stationId;
  final String stationName;
  final String stationCode;
  final int platformCount;
  final Map<String, dynamic> todayTasks;

  StationSummary({
    required this.stationId,
    this.stationName = '',
    this.stationCode = '',
    this.platformCount = 0,
    this.todayTasks = const {},
  });

  factory StationSummary.fromJson(Map<String, dynamic> json) => StationSummary(
    stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    stationCode: json['stationCode'] ?? '',
    platformCount: json['platformCount'] ?? 0,
    todayTasks: json['todayTasks'] ?? {},
  );
}

class AdminDashboard {
  final String level;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> cleaningTasks;
  final List<ZoneSummary> zones;

  AdminDashboard({
    required this.level,
    this.summary = const {},
    this.cleaningTasks = const {},
    this.zones = const [],
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
    level: json['level'] ?? 'admin',
    summary: json['summary'] ?? {},
    cleaningTasks: json['cleaningTasks'] ?? {},
    zones: (json['zones'] as List<dynamic>?)?.map((e) => ZoneSummary.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

class ZoneSummary {
  final String zoneId;
  final String zoneName;
  final int stationCount;

  ZoneSummary({
    required this.zoneId,
    this.zoneName = '',
    this.stationCount = 0,
  });

  factory ZoneSummary.fromJson(Map<String, dynamic> json) => ZoneSummary(
    zoneId: json['zoneId'] ?? '',
    zoneName: json['zoneName'] ?? '',
    stationCount: json['stationCount'] ?? 0,
  );
}

class SupervisorShift {
  final String uid;
  final String fullName;
  final String email;
  final String mobile;
  final String? shift;

  SupervisorShift({
    required this.uid,
    this.fullName = '',
    this.email = '',
    this.mobile = '',
    this.shift,
  });

  factory SupervisorShift.fromJson(Map<String, dynamic> json) => SupervisorShift(
    uid: json['uid'] ?? '',
    fullName: json['fullName'] ?? '',
    email: json['email'] ?? '',
    mobile: json['mobile'] ?? '',
    shift: json['shift']?.toString().toLowerCase(),
  );
}
