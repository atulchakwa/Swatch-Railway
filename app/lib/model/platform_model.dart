class Platform {
  final String? uid;
  final String platformNumber;
  final String? platformName;
  final String stationId;
  final String? stationName;
  final String? surfaceType;
  final double? length;
  final double? width;
  final String? platformArea;
  final String status;
  final String? createdBy;
  final String? createdAt;
  final String? updatedAt;

  Platform({
    this.uid,
    required this.platformNumber,
    this.platformName,
    required this.stationId,
    this.stationName,
    this.surfaceType,
    this.length,
    this.width,
    this.platformArea,
    this.status = 'active',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  String get displayName {
    final base = (platformName != null && platformName!.trim().isNotEmpty)
        ? platformName!
        : 'Platform $platformNumber';
    if (platformArea != null && platformArea!.isNotEmpty) {
      return '$base (${platformArea!})';
    }
    return base;
  }

  factory Platform.fromJson(Map<String, dynamic> json) => Platform(
    uid: json['uid'] ?? json['id'],
    platformNumber: json['platformNumber'] ?? '',
    platformName: json['platformName'],
    stationId: json['stationId'] ?? '',
    stationName: json['stationName'],
    surfaceType: json['surfaceType'],
    length: (json['length'] as num?)?.toDouble(),
    width: (json['width'] as num?)?.toDouble(),
    platformArea: json['platformArea'],
    status: json['status'] ?? 'active',
    createdBy: json['createdBy'],
    createdAt: json['createdAt'],
    updatedAt: json['updatedAt'],
  );

  Map<String, dynamic> toJson() => {
    if (uid != null) 'uid': uid,
    'platformNumber': platformNumber,
    if (platformName != null) 'platformName': platformName,
    'stationId': stationId,
    if (stationName != null) 'stationName': stationName,
    if (surfaceType != null) 'surfaceType': surfaceType,
    if (length != null) 'length': length,
    if (width != null) 'width': width,
    if (platformArea != null) 'platformArea': platformArea,
    'status': status,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Platform &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          platformNumber == other.platformNumber;

  @override
  int get hashCode => uid.hashCode ^ platformNumber.hashCode;
}
