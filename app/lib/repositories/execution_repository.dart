import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class ExecutionRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<ExecutionPlan> createPlan(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/execution-plans'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode == 201) return ExecutionPlan.fromJson(jsonDecode(res.body)['plan'] ?? jsonDecode(res.body));
    throw Exception(jsonDecode(res.body)['message'] ?? 'Failed to create plan');
  }

  static Future<List<ExecutionPlan>> listPlans(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/execution-plans').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['plans'] as List;
      return list.map<ExecutionPlan>((e) => ExecutionPlan.fromJson(e)).toList();
    }
    throw Exception('Failed to load plans');
  }

  static Future<ExecutionPlan> getPlan(String uid) async {
    final res = await http.get(Uri.parse('$baseUrl/api/execution-plans/$uid'), headers: await _headers());
    if (res.statusCode == 200) return ExecutionPlan.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load plan');
  }

  static Future<void> updatePlan(String uid, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/api/execution-plans/$uid'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 200) throw Exception('Failed to update plan');
  }

  static Future<void> submitPlan(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/execution-plans/$uid/submit'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to submit plan');
  }

  static Future<void> approvePlan(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/execution-plans/$uid/approve'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to approve plan');
  }

  static Future<void> rejectPlan(String uid, String reason) async {
    final res = await http.post(Uri.parse('$baseUrl/api/execution-plans/$uid/reject'), headers: await _headers(), body: jsonEncode({'reason': reason}));
    if (res.statusCode != 200) throw Exception('Failed to reject plan');
  }

  static Future<void> deletePlan(String uid) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/execution-plans/$uid'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to delete plan');
  }

  static Future<List<ExecutionLog>> listLogs(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/execution-logs').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['logs'] as List;
      return list.map<ExecutionLog>((e) => ExecutionLog.fromJson(e)).toList();
    }
    throw Exception('Failed to load logs');
  }

  static Future<ExecutionLog> getLog(String uid) async {
    final res = await http.get(Uri.parse('$baseUrl/api/execution-logs/$uid'), headers: await _headers());
    if (res.statusCode == 200) return ExecutionLog.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load log');
  }

  static Future<void> createLog(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/execution-logs'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to create log');
  }

  static Future<void> submitLog(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/execution-logs/$uid/submit'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to submit log');
  }

  static Future<void> approveLog(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/execution-logs/$uid/approve'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to approve log');
  }

  static Future<void> rejectLog(String uid, String reason) async {
    final res = await http.post(Uri.parse('$baseUrl/api/execution-logs/$uid/reject'), headers: await _headers(), body: jsonEncode({'reason': reason}));
    if (res.statusCode != 200) throw Exception('Failed to reject log');
  }
}
