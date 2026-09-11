import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../helper/api_error_handler.dart';
import '../model/railway_worker_model.dart';

class WorkerDirectoryRepository {
  static String get _baseUrl =>
      'https://swatch-railway-4.onrender.com';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
  ) async {
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw Exception('AUTH_ERROR');
    } else {
      throw Exception(
        ApiErrorHandler.getErrorMessage(response.body, response.statusCode),
      );
    }
  }

  static Future<List<RailwayWorkerModel>> getWorkers() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/users/workers'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = await _handleResponse(response);
      final workersData = data['workers'] as List<dynamic>? ?? [];
      return workersData
          .map((w) => RailwayWorkerModel.fromJson(w as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) rethrow;
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  static Future<List<RailwayWorkerModel>> getRailwayWorkers() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/admin/railway-workers'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = await _handleResponse(response);
      final workers = (data['workers'] as List<dynamic>?)
              ?.map((worker) => RailwayWorkerModel.fromJson(
                  worker as Map<String, dynamic>))
              .toList() ??
          [];
      return workers;
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) rethrow;
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }
}
