import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class WorkforceDeploymentRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<WorkforceDeployment>> list(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/deployments').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['deployments'] ?? [];
      return list.map((e) => WorkforceDeployment.fromJson(e)).toList();
    }
    throw Exception('Failed to load deployments');
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/deployments'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode == 201 || res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to create deployment');
  }

  static Future<void> update(String uid, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/api/deployments/$uid'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 200) throw Exception('Failed to update deployment');
  }

  static Future<void> delete(String uid) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/deployments/$uid'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to deactivate deployment');
  }

  static Future<Map<String, dynamic>> getShiftWiseManpower(String stationId, String date) async {
    final uri = Uri.parse('$baseUrl/api/deployments/shift-wise-manpower').replace(queryParameters: {'stationId': stationId, 'date': date});
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load shift-wise manpower');
  }

  static Future<Map<String, dynamic>> getManpowerVariance(String stationId, String date) async {
    final uri = Uri.parse('$baseUrl/api/deployments/manpower-variance').replace(queryParameters: {'stationId': stationId, 'date': date});
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load manpower variance');
  }

  static Future<List<Map<String, dynamic>>> getShifts(String stationId) async {
    final uri = Uri.parse('$baseUrl/api/shifts').replace(queryParameters: {'stationId': stationId});
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['shifts'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load shifts');
  }

  static Future<List<Map<String, dynamic>>> getTaskTypes() async {
    final res = await http.get(Uri.parse('$baseUrl/api/task-types'), headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['taskTypes'] ?? jsonDecode(res.body)['data'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load task types');
  }
}
