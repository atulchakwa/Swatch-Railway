class RailwayWorkerModel {
  final String uid;
  final String email;
  final String? password;
  final String role;
  final String userType;
  final String fullName;
  final String mobile;
  final String? designation;
  final String? zone;
  final String? division;
  final String? depot;
  final String? entityId;
  final Map<String, dynamic>? entityDetails;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final String? rejectedByName;
  final DateTime? rejectedAt;
  final String status;
  final String? workerType; // 'Janitor' or 'Attendant'
  final List<String>? trainIds;
  final String? stationId;

  RailwayWorkerModel({
    required this.uid,
    required this.email,
    this.password,
    required this.role,
    required this.userType,
    required this.fullName,
    required this.mobile,
    this.designation,
    this.zone,
    this.division,
    this.depot,
    this.entityId,
    this.entityDetails,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.submittedAt,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedByName,
    this.rejectedAt,
    this.status = 'PENDING',
    this.workerType,
    this.trainIds,
    this.stationId,
  });

  factory RailwayWorkerModel.fromJson(Map<String, dynamic> json) {
    return RailwayWorkerModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      password: json['password'] as String?,
      role: json['role'] as String? ?? '',
      userType: json['userType'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      designation: json['designation'] as String?,
      zone: json['zone'] as String?,
      division: json['division'] as String?,
      depot: json['depot'] as String?,
      entityId: json['entityId'] as String?,
      entityDetails: json['entityDetails'] as Map<String, dynamic>?,
      createdBy: json['createdBy'] as String?,
      createdByName: json['createdByName'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      approvedBy: json['approvedBy'] as String?,
      approvedByName: json['approvedByName'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      rejectedBy: json['rejectedBy'] as String?,
      rejectedByName: json['rejectedByName'] as String?,
      rejectedAt: json['rejectedAt'] != null
          ? DateTime.parse(json['rejectedAt'] as String)
          : null,
      status: json['status'] as String? ?? 'PENDING',
      workerType: (json['workerType'] ?? json['worker_type']) as String?,
      trainIds: (json['trainIds'] ?? json['train_ids']) != null
          ? List<String>.from((json['trainIds'] ?? json['train_ids']) as List)
          : null,
      stationId: json['stationId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      if (password != null) 'password': password,
      'role': role,
      'userType': userType,
      'fullName': fullName,
      'mobile': mobile,
      if (designation != null) 'designation': designation,
      if (zone != null) 'zone': zone,
      if (division != null) 'division': division,
      if (depot != null) 'depot': depot,
      if (entityId != null) 'entityId': entityId,
      if (entityDetails != null) 'entityDetails': entityDetails,
      if (createdBy != null) 'createdBy': createdBy,
      if (createdByName != null) 'createdByName': createdByName,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (submittedAt != null) 'submitted_at': submittedAt!.toIso8601String(),
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedByName != null) 'approvedByName': approvedByName,
      if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (rejectedByName != null) 'rejectedByName': rejectedByName,
      if (rejectedAt != null) 'rejectedAt': rejectedAt!.toIso8601String(),
      'status': status,
      if (workerType != null) 'workerType': workerType,
      if (trainIds != null) 'trainIds': trainIds,
      if (stationId != null) 'stationId': stationId,
    };
  }

  RailwayWorkerModel copyWith({
    String? uid,
    String? email,
    String? password,
    String? role,
    String? userType,
    String? fullName,
    String? mobile,
    String? designation,
    String? zone,
    String? division,
    String? depot,
    String? entityId,
    Map<String, dynamic>? entityDetails,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? submittedAt,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    String? rejectedBy,
    String? rejectedByName,
    DateTime? rejectedAt,
    String? status,
    String? workerType,
    List<String>? trainIds,
    String? stationId,
  }) {
    return RailwayWorkerModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      userType: userType ?? this.userType,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      designation: designation ?? this.designation,
      zone: zone ?? this.zone,
      division: division ?? this.division,
      depot: depot ?? this.depot,
      entityId: entityId ?? this.entityId,
      entityDetails: entityDetails ?? this.entityDetails,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedByName: rejectedByName ?? this.rejectedByName,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      status: status ?? this.status,
      workerType: workerType ?? this.workerType,
      trainIds: trainIds ?? this.trainIds,
      stationId: stationId ?? this.stationId,
    );
  }

  // Helper getter for display name in dropdowns
  String get displayName => fullName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RailwayWorkerModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
