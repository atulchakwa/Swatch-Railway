import 'station_feedback_model.dart';

class PassengerFeedback {
  final String? uid;
  final String stationId;
  final String stationName;
  final String pnr;
  final String passengerName;
  final String passengerPhone;
  final String journeyDate;
  final Map<String, String> ratings;
  final double overallRating;
  final double overallScore;
  final String overallGrade;
  final bool isNegative;
  final String comments;
  final Map<String, dynamic>? takenBy;
  final String status;
  final String date;
  final String createdAt;

  PassengerFeedback({
    this.uid,
    required this.stationId,
    this.stationName = '',
    this.pnr = '',
    this.passengerName = '',
    this.passengerPhone = '',
    this.journeyDate = '',
    this.ratings = const {},
    this.overallRating = 0,
    this.overallScore = 0,
    this.overallGrade = '',
    this.isNegative = false,
    this.comments = '',
    this.takenBy,
    this.status = '',
    this.date = '',
    this.createdAt = '',
  });

  factory PassengerFeedback.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['ratings'] is Map ? (json['ratings'] as Map) : <dynamic, dynamic>{};
    final ratings = <String, String>{};
    rawRatings.forEach((k, v) => ratings[k.toString()] = v.toString());
    return PassengerFeedback(
      uid: json['uid'],
      stationId: json['stationId'] ?? '',
      stationName: json['stationName'] ?? '',
      pnr: json['pnr'] ?? '',
      passengerName: json['passengerName'] ?? '',
      passengerPhone: json['passengerPhone'] ?? '',
      journeyDate: json['journeyDate'] ?? '',
      ratings: ratings,
      overallRating: (json['overallRating'] as num?)?.toDouble() ?? 0,
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
      overallGrade: json['overallGrade'] ?? '',
      isNegative: json['isNegative'] ?? false,
      comments: json['comments'] ?? '',
      takenBy: json['takenBy'] is Map ? Map<String, dynamic>.from(json['takenBy'] as Map) : null,
      status: json['status'] ?? '',
      date: json['date'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }

  int get ratedCount => ratings.length;

  String get takenByName {
    final name = takenBy?['name']?.toString() ?? '';
    final role = takenBy?['role']?.toString() ?? '';
    if (name.isEmpty) return role;
    return role.isNotEmpty ? '$name ($role)' : name;
  }
}

class PassengerFeedbackSummary {
  final String stationId;
  final int totalFeedback;
  final double averageRating;
  final int negativeCount;
  final int positiveCount;
  final int uniquePnrCount;
  final Map<String, CategoryBreakdown> categoryBreakdown;

  PassengerFeedbackSummary({
    required this.stationId,
    required this.totalFeedback,
    required this.averageRating,
    required this.negativeCount,
    required this.positiveCount,
    required this.uniquePnrCount,
    required this.categoryBreakdown,
  });

  factory PassengerFeedbackSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = <String, CategoryBreakdown>{};
    if (json['categoryBreakdown'] is Map) {
      (json['categoryBreakdown'] as Map).forEach((key, val) {
        breakdown[key.toString()] = CategoryBreakdown.fromJson(val);
      });
    }
    return PassengerFeedbackSummary(
      stationId: json['stationId'] ?? '',
      totalFeedback: json['totalFeedback'] ?? 0,
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      negativeCount: json['negativeCount'] ?? 0,
      positiveCount: json['positiveCount'] ?? 0,
      uniquePnrCount: json['uniquePnrCount'] ?? 0,
      categoryBreakdown: breakdown,
    );
  }
}