import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class DailyActivityRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> create(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/station-activities'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to create daily activity');
    }
  }

  static Future<List<DailyActivityRecord>> list(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/station-activities').replace(queryParameters: query);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List list = body['activities'] ?? [];
      return list.map<DailyActivityRecord>((e) => DailyActivityRecord.fromJson(e)).toList();
    }
    throw Exception('Failed to load activities');
  }

  static Future<DailyActivityRecord> getById(String uid) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/station-activities/$uid'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return DailyActivityRecord.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load activity details');
  }

  static Future<void> updateStatus(String uid, String status, {String? beforePhotoUrl, String? afterPhotoUrl, String? remarks, String? rejectionReason, String? resubmissionRemarks}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/station-activities/$uid/status'),
      headers: await _headers(),
      body: jsonEncode({
        'status': status,
        if (beforePhotoUrl != null) 'beforePhotoUrl': beforePhotoUrl,
        if (afterPhotoUrl != null) 'afterPhotoUrl': afterPhotoUrl,
        if (remarks != null) 'remarks': remarks,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (resubmissionRemarks != null) 'resubmissionRemarks': resubmissionRemarks,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed status update');
    }
  }

  static Future<List<Map<String, dynamic>>> getMissed(String stationId, String date, {String? shift}) async {
    final uri = Uri.parse('$baseUrl/api/station-activities/missed').replace(
      queryParameters: {
        'stationId': stationId,
        'date': date,
        if (shift != null) 'shift': shift,
      },
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List list = body['missed'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load missed activities');
  }

  static Future<List<DailyActivityRecord>> getPending(String stationId, String date, {String? shift, String? workerId}) async {
    final uri = Uri.parse('$baseUrl/api/station-activities/pending').replace(
      queryParameters: {
        'stationId': stationId,
        'date': date,
        if (shift != null) 'shift': shift,
        if (workerId != null) 'workerId': workerId,
      },
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List list = body['activities'] ?? [];
      return list.map<DailyActivityRecord>((e) => DailyActivityRecord.fromJson(e)).toList();
    }
    throw Exception('Failed to load pending activities');
  }

  static Future<Map<String, dynamic>> getShiftSummary(String stationId, String date, String shift) async {
    final uri = Uri.parse('$baseUrl/api/station-activities/shift-summary').replace(
      queryParameters: {'stationId': stationId, 'date': date, 'shift': shift},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load shift summary');
  }

  static Future<void> bulkVerify(List<String> uids, String status, {String? remarks}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/station-activities/bulk-verify'),
      headers: await _headers(),
      body: jsonEncode({
        'uids': uids,
        'status': status,
        if (remarks != null) 'remarks': remarks,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to perform bulk verification');
    }
  }
}
