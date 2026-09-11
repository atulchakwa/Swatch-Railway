class StationPlatformAssignment {
  final String platformNumber;
  final String janitorId;
  final String janitorName;
  final String status;
  final String? areaId;
  final String? areaName;

  StationPlatformAssignment({
    required this.platformNumber,
    required this.janitorId,
    required this.janitorName,
    this.status = 'Pending',
    this.areaId,
    this.areaName,
  });

  factory StationPlatformAssignment.fromJson(Map<String, dynamic> json) {
    return StationPlatformAssignment(
      platformNumber: json['platformNumber']?.toString() ?? '',
      janitorId: json['janitorId'] ?? '',
      janitorName: json['janitorName'] ?? '',
      status: json['status'] ?? 'Pending',
      areaId: json['areaId'],
      areaName: json['areaName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platformNumber': platformNumber,
      'janitorId': janitorId,
      'janitorName': janitorName,
      'status': status,
      if (areaId != null) 'areaId': areaId,
      if (areaName != null) 'areaName': areaName,
    };
  }
}

class StationCleaningRunModel {
  String? id;
  String runInstanceId;
  String stationId;
  String stationName;
  String shift;
  String date;
  String status;
  String? frequency;
  List<StationPlatformAssignment> platforms;
  String? supervisorId;
  String? supervisorName;
  String? createdAt;
  String? updatedAt;

  StationCleaningRunModel({
    this.id,
    required this.runInstanceId,
    required this.stationId,
    required this.stationName,
    required this.shift,
    required this.date,
    this.status = 'Pending',
    this.frequency = 'daily',
    this.platforms = const [],
    this.supervisorId,
    this.supervisorName,
    this.createdAt,
    this.updatedAt,
  });

  factory StationCleaningRunModel.fromJson(Map<String, dynamic> json) {
    var platformsList = json['platforms'] as List? ?? [];
    List<StationPlatformAssignment> parsedPlatforms = platformsList
        .map((p) => StationPlatformAssignment.fromJson(p))
        .toList();

    return StationCleaningRunModel(
      id: json['id'],
      runInstanceId: json['runInstanceId'] ?? '',
      stationId: json['stationId'] ?? '',
      stationName: json['stationName'] ?? '',
      shift: json['shift'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'Pending',
      frequency: json['frequency'] ?? 'daily',
      platforms: parsedPlatforms,
      supervisorId: json['supervisorId'],
      supervisorName: json['supervisorName'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'runInstanceId': runInstanceId,
      'stationId': stationId,
      'stationName': stationName,
      'shift': shift,
      'date': date,
      'status': status,
      if (frequency != null) 'frequency': frequency,
      'platforms': platforms.map((p) => p.toJson()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
