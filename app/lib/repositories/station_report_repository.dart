import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class StationReportRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<StationReport>> list(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/station-reports').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['reports'] ?? [];
      return list.map<StationReport>((e) => StationReport.fromJson(e)).toList();
    }
    throw Exception('Failed to load reports');
  }

  static String _typeToRouteSuffix(String type) {
    // Strip frequency prefix for URL building
    var suffix = type;
    if (suffix.startsWith('daily_')) suffix = suffix.substring(6);
    else if (suffix.startsWith('monthly_')) suffix = suffix.substring(8);
    // Convert underscores to hyphens (route convention)
    suffix = suffix.replaceAll('_', '-');
    return suffix;
  }

  static Future<StationReport> generateDaily(String type, String stationId, String date) async {
    final route = _typeToRouteSuffix(type);
    final res = await http.post(Uri.parse('$baseUrl/api/station-reports/daily/$route'), headers: await _headers(), body: jsonEncode({'stationId': stationId, 'date': date}));
    if (res.statusCode == 200 || res.statusCode == 201) return StationReport.fromJson(jsonDecode(res.body));
    throw Exception('Failed to generate daily report');
  }

  static Future<StationReport> generateMonthly(String type, String stationId, int month, int year) async {
    final route = _typeToRouteSuffix(type);
    final res = await http.post(Uri.parse('$baseUrl/api/station-reports/monthly/$route'), headers: await _headers(), body: jsonEncode({'stationId': stationId, 'month': month, 'year': year}));
    if (res.statusCode == 200 || res.statusCode == 201) return StationReport.fromJson(jsonDecode(res.body));
    throw Exception('Failed to generate monthly report');
  }

  static Future<StationReport> generateArchiveRetrieval(String stationId, String startDate, String endDate) async {
    final res = await http.post(Uri.parse('$baseUrl/api/station-reports/archive-retrieval'), headers: await _headers(), body: jsonEncode({'stationId': stationId, 'startDate': startDate, 'endDate': endDate}));
    if (res.statusCode == 200 || res.statusCode == 201) return StationReport.fromJson(jsonDecode(res.body));
    throw Exception('Failed to generate archive retrieval report');
  }

  static Future<void> schedule(String reportType, String cronExpression, List<String> recipients, Map<String, dynamic> parameters) async {
    final res = await http.post(Uri.parse('$baseUrl/api/station-reports/schedule'), headers: await _headers(), body: jsonEncode({'reportType': reportType, 'cronExpression': cronExpression, 'recipients': recipients, 'parameters': parameters}));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to schedule report');
  }

  static Future<List<Map<String, dynamic>>> listSchedules() async {
    final res = await http.get(Uri.parse('$baseUrl/api/station-reports/schedules'), headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['schedules'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load schedules');
  }

  static Future<void> deleteSchedule(String uid) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/station-reports/schedule/$uid'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to delete schedule');
  }

  static Future<Map<String, dynamic>> getScoreTrend(String stationId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/station-reports/score-trend?stationId=$stationId'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load score trend');
  }

  static Future<Map<String, dynamic>> generateAuditReport(String type, Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/station-reports/audit/$type').replace(queryParameters: query.isNotEmpty ? query : null);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to generate audit report');
  }
}
