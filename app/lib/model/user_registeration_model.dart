import 'package:crm_train/model/user_entity_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

class UserRegistrationModel {
  final String uid;

  final String? fullName;
  final String? email;
  final String? mobile;
  final String? role;
  final String? userType;
  final String? designation;

  final String? entityId;
  final EntityModel? entityDetails;
  final String? contractId;
  final String? contractType;
  final String? domain;
  final List<String> stations;

  final String? zone;
  final String? division;
  final String? depot;
  final String? status;
  final String? stationId;
  final String? areaId;
  final String? platformId;


  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? updatedAt;
  final DateTime? suspendedAt;
  final DateTime? rejectedAt;


  final String? createdBy;
  final String? approvedBy;
  final String? updatedBy;
  final String? suspendedBy;
  final String? rejectedBy;


  final String? createdByName;
  final String? approvedByName;
  final String? updatedByName;
  final String? suspendedByName;
  final String? rejectedByName;

  final List<AuditLog>? auditLogs;

  UserRegistrationModel({
    required this.uid,
    this.fullName,
    this.email,
    this.mobile,
    this.role,
    this.userType,
    this.designation,
    this.entityId,
    this.entityDetails,
    this.contractId,
    this.contractType,
    this.domain,
    this.stations = const [],
    this.zone,
    this.division,
    this.depot,
    this.status,
    this.stationId,
    this.areaId,
    this.platformId,
    this.createdAt,
    this.submittedAt,
    this.approvedAt,
    this.updatedAt,
    this.suspendedAt,
    this.rejectedAt,
    this.createdBy,
    this.approvedBy,
    this.updatedBy,
    this.suspendedBy,
    this.rejectedBy,
    this.createdByName,
    this.approvedByName,
    this.updatedByName,
    this.suspendedByName,
    this.rejectedByName,
    this.auditLogs,
  });

  factory UserRegistrationModel.fromJson(Map<String, dynamic> json) {
    return UserRegistrationModel(
      uid: json['uid'] ?? '',

      fullName: json['fullName'],
      email: json['email'],
      mobile: json['mobile'],
      role: json['role'],
      userType: json['userType'],
      designation: json['designation'],

      entityId: json['entityId'] ?? json['entityID'],
      entityDetails: json['entityDetails'] != null
          ? EntityModel.fromJson(Map<String, dynamic>.from(json['entityDetails']))
          : null,
      contractId: json['contractId'],
      contractType: json['contractType'],
      domain: json['domain'],
      stations: (json['stations'] as List?)?.cast<String>() ?? [],

      zone: json['zone'],
      division: json['division'],
      depot: json['depot'],
      status: json['status'],
      stationId: json['stationId'],
      areaId: json['areaId'],
      platformId: json['platformId'],

      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      submittedAt: _parseDateTime(json['submittedAt'] ?? json['submitted_at']),
      approvedAt: _parseDateTime(json['approvedAt'] ?? json['approved_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
      suspendedAt: _parseDateTime(json['suspendedAt'] ?? json['suspended_at']),
      rejectedAt: _parseDateTime(json['rejectedAt'] ?? json['rejected_at']),


      createdBy: json['createdBy'],
      approvedBy: json['approvedBy'],
      updatedBy: json['updatedBy'],
      suspendedBy: json['suspendedBy'],
      rejectedBy: json['rejectedBy'],


      createdByName: json['createdByName'],
      approvedByName: json['approvedByName'],
      updatedByName: json['updatedByName'],
      suspendedByName: json['suspendedByName'],
      rejectedByName: json['rejectedByName'],

      auditLogs: (json['auditLogs'] as List?)
          ?.map((e) => AuditLog.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      try {
        final parsed = DateTime.parse(value);
        return parsed.toLocal();
      } catch (e) {
        debugPrint(' $e');
      }

      try {
        final format = DateFormat('dd/MM/yy, h:mm a');
        final parsed = format.parse(value);
        return parsed;
      } catch (e) {
        debugPrint(' $e');
      }

      try {
        final format = DateFormat('dd/MM/yy, HH:mm');
        final parsed = format.parse(value);
        return parsed;
      } catch (e) {
        debugPrint(' $e');
      }

      return null;
    }

    if (value is Map && value['_seconds'] != null) {
      final seconds = value['_seconds'];
      final parsed = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ).toLocal();
      return parsed;
    }
    return null;
  }
}
