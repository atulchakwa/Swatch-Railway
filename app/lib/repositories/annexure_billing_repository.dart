import 'dart:convert';
import 'package:crm_train/model/annexure_billing_models.dart';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';

class AnnexureBillingRepository {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _err(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return (body['error'] ?? body['message'] ?? 'Request failed') as String;
    } catch (_) {
      return 'Request failed (${res.statusCode})';
    }
  }

  // ─── Items (Level 1) ───────────────────────────────────────────────────────
  static Future<AnnexureOpResult> seed(String contractId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/annexure-billing/contracts/$contractId/seed'),
      headers: await _headers(),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return AnnexureOpResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  static Future<AnnexureContractItemsResult> items(String contractId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/annexure-billing/contracts/$contractId/items'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return AnnexureContractItemsResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  static Future<AnnexureContractItemsResult> validate(String contractId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/annexure-billing/contracts/$contractId/validate'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return AnnexureContractItemsResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  // ─── Areas (Level 2) ───────────────────────────────────────────────────────
  static Future<AnnexureOpResult> addArea(
    String itemId, {
    required String areaName,
    required double allocatedWeightage,
    String? areaCode,
    String? unit,
    double? quantity,
    double? rate,
    String? frequencyOverride,
    String? remarks,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/annexure-billing/items/$itemId/areas'),
      headers: await _headers(),
      body: jsonEncode({
        'areaName': areaName,
        'allocatedWeightage': allocatedWeightage,
        if (areaCode != null) 'areaCode': areaCode,
        if (unit != null) 'unit': unit,
        if (quantity != null) 'quantity': quantity,
        if (rate != null) 'rate': rate,
        if (frequencyOverride != null) 'frequencyOverride': frequencyOverride,
        if (remarks != null) 'remarks': remarks,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return AnnexureOpResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  static Future<AnnexureOpResult> updateArea(
    String areaId, {
    String? areaName,
    double? allocatedWeightage,
    String? areaCode,
    String? unit,
    double? quantity,
    double? rate,
    String? frequencyOverride,
    String? remarks,
    String? status,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/annexure-billing/areas/$areaId'),
      headers: await _headers(),
      body: jsonEncode({
        if (areaName != null) 'areaName': areaName,
        if (allocatedWeightage != null) 'allocatedWeightage': allocatedWeightage,
        if (areaCode != null) 'areaCode': areaCode,
        if (unit != null) 'unit': unit,
        if (quantity != null) 'quantity': quantity,
        if (rate != null) 'rate': rate,
        if (frequencyOverride != null) 'frequencyOverride': frequencyOverride,
        if (remarks != null) 'remarks': remarks,
        if (status != null) 'status': status,
      }),
    );
    if (res.statusCode == 200) {
      return AnnexureOpResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  static Future<AnnexureOpResult> deleteArea(String areaId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/annexure-billing/areas/$areaId'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return AnnexureOpResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  // ─── Item controls ─────────────────────────────────────────────────────────
  static Future<AnnexureOpResult> markUnavailable(String itemId, {String? reason}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/annexure-billing/items/$itemId/unavailable'),
      headers: await _headers(),
      body: jsonEncode({if (reason != null) 'reason': reason}),
    );
    if (res.statusCode == 200) {
      return AnnexureOpResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  static Future<AnnexureOpResult> addNewItem(
    String contractId, {
    required String description,
    required double weightage,
    String? frequency,
    String? quantityMode,
    String? remarks,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/annexure-billing/contracts/$contractId/items'),
      headers: await _headers(),
      body: jsonEncode({
        'description': description,
        'weightage': weightage,
        if (frequency != null) 'frequency': frequency,
        if (quantityMode != null) 'quantityMode': quantityMode,
        if (remarks != null) 'remarks': remarks,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return AnnexureOpResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  // ─── Billing / deductions ──────────────────────────────────────────────────
  static Future<AnnexureOpResult> calculateDeductions(
    String contractId, {
    required String billingStart,
    required String billingEnd,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/annexure-billing/deductions/calculate'),
      headers: await _headers(),
      body: jsonEncode({'contractId': contractId, 'billingStart': billingStart, 'billingEnd': billingEnd}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return AnnexureOpResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  static Future<AnnexureOpResult> finalizeDeductions(
    String contractId, {
    required String billingStart,
    required String billingEnd,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/annexure-billing/deductions/finalize'),
      headers: await _headers(),
      body: jsonEncode({'contractId': contractId, 'billingStart': billingStart, 'billingEnd': billingEnd}),
    );
    if (res.statusCode == 200) {
      return AnnexureOpResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  static Future<AnnexureBillingSummary> summary(
    String contractId, {
    String? billingStart,
    String? billingEnd,
  }) async {
    final uri = Uri.parse('$baseUrl/api/annexure-billing/contracts/$contractId/summary').replace(
      queryParameters: {
        if (billingStart != null) 'billingStart': billingStart,
        if (billingEnd != null) 'billingEnd': billingEnd,
      },
    );
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      return AnnexureBillingSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_err(res));
  }

  static Future<List<AnnexureWeightageTransfer>> transfers(String contractId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/annexure-billing/contracts/$contractId/transfers'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ((body['transfers'] ?? const []) as List)
          .whereType<Map<String, dynamic>>()
          .map(AnnexureWeightageTransfer.fromJson)
          .toList();
    }
    throw Exception(_err(res));
  }
}