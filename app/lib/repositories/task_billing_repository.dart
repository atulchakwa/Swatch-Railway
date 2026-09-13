import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/task_billing_models.dart';

class TaskBillingRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<AreaWeightage>> getWeightages(String contractId, String stationId) async {
    final uri = Uri.parse('$baseUrl/api/task-execution-billing/weightages').replace(
      queryParameters: {'contractId': contractId, 'stationId': stationId},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List list = body['weightages'] ?? [];
      return list.map<AreaWeightage>((e) => AreaWeightage.fromJson(e)).toList();
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load area weightages');
  }

  static Future<Map<String, dynamic>> upsertWeightage(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/task-execution-billing/weightages'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to save area weightage');
  }

  static Future<void> deleteWeightage(String uid) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/task-execution-billing/weightages/$uid'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to deactivate area weightage');
    }
  }

  static Future<DailyTaskBillingResponse> preview(String contractId, String stationId, String date) async {
    final uri = Uri.parse('$baseUrl/api/task-execution-billing/daily/preview').replace(
      queryParameters: {'contractId': contractId, 'stationId': stationId, 'date': date},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return DailyTaskBillingResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to preview daily bill');
  }

  static Future<DailyTaskBillingResponse> generate(String contractId, String stationId, String date) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/task-execution-billing/daily/generate'),
      headers: await _headers(),
      body: jsonEncode({'contractId': contractId, 'stationId': stationId, 'date': date}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return DailyTaskBillingResponse.fromJson(body['bill'] ?? body);
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to generate daily bill');
  }

  static Future<DailyTaskBillingResponse?> getByDate(String contractId, String stationId, String date) async {
    final uri = Uri.parse('$baseUrl/api/task-execution-billing/daily').replace(
      queryParameters: {'contractId': contractId, 'stationId': stationId, 'date': date},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return DailyTaskBillingResponse.fromJson(jsonDecode(response.body));
    return null;
  }

  static Future<List<DailyTaskBillingResponse>> list(String contractId, String stationId, int month, int year) async {
    final uri = Uri.parse('$baseUrl/api/task-execution-billing/daily/list').replace(
      queryParameters: {'contractId': contractId, 'stationId': stationId, 'month': '$month', 'year': '$year'},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List list = body['bills'] ?? [];
      return list.map<DailyTaskBillingResponse>((e) => DailyTaskBillingResponse.fromJson(e)).toList();
    }
    throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load daily bills');
  }
}