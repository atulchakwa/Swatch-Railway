import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../helper/api_error_handler.dart';
import '../services/api_services.dart';

class WorkerRepository {
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

  static Future<Map<String, dynamic>> getWorkerProfile() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('AUTH_ERROR');
      }

      final response = await _handleRequest(
        () => http.get(
          Uri.parse('$baseUrl/api/worker/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(
          ApiErrorHandler.getErrorMessage(response.body, response.statusCode),
        );
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  static Future<Map<String, dynamic>> getWorkerStatistics() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('AUTH_ERROR');
      }

      final response = await _handleRequest(
        () => http.get(
          Uri.parse('$baseUrl/api/worker/statistics'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(
          ApiErrorHandler.getErrorMessage(response.body, response.statusCode),
        );
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  static Future<Map<String, dynamic>> getWorkerTasks() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('AUTH_ERROR');
      }

      final response = await _handleRequest(
        () => http.get(
          Uri.parse('$baseUrl/api/worker/tasks'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(
          ApiErrorHandler.getErrorMessage(response.body, response.statusCode),
        );
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  static Future<String> uploadMedia(String filePath) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('AUTH_ERROR');
      }

      List<int>? fileBytes;
      String filename = 'upload.jpg';
      if (kIsWeb) {
        try {
          final res = await http.get(Uri.parse(filePath));
          fileBytes = res.bodyBytes;
          filename = filePath.split('/').last;
          if (!filename.contains('.')) filename += '.jpg';
        } catch (e) {
          debugPrint('Error reading web blob bytes: $e');
        }
      }

      http.Response? lastResponse;
      // Only try the field names currently supported by the backend: 'image' and 'file'
      for (final fieldName in ['image', 'file']) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/media/upload'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['folder'] = 'station_tasks';
        
        if (kIsWeb && fileBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              fieldName,
              fileBytes,
              filename: filename,
              contentType: _mediaTypeForPath(filePath),
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              filePath,
              contentType: _mediaTypeForPath(filePath),
            ),
          );
        }

        try {
          final streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Upload timeout'),
          );
          final response = await http.Response.fromStream(streamedResponse);
          lastResponse = response;

          if (response.statusCode == 200 || response.statusCode == 201) {
            final decoded = jsonDecode(response.body) as Map<String, dynamic>;
            final url = _extractMediaUrl(decoded);
            if (url != null && url.isNotEmpty) return url;
          }

          // If auth error, fail immediately
          if (response.statusCode == 401) {
            throw Exception('AUTH_ERROR');
          }

          // If it's a 4xx or 5xx error, don't keep trying other keys if we already tried 'image'
          if (response.statusCode >= 400) {
            final msg = ApiErrorHandler.getErrorMessage(response.body, response.statusCode);
            throw Exception(msg);
          }
        } catch (e) {
          if (e.toString().contains('AUTH_ERROR') || !e.toString().contains('Invalid field')) {
            rethrow;
          }
          // Continue to 'file' if 'image' failed with a specific "Invalid field" type error
        }
      }

      throw Exception(
        lastResponse == null
            ? 'Media upload failed.'
            : ApiErrorHandler.getErrorMessage(
                lastResponse.body,
                lastResponse.statusCode,
              ),
      );
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  static String? _extractMediaUrl(Map<String, dynamic> json) {
    for (final key in [
      'imageUrl',
      'url',
      'fileUrl',
      'mediaUrl',
      'downloadUrl',
    ]) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return _extractMediaUrl(data);
    }

    final file = json['file'];
    if (file is Map<String, dynamic>) {
      return _extractMediaUrl(file);
    }

    return null;
  }

  static MediaType _mediaTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    return MediaType('image', 'jpeg');
  }

  static Future<Map<String, dynamic>> submitComplaint({
    required String title,
    required String description,
    String? category,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('AUTH_ERROR');
      }

      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$baseUrl/api/worker/complaints'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'title': title,
            'description': description,
            'category': category,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(
          ApiErrorHandler.getErrorMessage(response.body, response.statusCode),
        );
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) {
        rethrow;
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  /// GET /api/passenger/tasks?trainNo=...&coachNo=...
  /// Fetches tasks raised by passengers.
  static Future<Map<String, dynamic>> getPassengerTasks({
    String? trainNo,
    String? coachNo,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final queryParams = <String, String>{};
      if (trainNo != null) queryParams['trainNo'] = trainNo;
      if (coachNo != null) queryParams['coachNo'] = coachNo;

      final uri = Uri.parse('$baseUrl/api/passenger/tasks').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await _handleRequest(
        () => http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(
          ApiErrorHandler.getErrorMessage(response.body, response.statusCode),
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}

