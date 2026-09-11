import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/station_run_model.dart';
import '../services/api_services.dart';

class StationRunRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<http.Response> _handleRequest(Future<http.Response> Function() requestFunc) async {
    try {
      final response = await requestFunc();
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('AUTH_ERROR');
      }
      return response;
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception('Connection failed. Please check your internet connection.');
    }
  }

  static Future<List<StationCleaningRunModel>> getAllStationRuns() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final response = await _handleRequest(
        () => http.get(
          Uri.parse('$baseUrl/api/station-runs'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return (decoded['data'] as List)
              .map<StationCleaningRunModel>((item) => StationCleaningRunModel.fromJson(item))
              .toList();
        } else {
          throw Exception(decoded['error'] ?? 'Failed to load station runs');
        }
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) rethrow;
      throw Exception('Error: $e');
    }
  }

  static Future<StationCleaningRunModel> createStationRun(StationCleaningRunModel run) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$baseUrl/api/station-runs'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(run.toJson()),
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return StationCleaningRunModel.fromJson(decoded['data']);
        } else {
          throw Exception(decoded['error'] ?? 'Failed to create run');
        }
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) rethrow;
      throw Exception('Error: $e');
    }
  }

  static Future<StationCleaningRunModel> updateStationRun(String runId, StationCleaningRunModel run) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final response = await _handleRequest(
        () => http.put(
          Uri.parse('$baseUrl/api/station-runs/$runId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(run.toJson()),
        ),
      );

      if (response.statusCode == 200) {
        return run;
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) rethrow;
      throw Exception('Error: $e');
    }
  }

  static Future<void> deleteStationRun(String runId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final response = await _handleRequest(
        () => http.delete(
          Uri.parse('$baseUrl/api/station-runs/$runId'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) rethrow;
      throw Exception('Error: $e');
    }
  }

  /// Fetches only runs where the logged-in worker is assigned as a janitor
  static Future<List<StationCleaningRunModel>> getMyStationRuns() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final response = await _handleRequest(
        () => http.get(
          Uri.parse('$baseUrl/api/station-runs/my-runs'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return (decoded['data'] as List)
              .map((item) => StationCleaningRunModel.fromJson(item))
              .toList();
        } else {
          throw Exception(decoded['error'] ?? 'Failed to load station runs');
        }
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) rethrow;
      throw Exception('Error: $e');
    }
  }
}
