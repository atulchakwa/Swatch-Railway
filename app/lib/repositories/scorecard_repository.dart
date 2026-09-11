import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class ScorecardRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<Scorecard>> list(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/scorecards/daily').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body)['scorecards'] as List? ?? [];
      return raw.map<Scorecard>((e) => Scorecard.fromJson(e)).toList();
    }
    throw Exception('Failed to load scorecards');
  }

  static Future<Scorecard> getById(String uid) async {
    final res = await http.get(Uri.parse('$baseUrl/api/scorecards/$uid'), headers: await _headers());
    if (res.statusCode == 200) return Scorecard.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load scorecard');
  }

  static Future<void> autoGenerate(String stationId, String date) async {
    final res = await http.post(Uri.parse('$baseUrl/api/scorecards/auto-generate'), headers: await _headers(), body: jsonEncode({'stationId': stationId, 'date': date}));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to auto-generate scorecard');
  }

  static Future<void> submit(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/scorecards/$uid/submit'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to submit scorecard');
  }

  static Future<void> approve(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/scorecards/$uid/approve'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to approve scorecard');
  }

  static Future<void> reject(String uid, String reason) async {
    final res = await http.post(Uri.parse('$baseUrl/api/scorecards/$uid/reject'), headers: await _headers(), body: jsonEncode({'reason': reason}));
    if (res.statusCode != 200) throw Exception('Failed to reject scorecard');
  }

  static Future<Map<String, dynamic>> monthlySummary(String stationId, int month, int year) async {
    final res = await http.get(Uri.parse('$baseUrl/api/scorecards/monthly/$stationId?month=$month&year=$year'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load monthly summary');
  }
}
