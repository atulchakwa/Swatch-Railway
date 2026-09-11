import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class SupervisorLogRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<SupervisorLog>> list(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/supervisor-logs').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['logs'] as List<dynamic>? ?? [];
      return list.map<SupervisorLog>((e) => SupervisorLog.fromJson(e)).toList();
    }
    throw Exception('Failed to load logs');
  }

  static Future<SupervisorLog> getById(String uid) async {
    final res = await http.get(Uri.parse('$baseUrl/api/supervisor-logs/$uid'), headers: await _headers());
    if (res.statusCode == 200) return SupervisorLog.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load log');
  }

  static Future<void> create(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/supervisor-logs'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to create log');
  }

  static Future<void> submit(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/supervisor-logs/$uid/submit'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to submit log');
  }

  static Future<void> acknowledge(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/supervisor-logs/$uid/acknowledge'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to acknowledge log');
  }

  static Future<void> accept(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/supervisor-logs/$uid/accept'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to accept log');
  }

  static Future<void> reject(String uid, String reason) async {
    final res = await http.post(Uri.parse('$baseUrl/api/supervisor-logs/$uid/reject'), headers: await _headers(), body: jsonEncode({'reason': reason}));
    if (res.statusCode != 200) throw Exception('Failed to reject log');
  }

  static Future<void> returnLog(String uid, String reason) async {
    final res = await http.post(Uri.parse('$baseUrl/api/supervisor-logs/$uid/return'), headers: await _headers(), body: jsonEncode({'reason': reason}));
    if (res.statusCode != 200) throw Exception('Failed to return log');
  }
}
