import 'station_models.dart';

enum AttendanceStatus { present, absent, late, halfDay, onLeave }
enum CaptureMode { biometric, manual, api, autoFlag }
enum DailyActivityStatus { pending, inProgress, completed, partiallyCompleted, rejected, resubmitted, approved }
enum DeficiencyStatus { open, closed, railwayVerified }
enum PlanStatus { draft, submitted, approved, rejected, deleted }
enum ComplaintStatus { reported, assigned, inProgress, resolved, closed, reopened, rejected, escalated, railwayVerified, resubmitted }
enum SupervisorLogStatus { draft, submitted, acknowledged, accepted, returned, rejected }
enum ScorecardStatus { draft, submitted, approved, rejected }
enum PestTreatmentStatus { pendingReview, approved, rejected, followUp, closed }
enum GarbageStatus { recorded, verified, approved, disposed, rejected }
enum MachineDowntimeStatus { open, resolved }
enum InspectionStatus { scheduled, inProgress, completed, approved, rejected }

class StationAttendance {
  final String attendanceId;
  final String stationId;
  final String stationName;
  final String workerId;
  final String workerName;
  final String date;
  final String shift;
  final AttendanceStatus status;
  final CaptureMode captureMode;
  final bool isManual;
  final bool isLate;
  final String photoUrl;
  final String reason;
  final String markedBy;
  final String markedByName;
  final DateTime markedAt;

  StationAttendance({
    required this.attendanceId,
    required this.stationId,
    required this.stationName,
    required this.workerId,
    required this.workerName,
    required this.date,
    required this.shift,
    required this.status,
    required this.captureMode,
    required this.isManual,
    required this.isLate,
    required this.photoUrl,
    required this.reason,
    required this.markedBy,
    required this.markedByName,
    required this.markedAt,
  });

  factory StationAttendance.fromJson(Map<String, dynamic> json) => StationAttendance(
    attendanceId: json['attendanceId'] ?? '',
    stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    workerId: json['workerId'] ?? '',
    workerName: json['workerName'] ?? '',
    date: json['date'] ?? '',
    shift: json['shift'] ?? '',
    status: AttendanceStatus.values.firstWhere(
      (e) => e.name == _toCamelCase(json['status'] ?? 'present'),
      orElse: () => AttendanceStatus.present,
    ),
    captureMode: CaptureMode.values.firstWhere(
      (e) => e.name == _toCamelCase(json['captureMode'] ?? 'manual'),
      orElse: () => CaptureMode.manual,
    ),
    isManual: json['isManual'] ?? true,
    isLate: json['isLate'] ?? false,
    photoUrl: json['photoUrl'] ?? '',
    reason: json['reason'] ?? '',
    markedBy: json['markedBy'] ?? '',
    markedByName: json['markedByName'] ?? '',
    markedAt: json['markedAt'] != null ? DateTime.parse(json['markedAt']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'attendanceId': attendanceId,
    'stationId': stationId,
    'stationName': stationName,
    'workerId': workerId,
    'workerName': workerName,
    'date': date,
    'shift': shift,
    'status': status.name,
    'captureMode': captureMode.name,
    'isManual': isManual,
    'isLate': isLate,
    'photoUrl': photoUrl,
    'reason': reason,
    'markedBy': markedBy,
    'markedByName': markedByName,
    'markedAt': markedAt.toIso8601String(),
  };
}

class DailyActivityRecord {
  final String uid;
  final String stationId;
  final String stationName;
  final String areaId;
  final String areaName;
  final String activityId;
  final String activityName;
  final String date;
  final String shift;
  final String scheduledFrequency;
  final DailyActivityStatus status;
  final String beforePhotoUrl;
  final String afterPhotoUrl;
  final String remarks;
  final String submittedBy;
  final String submittedByName;
  final DateTime? submittedAt;
  final String? verifiedBy;
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final String? resubmissionRemarks;

