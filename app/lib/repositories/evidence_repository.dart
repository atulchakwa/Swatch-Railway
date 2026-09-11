import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class EvidenceRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<EvidenceMetadata>> search(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/evidence/search').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['results'] as List<dynamic>? ?? [];
      return list.map<EvidenceMetadata>((e) => EvidenceMetadata.fromJson(e)).toList();
    }
    throw Exception('Failed to search evidence');
  }

  static Future<Map<String, dynamic>> upload(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/evidence/upload'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode == 201 || res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to upload evidence');
  }

  static Future<Map<String, dynamic>> getStorageAnalytics(String stationId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/storage/analytics?stationId=$stationId'), headers: await _headers());
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load storage analytics');
  }

  static Future<String> verifyFace(String image1, String image2) async {
    final res = await http.post(Uri.parse('$baseUrl/api/evidence/verify-face'), headers: await _headers(), body: jsonEncode({'image1': image1, 'image2': image2}));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['match'] == true ? 'match' : 'no_match';
    }
    throw Exception('Face verification failed');
  }
}
