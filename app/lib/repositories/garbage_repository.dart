import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../helper/api_error_handler.dart';
import '../model/garbage_task_model.dart';
import '../model/station_cleaning_models.dart';
import '../services/api_services.dart';

class GarbageRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<http.Response> _handleRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<GarbageTaskModel>> getGarbageTasks(String runInstanceId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('AUTH_ERROR');
      }

      final uri = Uri.parse('$baseUrl/api/obhs/garbage-tasks').replace(
        queryParameters: {'runInstanceId': runInstanceId},
      );

      final response = await _handleRequest(
        () => http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tasks = (data['tasks'] as List<dynamic>?)
                ?.map((t) => GarbageTaskModel.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [];
        return tasks;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  static Future<bool> completeGarbageTask(String taskId, {required String beforePhoto, required String afterPhoto, double? latitude, double? longitude}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('AUTH_ERROR');
      }

      final body = <String, dynamic>{
        'taskId': taskId,
        'beforePhoto': beforePhoto,
        'afterPhoto': afterPhoto,
        'deviceTimestamp': DateTime.now().toUtc().toIso8601String(),
      };
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$baseUrl/api/obhs/garbage-tasks/complete'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  // --- Station Cleaning Garbage Collection methods ---

  static Future<List<GarbageCollection>> listStationGarbage(Map<String, String> query) async {
    final token = await _getToken();
    if (token == null) throw Exception('AUTH_ERROR');
    final uri = Uri.parse('$baseUrl/api/garbage/collections').replace(queryParameters: query);
    final res = await http.get(uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      final raw = jsonDecode(res.body)['collections'] as List? ?? [];
      return raw.map<GarbageCollection>((e) => GarbageCollection.fromJson(e)).toList();
    }
    throw Exception('Failed to load garbage collections');
  }

  static Future<void> recordStationGarbage(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('AUTH_ERROR');
    final res = await http.post(Uri.parse('$baseUrl/api/garbage/collections'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to record garbage');
  }

  static Future<GarbageCollection> getStationGarbageById(String uid) async {
    final token = await _getToken();
    if (token == null) throw Exception('AUTH_ERROR');
    final res = await http.get(Uri.parse('$baseUrl/api/garbage/collections/$uid'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) return GarbageCollection.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load garbage record');
  }

  static Future<void> verifyStationGarbage(String uid) async {
    final token = await _getToken();
    if (token == null) throw Exception('AUTH_ERROR');
    final res = await http.post(Uri.parse('$baseUrl/api/garbage/collections/$uid/verify'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw Exception('Failed to verify garbage');
  }

  static Future<void> approveStationGarbage(String uid) async {
    final token = await _getToken();
    if (token == null) throw Exception('AUTH_ERROR');
    final res = await http.post(Uri.parse('$baseUrl/api/garbage/collections/$uid/approve'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw Exception('Failed to approve garbage');
  }

  static Future<void> markStationGarbageDisposed(String uid, String agency, String vehicle) async {
    final token = await _getToken();
    if (token == null) throw Exception('AUTH_ERROR');
    final res = await http.post(Uri.parse('$baseUrl/api/garbage/collections/$uid/dispose'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'disposalAgency': agency, 'vehicleNumber': vehicle}));
    if (res.statusCode != 200) throw Exception('Failed to mark disposed');
  }

  static Future<void> rejectStationGarbage(String uid, String reason) async {
    final token = await _getToken();
    if (token == null) throw Exception('AUTH_ERROR');
    final res = await http.post(Uri.parse('$baseUrl/api/garbage/collections/$uid/reject'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'reason': reason}));
    if (res.statusCode != 200) throw Exception('Failed to reject garbage');
  }

  // --- OBHS methods below ---

  static Future<List<GarbageTaskModel>> getPreTerminalTasks(String runInstanceId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('AUTH_ERROR');
      }

      final uri = Uri.parse('$baseUrl/api/obhs/garbage-tasks/pre-terminal').replace(
        queryParameters: {'runInstanceId': runInstanceId},
      );

      final response = await _handleRequest(
        () => http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tasks = (data['tasks'] as List<dynamic>?)
                ?.map((t) => GarbageTaskModel.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [];
        return tasks;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }
}
