import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/passenger_feedback_model.dart';
import '../services/api_services.dart';

class PassengerFeedbackRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/passenger-feedback'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode == 201 || res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to submit feedback');
  }

  static Future<List<PassengerFeedback>> list(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/passenger-feedback').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body)['feedbacks'] as List? ?? [];
      return raw.map<PassengerFeedback>((e) => PassengerFeedback.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load feedback');
  }

  static Future<Map<String, dynamic>> getById(String uid) async {
    final res = await http.get(Uri.parse('$baseUrl/api/passenger-feedback/$uid'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load feedback');
  }

  static Future<void> update(String uid, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/api/passenger-feedback/$uid'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 200) throw Exception('Failed to update feedback');
  }

  static Future<void> remove(String uid) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/passenger-feedback/$uid'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to delete feedback');
  }

  static Future<PassengerFeedbackSummary> getSummary(String stationId,
      {String? startDate, String? endDate}) async {
    var uri = Uri.parse('$baseUrl/api/passenger-feedback/summary/$stationId');
    final params = <String, String>{
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    if (params.isNotEmpty) uri = uri.replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) return PassengerFeedbackSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    throw Exception('Failed to load summary');
  }
}