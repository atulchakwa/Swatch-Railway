import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class PettyIssueRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<PettyIssue>> list(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/petty-issues').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body)['issues'] as List? ?? [];
      return raw.map<PettyIssue>((e) => PettyIssue.fromJson(e)).toList();
    }
    throw Exception('Failed to load petty issues');
  }

  static Future<PettyIssue> getById(String uid) async {
    final res = await http.get(Uri.parse('$baseUrl/api/petty-issues/$uid'), headers: await _headers());
    if (res.statusCode == 200) return PettyIssue.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load petty issue');
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/petty-issues'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode == 201 || res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to create petty issue');
  }

  static Future<void> update(String uid, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/api/petty-issues/$uid'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 200) throw Exception('Failed to update petty issue');
  }

  static Future<void> updateStatus(String uid, Map<String, dynamic> data) async {
    final res = await http.patch(Uri.parse('$baseUrl/api/petty-issues/$uid/status'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 200) throw Exception('Failed to update status');
  }

  static Future<void> resolve(String uid, {String remarks = ''}) async {
    final res = await http.post(Uri.parse('$baseUrl/api/petty-issues/$uid/resolve'), headers: await _headers(), body: jsonEncode({'remarks': remarks}));
    if (res.statusCode != 200) throw Exception('Failed to resolve petty issue');
  }

  static Future<void> close(String uid, {String remarks = ''}) async {
    final res = await http.post(Uri.parse('$baseUrl/api/petty-issues/$uid/close'), headers: await _headers(), body: jsonEncode({'remarks': remarks}));
    if (res.statusCode != 200) throw Exception('Failed to close petty issue');
  }

  static Future<void> remove(String uid) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/petty-issues/$uid'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to delete petty issue');
  }

  static Future<Map<String, dynamic>> summary(String stationId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/petty-issues/summary/$stationId'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load summary');
  }
}