  DailyActivityRecord({
    required this.uid,
    required this.stationId,
    required this.stationName,
    required this.areaId,
    required this.areaName,
    required this.activityId,
    required this.activityName,
    required this.date,
    required this.shift,
    required this.scheduledFrequency,
    required this.status,
    required this.beforePhotoUrl,
    required this.afterPhotoUrl,
    required this.remarks,
    required this.submittedBy,
    required this.submittedByName,
    this.submittedAt,
    this.verifiedBy,
    this.verifiedByName,
    this.verifiedAt,
    this.rejectionReason,
    this.resubmissionRemarks,
  });

  factory DailyActivityRecord.fromJson(Map<String, dynamic> json) => DailyActivityRecord(
    uid: json['uid'] ?? '',
    stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    areaId: json['areaId'] ?? '',
    areaName: json['areaName'] ?? '',
    activityId: json['activityId'] ?? '',
    activityName: json['activityName'] ?? '',
    date: json['date'] ?? '',
    shift: json['shift'] ?? '',
    scheduledFrequency: json['scheduledFrequency'] ?? '',
    status: DailyActivityStatus.values.firstWhere(
      (e) => e.name == _toCamelCase(json['status'] ?? 'pending'),
      orElse: () => DailyActivityStatus.pending,
    ),
    beforePhotoUrl: json['beforePhotoUrl'] ?? '',
    afterPhotoUrl: json['afterPhotoUrl'] ?? '',
    remarks: json['remarks'] ?? '',
    submittedBy: json['submittedBy'] ?? '',
    submittedByName: json['submittedByName'] ?? '',
    submittedAt: json['submittedAt'] != null ? DateTime.parse(json['submittedAt']) : null,
    verifiedBy: json['verifiedBy'],
    verifiedByName: json['verifiedByName'],
    verifiedAt: json['verifiedAt'] != null ? DateTime.parse(json['verifiedAt']) : null,
    rejectionReason: json['rejectionReason'],
    resubmissionRemarks: json['resubmissionRemarks'],
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'stationId': stationId,
    'stationName': stationName,
    'areaId': areaId,
    'areaName': areaName,
    'activityId': activityId,
    'activityName': activityName,
    'date': date,
    'shift': shift,
    'scheduledFrequency': scheduledFrequency,
    'status': status.name,
    'beforePhotoUrl': beforePhotoUrl,
    'afterPhotoUrl': afterPhotoUrl,
    'remarks': remarks,
    'submittedBy': submittedBy,
    'submittedByName': submittedByName,
    if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
    if (verifiedBy != null) 'verifiedBy': verifiedBy,
    if (verifiedByName != null) 'verifiedByName': verifiedByName,
    if (verifiedAt != null) 'verifiedAt': verifiedAt!.toIso8601String(),
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
    if (resubmissionRemarks != null) 'resubmissionRemarks': resubmissionRemarks,
  };
}

class StationBillingPack {
  final String uid;
  final String contractId;
  final String stationId;
  final String stationName;
  final int month;
  final int year;
  final String contractNumber;
  final String contractorName;
  final int monthlyContractValue;
  final Map<String, dynamic> attendanceSummary;
  final Map<String, dynamic> activitySummary;
  final Map<String, dynamic> scorecardSummary;
  final Map<String, dynamic> complaintSummary;
  final Map<String, dynamic> feedbackSummary;
  final Map<String, dynamic> machineSummary;
  final Map<String, dynamic> penalties;
  final int billableAmount;
  final String status;
  final Map<String, dynamic> complianceChecklist;
  final String generatedBy;
  final String generatedByName;
  final DateTime generatedAt;

  StationBillingPack({
    required this.uid,
    required this.contractId,
    required this.stationId,
    required this.stationName,
    required this.month,
    required this.year,
    required this.contractNumber,
    required this.contractorName,
    required this.monthlyContractValue,
    required this.attendanceSummary,
    required this.activitySummary,
    required this.scorecardSummary,
    required this.complaintSummary,
    required this.feedbackSummary,
    required this.machineSummary,
    required this.penalties,
    required this.billableAmount,
    required this.status,
    required this.complianceChecklist,
    required this.generatedBy,
    required this.generatedByName,
    required this.generatedAt,
  });

