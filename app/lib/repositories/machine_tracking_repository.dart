import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_services.dart';
import '../model/station_cleaning_models.dart';

class MachineTrackingRepository {
  static String get baseUrl => ApiService.baseUrl;
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<List<MachineDeployment>> listDeployments(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/machines/deployments').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['deployments'] ?? [];
      return list.map<MachineDeployment>((e) => MachineDeployment.fromJson(e)).toList();
    }
    throw Exception('Failed to load deployments');
  }

  static Future<void> deploy(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/machines/deploy'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to deploy machine');
  }

  static Future<void> returnMachine(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/machines/deployments/$uid/return'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to return machine');
  }

  static Future<List<MachineDowntime>> listDowntime(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/machines/downtime').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['downtimeRecords'] ?? jsonDecode(res.body)['records'] ?? [];
      return list.map<MachineDowntime>((e) => MachineDowntime.fromJson(e)).toList();
    }
    throw Exception('Failed to load downtime');
  }

  static Future<void> logDowntime(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/machines/downtime'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to log downtime');
  }

  static Future<void> resolveDowntime(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/machines/downtime/$uid/resolve'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to resolve downtime');
  }

  static Future<List<MachineMaintenance>> listMaintenance(Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl/api/machines/maintenance').replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body)['schedules'] ?? [];
      return list.map<MachineMaintenance>((e) => MachineMaintenance.fromJson(e)).toList();
    }
    throw Exception('Failed to load maintenance');
  }

  static Future<void> scheduleMaintenance(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/machines/maintenance'), headers: await _headers(), body: jsonEncode(data));
    if (res.statusCode != 201 && res.statusCode != 200) throw Exception('Failed to schedule maintenance');
  }

  static Future<void> completeMaintenance(String uid) async {
    final res = await http.post(Uri.parse('$baseUrl/api/machines/maintenance/$uid/complete'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to complete maintenance');
  }
}
