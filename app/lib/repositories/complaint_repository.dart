import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class ComplaintRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<Complaint>> list(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/complaints').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['complaints'] as List<dynamic>? ?? [];
      return list.map<Complaint>((e) => Complaint.fromJson(e)).toList();
    }
    throw Exception('Failed to load complaints');
  }

  static Future<Complaint> getById(String uid) async {
    final res = await http.get(Uri.parse('$baseUrl/api/complaints/$uid'), headers: await _headers());
    if (res.statusCode == 200) return Complaint.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load complaint');
  }

  static Future<void> create(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/complaints'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to create complaint');
  }

  static Future<void> assign(String uid, String assigneeId) async {
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/assign'), headers: await _headers(), body: jsonEncode({'assignedTo': assigneeId}));
    if (res.statusCode != 200) throw Exception('Failed to assign complaint');
  }

  static Future<void> startProgress(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/start'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to start progress');
  }

  static Future<void> resolve(String uid, String actionTaken, String? photoUrl) async {
    final body = <String, dynamic>{'actionTaken': actionTaken};
    if (photoUrl != null) body['closurePhotoUrl'] = photoUrl;
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/resolve'), headers: await _headers(), body: jsonEncode(body));
    if (res.statusCode != 200) throw Exception('Failed to resolve complaint');
  }

  static Future<void> reject(String uid, String reason) async {
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/reject'), headers: await _headers(), body: jsonEncode({'reason': reason}));
    if (res.statusCode != 200) throw Exception('Failed to reject complaint');
  }

  static Future<void> verify(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/verify'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to verify complaint');
  }

  static Future<void> resubmit(String uid, String actionTaken, String? photoUrl) async {
    final body = <String, dynamic>{'actionTaken': actionTaken};
    if (photoUrl != null) body['closurePhotoUrl'] = photoUrl;
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/resubmit'), headers: await _headers(), body: jsonEncode(body));
    if (res.statusCode != 200) throw Exception('Failed to resubmit complaint');
  }

  static Future<void> close(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/close'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to close complaint');
  }

  static Future<void> reopen(String uid, String reason) async {
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/reopen'), headers: await _headers(), body: jsonEncode({'reason': reason}));
    if (res.statusCode != 200) throw Exception('Failed to reopen complaint');
  }

  static Future<void> escalate(String uid, String escalateTo) async {
    final res = await http.post(Uri.parse('$baseUrl/api/complaints/$uid/escalate'), headers: await _headers(), body: jsonEncode({'escalatedTo': escalateTo}));
    if (res.statusCode != 200) throw Exception('Failed to escalate complaint');
  }
}
