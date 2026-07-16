class RailwaySupervisor {
  final String uid;
  final String fullName;
  final String division;
  final String depot;

  RailwaySupervisor({
    required this.uid,
    required this.fullName,
    required this.division,
    required this.depot,
  });

  factory RailwaySupervisor.fromJson(Map<String, dynamic> json) {
    return RailwaySupervisor(
      uid: json['uid'] ?? '',
      fullName: json['fullName'] ?? 'Unknown',
      division: json['division'] ?? '',
      depot: json['depot'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RailwaySupervisor &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
