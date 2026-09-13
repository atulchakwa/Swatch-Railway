import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/estimation_models.dart';

class EstimationRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _msg(http.Response r, String fallback) {
    try {
      final body = jsonDecode(r.body);
      final m = body is Map ? body['message'] : null;
      return (m ?? fallback).toString();
    } catch (_) {
      return fallback;
    }
  }

  static Future<EstimateSummary> getEstimate(String contractId, {String stationId = ''}) async {
    final uri = Uri.parse('$baseUrl/api/contract-estimation/$contractId/estimate').replace(
      queryParameters: {if (stationId.isNotEmpty) 'stationId': stationId},
    );
    final r = await http.get(uri, headers: await _headers());
    if (r.statusCode == 200) return EstimateSummary.fromJson(jsonDecode(r.body));
    throw Exception(_msg(r, 'Failed to load estimate'));
  }

  static Future<Map<String, dynamic>> createItem(String contractId, Map<String, dynamic> payload) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/contract-estimation/$contractId/items'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode == 200 || r.statusCode == 201) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Failed to create estimate item'));
  }

  static Future<Map<String, dynamic>> updateItem(String uid, Map<String, dynamic> payload) async {
    final r = await http.put(
      Uri.parse('$baseUrl/api/contract-estimation/items/$uid'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Failed to update estimate item'));
  }

  static Future<void> deleteItem(String uid) async {
    final r = await http.delete(
      Uri.parse('$baseUrl/api/contract-estimation/items/$uid'),
      headers: await _headers(),
    );
    if (r.statusCode != 200) throw Exception(_msg(r, 'Failed to delete estimate item'));
  }

  static Future<VariationSet> getVariations(String contractId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/contract-estimation/$contractId/variations'),
      headers: await _headers(),
    );
    if (r.statusCode == 200) return VariationSet.fromJson(jsonDecode(r.body));
    throw Exception(_msg(r, 'Failed to load variations'));
  }

  static Future<Map<String, dynamic>> createVariation(String contractId, Map<String, dynamic> payload) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/contract-estimation/$contractId/variations'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode == 200 || r.statusCode == 201) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Failed to create variation'));
  }

  static Future<SwoSet> getSwos(String contractId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/contract-estimation/$contractId/swos'),
      headers: await _headers(),
    );
    if (r.statusCode == 200) return SwoSet.fromJson(jsonDecode(r.body));
    throw Exception(_msg(r, 'Failed to load SWOs'));
  }

  static Future<Map<String, dynamic>> createSwo(String contractId, Map<String, dynamic> payload) async {
    final r = await http.post(
      Uri.parse('$baseUrl/api/contract-estimation/$contractId/swos'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode == 200 || r.statusCode == 201) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(_msg(r, 'Failed to create SWO'));
  }

  static Future<void> deleteSwo(String uid) async {
    final r = await http.delete(
      Uri.parse('$baseUrl/api/contract-estimation/swos/$uid'),
      headers: await _headers(),
    );
    if (r.statusCode != 200) throw Exception(_msg(r, 'Failed to delete SWO'));
  }

  static Future<AmendedValue> getAmended(String contractId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/api/contract-estimation/$contractId/amended'),
      headers: await _headers(),
    );
    if (r.statusCode == 200) return AmendedValue.fromJson(jsonDecode(r.body));
    throw Exception(_msg(r, 'Failed to load amended value'));
  }

  static Future<PeriodContribution> getPeriodContribution(String contractId,
      {String stationId = '', int month = 0, int year = 0}) async {
    final uri = Uri.parse('$baseUrl/api/contract-estimation/$contractId/period-contribution').replace(
      queryParameters: {
        if (stationId.isNotEmpty) 'stationId': stationId,
        if (month > 0) 'month': '$month',
        if (year > 0) 'year': '$year',
      },
    );
    final r = await http.get(uri, headers: await _headers());
    if (r.statusCode == 200) return PeriodContribution.fromJson(jsonDecode(r.body));
    throw Exception(_msg(r, 'Failed to load period contribution'));
  }
}