import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class PestControlRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<PestTreatment>> listPlans(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/pest-control/plans').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['plans'] ?? [];
      return list.map<PestTreatment>((e) => PestTreatment.fromJson(e)).toList();
    }
    throw Exception('Failed to load plans');
  }

  static Future<void> createPlan(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/pest-control/plans'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to create plan');
  }

  static Future<void> reviewPlan(String uid, String status, String remarks) async {
    final res = await http.post(Uri.parse('$baseUrl/api/pest-control/plans/$uid/review'), headers: await _headers(), body: jsonEncode({'status': status, 'reviewNotes': remarks}));
    if (res.statusCode != 200) throw Exception('Failed to review plan');
  }

  static Future<List<Map<String, dynamic>>> listChemicals(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/pest-control/chemicals').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['chemicals'] ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load chemicals');
  }

  static Future<void> createChemical(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/pest-control/chemicals'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to create chemical');
  }
}
