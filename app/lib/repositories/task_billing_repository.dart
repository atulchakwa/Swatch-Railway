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

  static Future<DailyTaskBillingResponse> preview(String contractId, String stationId, String date) async {
    final uri = Uri.parse('$baseUrl/api/task-execution-billing/daily/preview').replace(
      queryParameters: {'contractId': contractId, 'stationId': stationId, 'date': date},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return DailyTaskBillingResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['error'] ?? jsonDecode(response.body)['message'] ?? 'Failed to preview daily bill');
  }

  static Future<DailyBillingMonth> previewRange(String contractId, String stationId, String startDate, String endDate) async {
    final uri = Uri.parse('$baseUrl/api/task-execution-billing/daily/preview/range').replace(
      queryParameters: {'contractId': contractId, 'stationId': stationId, 'startDate': startDate, 'endDate': endDate},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return DailyBillingMonth.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? jsonDecode(response.body)['message'] ?? 'Failed to preview daily bill range');
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
    throw Exception(jsonDecode(response.body)['error'] ?? jsonDecode(response.body)['message'] ?? 'Failed to generate daily bill');
  }

  static Future<Map<String, dynamic>> generateRange(String contractId, String stationId, String startDate, String endDate) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/task-execution-billing/daily/generate'),
      headers: await _headers(),
      body: jsonEncode({'contractId': contractId, 'stationId': stationId, 'startDate': startDate, 'endDate': endDate}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(jsonDecode(response.body)['error'] ?? jsonDecode(response.body)['message'] ?? 'Failed to generate daily bill range');
  }

  static Future<DailyTaskBillingResponse?> getByDate(String contractId, String stationId, String date) async {
    final uri = Uri.parse('$baseUrl/api/task-execution-billing/daily').replace(
      queryParameters: {'contractId': contractId, 'stationId': stationId, 'date': date},
    );
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) return DailyTaskBillingResponse.fromJson(jsonDecode(response.body));
    return null;
  }

  static Future<DailyBillingMonth> list(String contractId, String stationId, int month, int year, {String? startDate, String? endDate}) async {
    final params = <String, String>{
      'contractId': contractId,
      'stationId': stationId,
    };
    if (startDate != null && endDate != null) {
      params['startDate'] = startDate;
      params['endDate'] = endDate;
    } else {
      params['month'] = '$month';
      params['year'] = '$year';
    }
    final uri = Uri.parse('$baseUrl/api/task-execution-billing/daily/list').replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return DailyBillingMonth.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? jsonDecode(response.body)['message'] ?? 'Failed to load daily bills');
  }
}