  factory StationBillingPack.fromJson(Map<String, dynamic> json) => StationBillingPack(
    uid: json['uid'] ?? '',
    contractId: json['contractId'] ?? '',
    stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    month: json['month'] ?? 1,
    year: json['year'] ?? 2026,
    contractNumber: json['contractNumber'] ?? '',
    contractorName: json['contractorName'] ?? '',
    monthlyContractValue: json['monthlyContractValue'] ?? 0,
    attendanceSummary: json['attendanceSummary'] ?? {},
    activitySummary: json['activitySummary'] ?? {},
    scorecardSummary: json['scorecardSummary'] ?? {},
    complaintSummary: json['complaintSummary'] ?? {},
    feedbackSummary: json['feedbackSummary'] ?? {},
    machineSummary: json['machineSummary'] ?? {},
    penalties: json['penalties'] ?? {},
    billableAmount: json['billableAmount'] ?? 0,
    status: json['status'] ?? 'DRAFT',
    complianceChecklist: json['complianceChecklist'] ?? {},
    generatedBy: json['generatedBy'] ?? '',
    generatedByName: json['generatedByName'] ?? '',
    generatedAt: json['generatedAt'] != null ? DateTime.parse(json['generatedAt']) : DateTime.now(),
  );
}

class StationInspection {
  final String uid;
  final String stationId;
  final String stationName;
  final String? platformId;
  final String? areaId;
  final String inspectionType;
  final String scheduledDate;
  final String inspectorId;
  final String inspectorName;
  final String status;
  final Map<String, dynamic> ratings;
  final int? overallScore;
  final String? grade;
  final String remarks;
  final List<String> photos;
  final List<Deficiency> deficiencies;

  StationInspection({
    required this.uid,
    required this.stationId,
    required this.stationName,
    this.platformId,
    this.areaId,
    required this.inspectionType,
    required this.scheduledDate,
    required this.inspectorId,
    required this.inspectorName,
    required this.status,
    required this.ratings,
    this.overallScore,
    this.grade,
    required this.remarks,
    required this.photos,
    required this.deficiencies,
  });

  factory StationInspection.fromJson(Map<String, dynamic> json) => StationInspection(
    uid: json['uid'] ?? '',
    stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    platformId: json['platformId'],
    areaId: json['areaId'],
    inspectionType: json['inspectionType'] ?? 'daily',
    scheduledDate: json['scheduledDate'] ?? '',
    inspectorId: json['inspectorId'] ?? '',
    inspectorName: json['inspectorName'] ?? '',
    status: json['status'] ?? '',
    ratings: json['ratings'] ?? {},
    overallScore: json['overallScore'],
    grade: json['grade'],
    remarks: json['remarks'] ?? '',
    photos: List<String>.from(json['photos'] ?? []),
    deficiencies: (json['deficiencies'] as List?)?.map((e) => Deficiency.fromJson(e)).toList() ?? [],
  );
}

class Deficiency {
  final String defId;
  final String area;
  final String description;
  final String severity;
  final String? assignedTo;
  final String assignedToName;
  final DeficiencyStatus closureStatus;
  final String? closureProof;
  final String? closureRemarks;
  final DateTime? closedAt;
  final String? closedBy;

  Deficiency({
    required this.defId,
    required this.area,
    required this.description,
    required this.severity,
    this.assignedTo,
    required this.assignedToName,
    required this.closureStatus,
    this.closureProof,
    this.closureRemarks,
    this.closedAt,
    this.closedBy,
  });

