import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../helper/api_error_handler.dart';
import '../services/api_services.dart';

class StationCleaningRepository {
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
        onTimeout: () => throw Exception('Request timeout'),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<T> _apiCall<T>({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) parser,
    Map<String, String>? queryParams,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('AUTH_ERROR');

      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      late http.Response response;
      switch (method) {
        case 'GET':
          response = await _handleRequest(() => http.get(uri, headers: headers));
          break;
        case 'POST':
          response = await _handleRequest(() => http.post(uri, headers: headers, body: jsonEncode(body)));
          break;
        case 'PUT':
          response = await _handleRequest(() => http.put(uri, headers: headers, body: jsonEncode(body)));
          break;
        case 'DELETE':
          response = await _handleRequest(() => http.delete(uri, headers: headers));
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return parser(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('AUTH_ERROR');
      } else {
        throw Exception(ApiErrorHandler.getErrorMessage(response.body, response.statusCode));
      }
    } catch (e) {
      if (e.toString().contains('AUTH_ERROR')) rethrow;
      throw Exception(ApiErrorHandler.getErrorMessage(e, null));
    }
  }

  // ─── AREAS ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createArea(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-area/create',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listAreas(String stationId) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-area/list/$stationId',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getAreaSummary(String stationId) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-area/summary/$stationId',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getArea(String uid) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-area/$uid',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> updateArea(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-area/update/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> deleteArea(String uid) async {
    return await _apiCall(
      method: 'DELETE',
      path: '/api/station-area/delete/$uid',
      parser: (d) => d,
    );
  }

  // ─── ZONES ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createZone(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-zone/create',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listZones(String stationId, {String? areaId}) async {
    final params = <String, String>{};
    if (areaId != null) params['areaId'] = areaId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-zone/list/$stationId',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getZone(String uid) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-zone/$uid',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> updateZone(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-zone/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> deleteZone(String uid) async {
    return await _apiCall(
      method: 'DELETE',
      path: '/api/station-zone/$uid',
      parser: (d) => d,
    );
  }

  // ─── CONTRACTOR MAPPINGS ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> mapContractor(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-contractor/map',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listContractors(String stationId) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-contractor/list/$stationId',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getContractorMapping(String uid) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-contractor/$uid',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> updateContractorMapping(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-contractor/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> deleteContractorMapping(String uid) async {
    return await _apiCall(
      method: 'DELETE',
      path: '/api/station-contractor/$uid',
      parser: (d) => d,
    );
  }

  // ─── SCHEDULES ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createSchedule(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-schedule/create',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listSchedules(String stationId) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-schedule/list/$stationId',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getSchedule(String uid) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-schedule/$uid',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> updateSchedule(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-schedule/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> deleteSchedule(String uid) async {
    return await _apiCall(
      method: 'DELETE',
      path: '/api/station-schedule/$uid',
      parser: (d) => d,
    );
  }

  // ─── STATION RUNS ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createRun(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-runs',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listRuns({String? stationId, String? status}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    if (status != null) params['status'] = status;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-runs',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getMyRuns() async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-runs/my-runs',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getWorkerRuns(String workerId) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-runs/worker/$workerId',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getSupervisorRuns(String supervisorId) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-runs/supervisor/$supervisorId',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> updateRun(String runId, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-runs/$runId',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> deleteRun(String runId) async {
    return await _apiCall(
      method: 'DELETE',
      path: '/api/station-runs/$runId',
      parser: (d) => d,
    );
  }

  // ─── STATION TASKS ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> submitTask(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-tasks/submit',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listPendingTasks({String? runInstanceId}) async {
    final params = <String, String>{};
    if (runInstanceId != null) params['runInstanceId'] = runInstanceId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-tasks/pending-review',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getTask(String taskId) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-tasks/$taskId',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> updateTask(String taskId, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-tasks/$taskId',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> deleteTask(String taskId) async {
    return await _apiCall(
      method: 'DELETE',
      path: '/api/station-tasks/$taskId',
      parser: (d) => d,
    );
  }

  // ─── CLEANING FORMS ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createForm(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning-form/create',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> submitForm(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning-form/submit/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> approveForm(String uid) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning-form/approve/$uid',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> rejectForm(String uid, String reason) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning-form/reject/$uid',
      body: {'reason': reason},
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> scoreForm(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning-form/score/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> lockForm(String uid) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning-form/lock/$uid',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listForms({String? status, String? stationId, String? areaId, String? zoneId, String? division, int? limit, String? cursor}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (stationId != null) params['stationId'] = stationId;
    if (areaId != null) params['areaId'] = areaId;
    if (zoneId != null) params['zoneId'] = zoneId;
    if (division != null) params['division'] = division;
    if (limit != null) params['limit'] = limit.toString();
    if (cursor != null) params['cursor'] = cursor;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning-form/list',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getFormDetail(String uid) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning-form/details/$uid',
      parser: (d) => d,
    );
  }

  // ─── PEST CONTROL ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> recordPestControl(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-pest-control/record',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listPestControl(String stationId, {String? status, String? pestType}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (pestType != null) params['pestType'] = pestType;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-pest-control/list/$stationId',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listAllPestControl({String? stationId, String? status}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    if (status != null) params['status'] = status;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-pest-control/all',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> reviewPestControl(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-pest-control/$uid/review',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> pestControlReport({String? stationId}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-pest-control/report',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  // ─── MACHINE DEPLOYMENT ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> deployMachine(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-machines/deploy',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listMachines({String? stationId, String? status, String? machineType}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    if (status != null) params['status'] = status;
    if (machineType != null) params['machineType'] = machineType;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-machines/list',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> returnMachine(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-machines/$uid/return',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> maintenanceMachine(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-machines/$uid/maintenance',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> machineReport({String? stationId}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-machines/report',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  // ─── GARBAGE DISPOSAL ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> recordGarbage(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-garbage/record',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listGarbage({String? stationId}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-garbage/records',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> garbageReport({String? stationId}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-garbage/report',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  // ─── AREA-TASK FREQUENCY MAPPING (SRS #2) ──────────────────────────────

  static Future<Map<String, dynamic>> createAreaTaskFrequency(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-area-task-frequency',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> updateAreaTaskFrequency(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-area-task-frequency/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> deleteAreaTaskFrequency(String uid) async {
    return await _apiCall(
      method: 'DELETE',
      path: '/api/station-area-task-frequency/$uid',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listAreaTaskFrequencies({String? stationId, String? areaId}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    if (areaId != null) params['areaId'] = areaId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-area-task-frequency',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  // ─── ATTENDANCE (3-step: start / mid / end) ─────────────────────────────

  static Future<Map<String, dynamic>> markStationAttendance({
    required String type,
    required String runInstanceId,
    String stationId = '',
    required String imageUrl,
    double? latitude,
    double? longitude,
    String? livenessChallenge,
  }) async {
    final body = <String, dynamic>{
      'runInstanceId': runInstanceId,
      'stationId': stationId,
      'attendanceType': type,
      'imageUrl': imageUrl,
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
      'deviceTimestamp': DateTime.now().toUtc().toIso8601String(),
      if (livenessChallenge != null) 'livenessChallenge': livenessChallenge,
    };
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning/attendance',
      body: body,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getStationAttendanceStatus({
    String? runInstanceId,
    String? workerId,
  }) async {
    final params = <String, String>{};
    if (runInstanceId != null) params['runInstanceId'] = runInstanceId;
    if (workerId != null) params['workerId'] = workerId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning/attendance/status',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  // ─── ATTENDANCE LIST ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStationAttendanceList({String? stationId, String? runInstanceId}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    if (runInstanceId != null) params['runInstanceId'] = runInstanceId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning/attendance/list',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  // ─── ATTENDANCE EXCEPTIONS ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> reportAttendanceIssue({
    required String issueType,
    required String remark,
    String? attendanceType,
    String? runInstanceId,
    String? stationId,
    String? photoUrl,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      'issueType': issueType,
      'remark': remark,
      'attendanceType': attendanceType ?? '',
      'runInstanceId': runInstanceId ?? '',
      'stationId': stationId ?? '',
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning/attendance/report-issue',
      body: body,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getAttendanceExceptions({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning/attendance/exceptions',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> takeExceptionAction({
    required String exceptionId,
    required String action,
    String? adminRemark,
  }) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning/attendance/exceptions/action',
      body: {'exceptionId': exceptionId, 'action': action, if (adminRemark != null) 'adminRemark': adminRemark},
      parser: (d) => d,
    );
  }

  // ─── SUPERVISOR WORKERS ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createWorker(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning/workers/create',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listWorkers({String? stationId, String? supervisorId}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    if (supervisorId != null) params['supervisorId'] = supervisorId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning/workers/list',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> getWorker(String uid) async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning/workers/$uid',
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> updateWorker(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-cleaning/workers/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> deleteWorker(String uid) async {
    return await _apiCall(
      method: 'DELETE',
      path: '/api/station-cleaning/workers/$uid',
      parser: (d) => d,
    );
  }

  // ─── CLEANING SUBMISSIONS ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> createSubmission(Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'POST',
      path: '/api/station-cleaning/submissions',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listMySubmissions({String? date}) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning/submissions/my',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> listAllSubmissions({String? stationId, String? status, String? supervisorId}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    if (status != null) params['status'] = status;
    if (supervisorId != null) params['supervisorId'] = supervisorId;
    return await _apiCall(
      method: 'GET',
      path: '/api/station-cleaning/submissions/list',
      queryParams: params.isNotEmpty ? params : null,
      parser: (d) => d,
    );
  }

  static Future<Map<String, dynamic>> reviewSubmission(String uid, Map<String, dynamic> data) async {
    return await _apiCall(
      method: 'PUT',
      path: '/api/station-cleaning/submissions/$uid/review',
      body: data,
      parser: (d) => d,
    );
  }

  // ─── DASHBOARD ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboard() async {
    return await _apiCall(
      method: 'GET',
      path: '/api/station-dashboard',
      parser: (d) => d,
    );
  }
}
