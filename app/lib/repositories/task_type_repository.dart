import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/task_type_model.dart';

class TaskTypeRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<TaskType>> list({String? category, bool? isActive}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (isActive != null) params['isActive'] = isActive.toString();
    final uri = Uri.parse('$baseUrl/api/task-types').replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body)['taskTypes'] ?? jsonDecode(res.body)['data'] ?? [];
      return raw.cast<Map<String, dynamic>>().map((e) => TaskType.fromJson(e)).toList();
    }
    throw Exception('Failed to load task types');
  }

  static Future<void> create(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/task-types'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['error'] ?? 'Failed to create task type');
    }
  }

  static Future<void> update(String uid, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/api/task-types/$uid'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['error'] ?? 'Failed to update task type');
    }
  }

  static Future<void> remove(String uid) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/task-types/$uid'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to delete task type');
  }
}