  factory Deficiency.fromJson(Map<String, dynamic> json) => Deficiency(
    defId: json['defId'] ?? '',
    area: json['area'] ?? '',
    description: json['description'] ?? '',
    severity: json['severity'] ?? 'medium',
    assignedTo: json['assignedTo'],
    assignedToName: json['assignedToName'] ?? '',
    closureStatus: DeficiencyStatus.values.firstWhere(
      (e) => e.name == _toCamelCase(json['closureStatus'] ?? 'open'),
      orElse: () => DeficiencyStatus.open,
    ),
    closureProof: json['closureProof'],
    closureRemarks: json['closureRemarks'],
    closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt']) : null,
    closedBy: json['closedBy'],
  );
}

class ExecutionPlan {
  final String uid;
  final String contractId;
  final String stationId;
  final int month;
  final int year;
  final String status;
  final Map<String, dynamic> shiftPlan;
  final Map<String, dynamic> manpowerPlan;
  final Map<String, dynamic> machinePlan;
  final List<dynamic> materialPlan;
  final Map<String, dynamic> garbageDisposalPlan;
  final List<dynamic> weeklySchedule;
  final int version;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? submittedBy;
  final String? approvedBy;
  final String? rejectedBy;
  final String? rejectionReason;

  ExecutionPlan({
    required this.uid, required this.contractId, required this.stationId,
    required this.month, required this.year, required this.status,
    required this.shiftPlan, required this.manpowerPlan,
    required this.machinePlan, required this.materialPlan,
    required this.garbageDisposalPlan, required this.weeklySchedule,
    required this.version, required this.createdBy, required this.createdByName,
    required this.createdAt, required this.updatedAt,
    this.submittedBy, this.approvedBy, this.rejectedBy, this.rejectionReason,
  });

  factory ExecutionPlan.fromJson(Map<String, dynamic> json) => ExecutionPlan(
    uid: json['uid'] ?? '', contractId: json['contractId'] ?? '',
    stationId: json['stationId'] ?? '', month: json['month'] ?? 1,
    year: json['year'] ?? 2026, status: json['status'] ?? 'DRAFT',
    shiftPlan: json['shiftPlan'] ?? {},
    manpowerPlan: json['manpowerPlan'] ?? {},
    machinePlan: json['machinePlan'] ?? {},
    materialPlan: json['materialPlan'] ?? [],
    garbageDisposalPlan: json['garbageDisposalPlan'] ?? {},
    weeklySchedule: json['weeklySchedule'] ?? [],
    version: json['version'] ?? 1,
    createdBy: json['createdBy'] ?? '',
    createdByName: json['createdByName'] ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    submittedBy: json['submittedBy'], approvedBy: json['approvedBy'],
    rejectedBy: json['rejectedBy'], rejectionReason: json['rejectionReason'],
  );
}

class ExecutionLog {
  final String uid;
  final String stationId;
  final String date;
  final String shift;
  final String status;
  final int plannedManpower;
  final int actualManpower;
  final int variance;
  final String reasonForVariance;
  final Map<String, dynamic> machinesDeployed;
  final List<dynamic> materialUsed;
  final Map<String, dynamic> garbageCollected;
  final List<dynamic> issuesEncountered;
  final List<dynamic> unresolvedWork;
  final String handoverNotes;
  final String createdBy;
  final DateTime createdAt;

  ExecutionLog({
    required this.uid, required this.stationId, required this.date,
    required this.shift, required this.status,
    required this.plannedManpower, required this.actualManpower,
    required this.variance, required this.reasonForVariance,
    required this.machinesDeployed, required this.materialUsed,
    required this.garbageCollected, required this.issuesEncountered,
    required this.unresolvedWork, required this.handoverNotes,
    required this.createdBy, required this.createdAt,
  });

