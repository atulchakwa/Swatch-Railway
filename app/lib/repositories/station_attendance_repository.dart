import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class StationAttendanceRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> mark(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/station-attendance/mark'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to mark attendance');
    }
  }

  static Future<void> bulkMark(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/station-attendance/bulk'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed bulk marking');
    }
  }

  static Future<List<StationAttendance>> getShiftAttendance(String stationId, String date, {String? shift}) async {
    final uri = Uri.parse('$baseUrl/api/station-attendance/shift').replace(
      queryParameters: {
        'stationId': stationId,
        'date': date,
        if (shift != null) 'shift': shift,
      },
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List list = body['records'] ?? [];
      return list.map<StationAttendance>((e) => StationAttendance.fromJson(e)).toList();
    }
    throw Exception('Failed to get shift attendance');
  }

  static Future<Map<String, dynamic>> getPlannedVsActual(String stationId, String date, String shift) async {
    final uri = Uri.parse('$baseUrl/api/station-attendance/planned-vs-actual').replace(
      queryParameters: {'stationId': stationId, 'date': date, 'shift': shift},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load planned vs actual data');
  }

  static Future<Map<String, dynamic>> getMonthlySummary(String stationId, int month, int year) async {
    final uri = Uri.parse('$baseUrl/api/station-attendance/monthly-summary').replace(
      queryParameters: {'stationId': stationId, 'month': month.toString(), 'year': year.toString()},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get monthly summary');
  }

  static Future<void> flagAbsences(String stationId, String date, String shift) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/station-attendance/flag-absences'),
      headers: await _headers(),
      body: jsonEncode({'stationId': stationId, 'date': date, 'shift': shift}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to flag absences');
    }
  }
}
