class ContractModel {
  String uid;
  String? contractNumber;
  String? contractName;
  String? entityId;
  String? entityName;
  String? zone;
  String? division;
  String? depot;
  List<String> stationIds;
  List<String> stationNames;
  List<String> trainIds;
  List<String> trainNames;
  String? startDate;
  String? endDate;
  String? contractDuration;
  double contractValue;
  String? workCategories;
  String? remarks;
  String? status;
  String? billingCycle;
  String? contractType;
  bool scoringApplicability;

  String? repName;
  String? repDesignation;
  String? repMobile;
  String? repEmail;
  String? repIdProofType;
  String? repIdProofNumber;

  bool? isActive;

  DateTime? createdAt;
  String? createdBy;
  String? createdByName;
  DateTime? updatedAt;
  String? updatedBy;
  String? updatedByName;

  ContractModel({
    required this.uid,
    this.contractNumber,
    this.contractName,
    this.entityId,
    this.entityName,
    this.zone,
    this.division,
    this.depot,
    this.stationIds = const [],
    this.stationNames = const [],
    this.trainIds = const [],
    this.trainNames = const [],
    this.startDate,
    this.endDate,
    this.contractDuration,
    this.contractValue = 0,
    this.workCategories,
    this.remarks,
    this.status,
    this.billingCycle,
    this.contractType,
    this.scoringApplicability = true,
    this.repName,
    this.repDesignation,
    this.repMobile,
    this.repEmail,
    this.repIdProofType,
    this.repIdProofNumber,
    this.isActive,
    this.createdAt,
    this.createdBy,
    this.createdByName,
    this.updatedAt,
    this.updatedBy,
    this.updatedByName,
  });

  factory ContractModel.fromJson(Map<String, dynamic> json) {
    DateTime? _parseTimestamp(dynamic ts) {
      if (ts == null) return null;

      if (ts is Map<String, dynamic> && ts['_seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(ts['_seconds'] * 1000);
      }

      if (ts is String) {
        try {
          return DateTime.parse(ts);
        } catch (e) {
          return null;
        }
      }

      return null;
    }

    String? _str(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      if (v is List) return v.map((e) => e.toString()).join(', ');
      return v.toString();
    }

    final rep = json['representative'] is Map ? json['representative'] as Map<String, dynamic> : {};

    final statusValue = (json['status'] ?? '').toString().toLowerCase();
    final bool isActiveValue = statusValue == 'active';

    List<String> _stringList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];

    final stations = _stringList(json['stationIds']);
    final stNames = _stringList(json['stationNames']);
    final trains = _stringList(json['trainIds']);
    final trNames = _stringList(json['trainNames']);

    return ContractModel(
      uid: json['uid'] ?? '',
      contractNumber: _str(json['contractNumber']),
      contractName: _str(json['contractName']),
      entityId: _str(json['entityId']),
      entityName: _str(json['entityName']),
      zone: _str(json['zone']),
      division: _str(json['division']),
      depot: _str(json['depot']),
      stationIds: stations,
      stationNames: stNames,
      trainIds: trains,
      trainNames: trNames,
      startDate: _str(json['startDate']),
      endDate: _str(json['endDate']),
      contractDuration: _str(json['contractDuration']),
      contractValue: (json['contractValue'] ?? 0).toDouble(),
      workCategories: _str(json['workCategories']),
      remarks: _str(json['remarks']),
      status: _str(json['status']),
      billingCycle: _str(json['billingCycle']),
      contractType: _str(json['contractType']),
      scoringApplicability: json['scoringApplicability'] ?? true,

      repName: _str(json['repName']) ?? _str(rep['name']),
      repDesignation: _str(json['repDesignation']) ?? _str(rep['designation']),
      repMobile: _str(json['repMobile']) ?? _str(rep['mobile']),
      repEmail: _str(json['repEmail']) ?? _str(rep['email']),
      repIdProofType: _str(json['repIdProofType']) ?? _str(rep['idProofType']),
      repIdProofNumber: _str(json['repIdProofNumber']) ?? _str(rep['idProofNumber']),

      isActive: isActiveValue,

      createdAt: _parseTimestamp(json['createdAt']),
      createdBy: _str(json['createdBy']),
      createdByName: _str(json['createdByName']),
      updatedAt: _parseTimestamp(json['updatedAt']),
      updatedBy: _str(json['updatedBy']),
      updatedByName: _str(json['updatedByName']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'contractNumber': contractNumber,
      'contractName': contractName,
      'entityId': entityId,
      'entityName': entityName,
      'zone': zone,
      'division': division,
      'depot': depot,
      'stationIds': stationIds,
      'stationNames': stationNames,
      'trainIds': trainIds,
      'trainNames': trainNames,
      'startDate': startDate,
      'endDate': endDate,
      'contractDuration': contractDuration,
      'contractValue': contractValue,
      'workCategories': workCategories,
      'remarks': remarks,
      'status': status,
      'billingCycle': billingCycle,
      'contractType': contractType,
      'scoringApplicability': scoringApplicability,

      'repName': repName,
      'repDesignation': repDesignation,
      'repMobile': repMobile,
      'repEmail': repEmail,
      'repIdProofType': repIdProofType,
      'repIdProofNumber': repIdProofNumber,

      'isActive': isActive,

      'createdAt': createdAt?.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
      'updatedByName': updatedByName,
    };
  }
}

class Contract {
  String uid;
  String? contractNo;
  String? contractName;
  String entity;
  String zone;
  String division;
  String? depot;
  List<String> workCategories;
  String status;
  String? remarks;
  DateTime? startDate;
  DateTime? endDate;
  bool isActive;

  Contract({
    required this.uid,
    this.contractNo,
    this.contractName,
    required this.entity,
    required this.zone,
    required this.division,
    this.depot,
    this.workCategories = const [],
    this.status = 'Active',
    this.remarks,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });
}