  factory ExecutionLog.fromJson(Map<String, dynamic> json) => ExecutionLog(
    uid: json['uid'] ?? '', stationId: json['stationId'] ?? '',
    date: json['date'] ?? '', shift: json['shift'] ?? '',
    status: json['status'] ?? '',
    plannedManpower: json['plannedManpower'] ?? 0,
    actualManpower: json['actualManpower'] ?? 0,
    variance: json['variance'] ?? 0,
    reasonForVariance: json['reasonForVariance'] ?? '',
    machinesDeployed: json['machinesDeployed'] ?? {},
    materialUsed: json['materialUsed'] ?? [],
    garbageCollected: json['garbageCollected'] ?? {},
    issuesEncountered: json['issuesEncountered'] ?? [],
    unresolvedWork: json['unresolvedWork'] ?? [],
    handoverNotes: json['handoverNotes'] ?? '',
    createdBy: json['createdBy'] ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

class EvidenceMetadata {
  final String uid;
  final String stationId;
  final String evidenceType;
  final String uploadedBy;
  final String uploadedByName;
  final String url;
  final String? thumbnailUrl;
  final int originalSize;
  final int? compressedSize;
  final String mimeType;
  final bool archived;
  final DateTime uploadedAt;

  EvidenceMetadata({
    required this.uid, required this.stationId, required this.evidenceType,
    required this.uploadedBy, required this.uploadedByName,
    required this.url, this.thumbnailUrl,
    required this.originalSize, this.compressedSize,
    required this.mimeType, required this.archived,
    required this.uploadedAt,
  });

  factory EvidenceMetadata.fromJson(Map<String, dynamic> json) => EvidenceMetadata(
    uid: json['uid'] ?? '', stationId: json['stationId'] ?? '',
    evidenceType: json['evidenceType'] ?? '',
    uploadedBy: json['uploadedBy'] ?? '',
    uploadedByName: json['uploadedByName'] ?? '',
    url: json['url'] ?? '', thumbnailUrl: json['thumbnailUrl'],
    originalSize: json['originalSize'] ?? 0,
    compressedSize: json['compressedSize'],
    mimeType: json['mimeType'] ?? '',
    archived: json['archived'] ?? false,
    uploadedAt: json['uploadedAt'] != null ? DateTime.parse(json['uploadedAt']) : DateTime.now(),
  );
}

class SupervisorLog {
  final String uid;
  final String stationId;
  final String stationName;
  final String date;
  final String shift;
  final String status;
  final String supervisorName;
  final List<dynamic> issues;
  final List<dynamic> materialUsed;
  final List<dynamic> machinesDeployed;
  final List<dynamic> photos;
  final String handoverNotes;
  final String createdBy;
  final String? acknowledgedBy;
  final String? acceptedBy;
  final String? rejectionReason;
  final DateTime createdAt;

  SupervisorLog({
    required this.uid, required this.stationId, required this.stationName,
    required this.date, required this.shift, required this.status,
    required this.supervisorName, required this.issues,
    required this.materialUsed, required this.machinesDeployed,
    required this.photos, required this.handoverNotes,
    required this.createdBy, this.acknowledgedBy, this.acceptedBy,
    this.rejectionReason, required this.createdAt,
  });

  factory SupervisorLog.fromJson(Map<String, dynamic> json) => SupervisorLog(
    uid: json['uid'] ?? '', stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    date: json['date'] ?? '', shift: json['shift'] ?? '',
    status: json['status'] ?? '',
    supervisorName: json['supervisorName'] ?? '',
    issues: json['issues'] ?? [],
    materialUsed: json['materialUsed'] ?? [],
    machinesDeployed: json['machinesDeployed'] ?? [],
    photos: json['photos'] ?? [],
    handoverNotes: json['handoverNotes'] ?? '',
    createdBy: json['createdBy'] ?? '',
    acknowledgedBy: json['acknowledgedBy'],
    acceptedBy: json['acceptedBy'],
    rejectionReason: json['rejectionReason'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

class Complaint {
  final String uid;
  final String stationId;
  final String category;
  final String description;
  final String status;
  final String reportedBy;
  final String reportedByName;
  final String? assignedTo;
  final String? assignedToName;
  final String? resolution;
  final String? rejectionReason;
  final String? escalatedTo;
  final String? slaDeadline;
  final bool slaBreached;
  final int reopenedCount;
  final DateTime createdAt;

  Complaint({
    required this.uid, required this.stationId, required this.category,
    required this.description, required this.status,
    required this.reportedBy, required this.reportedByName,
    this.assignedTo, this.assignedToName, this.resolution,
    this.rejectionReason, this.escalatedTo, this.slaDeadline,
    required this.slaBreached, required this.reopenedCount,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
    uid: json['uid'] ?? '', stationId: json['stationId'] ?? '',
    category: json['category'] ?? '',
    description: json['description'] ?? '',
    status: _toCamelCase((json['status'] ?? '').toString()),
    reportedBy: json['reportedBy'] ?? '',
    reportedByName: json['reportedByName'] ?? '',
    assignedTo: json['assignedTo'], assignedToName: json['assignedToName'],
    resolution: json['resolution'], rejectionReason: json['rejectionReason'],
    escalatedTo: json['escalatedTo'], slaDeadline: json['slaDeadline'],
    slaBreached: json['slaBreached'] ?? false,
    reopenedCount: json['reopenedCount'] ?? 0,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

class PestTreatment {
  final String uid;
  final String stationId;
  final String treatmentType;
  final DateTime scheduledDate;
  final String? chemicalUsed;
  final double? quantityUsed;
  final String? frequency;
  final DateTime? nextDueDate;
  final String status;
  final String createdBy;
  final String? reviewedBy;
  final String? reviewRemarks;
  final DateTime createdAt;

  PestTreatment({
    required this.uid, required this.stationId, required this.treatmentType,
    required this.scheduledDate, this.chemicalUsed, this.quantityUsed,
    this.frequency, this.nextDueDate, required this.status,
    required this.createdBy, this.reviewedBy, this.reviewRemarks,
    required this.createdAt,
  });

  factory PestTreatment.fromJson(Map<String, dynamic> json) => PestTreatment(
    uid: json['uid'] ?? '', stationId: json['stationId'] ?? '',
    treatmentType: json['treatmentMethod'] ?? json['treatmentType'] ?? '',
    scheduledDate: json['scheduledDate'] != null ? DateTime.parse(json['scheduledDate']) : DateTime.now(),
    chemicalUsed: json['chemicalUsed'] ?? (json['chemicalIds'] is List ? (json['chemicalIds'] as List).join(', ') : null),
    quantityUsed: json['quantityUsed'],
    frequency: json['frequency'], nextDueDate: json['nextDueDate'] != null ? DateTime.parse(json['nextDueDate']) : null,
    status: json['status'] ?? '',
    createdBy: json['createdBy'] ?? '',
    reviewedBy: json['reviewedBy'], reviewRemarks: json['reviewNotes'] ?? json['reviewRemarks'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

class MachineDeployment {
  final String uid;
  final String machineId;
  final String machineName;
  final String stationId;
  final String deployedAt;
  final String? returnedAt;
  final String condition;
  final String status;
  final String deployedBy;

  MachineDeployment({
    required this.uid, required this.machineId, required this.machineName,
    required this.stationId, required this.deployedAt, this.returnedAt,
    required this.condition, required this.status, required this.deployedBy,
  });

  factory MachineDeployment.fromJson(Map<String, dynamic> json) => MachineDeployment(
    uid: json['uid'] ?? '', machineId: json['machineId'] ?? '',
    machineName: json['machineName'] ?? '',
    stationId: json['stationId'] ?? '',
    deployedAt: json['deployedAt'] ?? '',
    returnedAt: json['returnedAt'], condition: json['condition'] ?? '',
    status: json['status'] ?? '', deployedBy: json['deployedBy'] ?? '',
  );
}

class MachineDowntime {
  final String uid;
  final String machineId;
  final String machineName;
  final String stationId;
  final String reason;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalHours;
  final double penaltyAmount;
  final String status;
  final String loggedBy;

  MachineDowntime({
    required this.uid, required this.machineId, required this.machineName,
    required this.stationId, required this.reason, required this.startTime,
    this.endTime, required this.totalHours, required this.penaltyAmount,
    required this.status, required this.loggedBy,
  });

  factory MachineDowntime.fromJson(Map<String, dynamic> json) => MachineDowntime(
    uid: json['uid'] ?? '', machineId: json['machineId'] ?? '',
    machineName: json['machineName'] ?? '',
    stationId: json['stationId'] ?? '', reason: json['reason'] ?? '',
    startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : DateTime.now(),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    totalHours: (json['totalDowntimeHours'] ?? json['totalHours'] ?? 0).toDouble(),
    penaltyAmount: (json['penaltyAmount'] ?? 0).toDouble(),
    status: json['status'] ?? 'OPEN', loggedBy: json['loggedBy'] ?? '',
  );
}

class MachineMaintenance {
  final String uid;
  final String machineId;
  final String machineName;
  final String stationId;
  final String maintenanceType;
  final String scheduledDate;
  final String? completedDate;
  final String status;
  final String? remarks;

  MachineMaintenance({
    required this.uid, required this.machineId, required this.machineName,
    required this.stationId, required this.maintenanceType,
    required this.scheduledDate, this.completedDate,
    required this.status, this.remarks,
  });

  factory MachineMaintenance.fromJson(Map<String, dynamic> json) => MachineMaintenance(
    uid: json['uid'] ?? '', machineId: json['machineId'] ?? '',
    machineName: json['machineName'] ?? '',
    stationId: json['stationId'] ?? '',
    maintenanceType: json['maintenanceType'] ?? '',
    scheduledDate: json['scheduledDate'] ?? '',
    completedDate: json['completedDate'], status: json['status'] ?? '',
    remarks: json['remarks'],
  );
}

class GarbageCollection {
  final String uid;
  final String stationId;
  final String collectionDate;
  final double wetKg;
  final double dryKg;
  final double hazardousKg;
  final String status;
  final String collectedBy;
  final String? verifiedBy;
  final String? disposalAgency;
  final String? vehicleNumber;
  final DateTime createdAt;

  GarbageCollection({
    required this.uid, required this.stationId, required this.collectionDate,
    required this.wetKg, required this.dryKg, required this.hazardousKg,
    required this.status, required this.collectedBy, this.verifiedBy,
    this.disposalAgency, this.vehicleNumber, required this.createdAt,
  });

  factory GarbageCollection.fromJson(Map<String, dynamic> json) => GarbageCollection(
    uid: json['uid'] ?? '', stationId: json['stationId'] ?? '',
    collectionDate: json['collectionDate'] ?? '',
    wetKg: (json['wetKg'] ?? 0).toDouble(), dryKg: (json['dryKg'] ?? 0).toDouble(),
    hazardousKg: (json['hazardousKg'] ?? 0).toDouble(),
    status: json['status'] ?? '',
    collectedBy: json['collectedBy'] ?? '', verifiedBy: json['verifiedBy'],
    disposalAgency: json['disposalAgency'], vehicleNumber: json['vehicleNumber'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

class Scorecard {
  final String uid;
  final String stationId;
  final String date;
  final int overallStationScore;
  final String? grade;
  final Map<String, dynamic> parameters;
  final String status;
  final bool certified;
  final String? certifiedBy;
  final Map<String, dynamic>? inspectionSummary;

  Scorecard({
    required this.uid, required this.stationId, required this.date,
    required this.overallStationScore, this.grade,
    required this.parameters, required this.status,
    required this.certified, this.certifiedBy, this.inspectionSummary,
  });

  factory Scorecard.fromJson(Map<String, dynamic> json) => Scorecard(
    uid: json['uid'] ?? '', stationId: json['stationId'] ?? '',
    date: json['date'] ?? '',
    overallStationScore: json['overallStationScore'] ?? 0,
    grade: json['grade'], parameters: json['parameters'] ?? {},
    status: json['status'] ?? '',
    certified: json['certified'] ?? false,
    certifiedBy: json['certifiedBy'],
    inspectionSummary: json['inspectionSummary'],
  );
}

class StationReport {
  final String uid;
  final String stationId;
  final String stationName;
  final String reportType;
  final String date;
  final int month;
  final int year;
  final Map<String, dynamic> summary;
  final String generatedBy;
  final String generatedByName;
  final DateTime generatedAt;

  StationReport({
    required this.uid, required this.stationId, required this.stationName,
    required this.reportType, required this.date,
    required this.month, required this.year,
    required this.summary, required this.generatedBy,
    required this.generatedByName, required this.generatedAt,
  });

  factory StationReport.fromJson(Map<String, dynamic> json) => StationReport(
    uid: json['uid'] ?? '', stationId: json['stationId'] ?? '',
    stationName: json['stationName'] ?? '',
    reportType: json['reportType'] ?? '',
    date: json['date'] ?? '',
    month: json['month'] ?? 0, year: json['year'] ?? 0,
    summary: json['summary'] ?? {},
    generatedBy: json['generatedBy'] ?? '',
    generatedByName: json['generatedByName'] ?? '',
    generatedAt: json['generatedAt'] != null ? DateTime.parse(json['generatedAt']) : DateTime.now(),
  );
}

class DashboardKpis {
  final int averageScore;
  final int attendanceRate;
  final double averageFeedback;
  final int openComplaints;
  final int inMaintenance;
  final int activityCompletionRate;
  final int plannedVsActual;
  final int missedAlerts;
  final int billingReady;
  final int reportsSent;
  final Map<String, dynamic> raw;

  DashboardKpis({
    required this.averageScore, required this.attendanceRate,
    required this.averageFeedback, required this.openComplaints,
    required this.inMaintenance, required this.activityCompletionRate,
    required this.plannedVsActual, required this.missedAlerts,
    required this.billingReady, required this.reportsSent,
    required this.raw,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) => DashboardKpis(
    averageScore: json['scorecard']?['averageScore'] ?? 0,
    attendanceRate: json['attendance']?['attendanceRate'] ?? 0,
    averageFeedback: (json['feedback']?['averageRating'] ?? 0).toDouble(),
    openComplaints: json['complaints']?['open'] ?? 0,
    inMaintenance: json['machines']?['inMaintenance'] ?? 0,
    activityCompletionRate: json['activities']?['completionRate'] ?? 0,
    plannedVsActual: json['plannedVsCompleted']?['variance'] ?? 0,
    missedAlerts: json['missedAlerts']?['count'] ?? 0,
    billingReady: json['billingReadiness']?['ready'] ?? 0,
    reportsSent: json['reportsSent']?['count'] ?? 0,
    raw: json,
  );
}

class WorkforceDeployment {
  final String uid;
  final String workerId;
  final String workerName;
  final String stationId;
  final String? platformId;
  final String? areaId;
  final String taskId;
  final String shiftId;
  final String? shiftType;
  final String? supervisorId;
  final String? supervisorName;
  final String startDate;
  final String? endDate;
  final String status;

  WorkforceDeployment({
    required this.uid,
    required this.workerId,
    required this.workerName,
    required this.stationId,
    this.platformId,
    this.areaId,
    required this.taskId,
    required this.shiftId,
    this.shiftType,
    this.supervisorId,
    this.supervisorName,
    required this.startDate,
    this.endDate,
    required this.status,
  });

  factory WorkforceDeployment.fromJson(Map<String, dynamic> json) => WorkforceDeployment(
    uid: json['uid'] ?? '',
    workerId: json['workerId'] ?? '',
    workerName: json['workerName'] ?? '',
    stationId: json['stationId'] ?? '',
    platformId: json['platformId'],
    areaId: json['areaId'],
    taskId: json['taskId'] ?? '',
    shiftId: json['shiftId'] ?? '',
    shiftType: json['shiftType'],
    supervisorId: json['supervisorId'],
    supervisorName: json['supervisorName'],
    startDate: json['startDate'] ?? '',
    endDate: json['endDate'],
    status: json['status'] ?? 'active',
  );
}

String _toCamelCase(String text) {
  final parts = text.split('_');
  if (parts.isEmpty) return '';
  final buffer = StringBuffer(parts[0].toLowerCase());
  for (var i = 1; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    buffer.write(parts[i][0].toUpperCase());
    buffer.write(parts[i].substring(1).toLowerCase());
  }
  return buffer.toString();
}
