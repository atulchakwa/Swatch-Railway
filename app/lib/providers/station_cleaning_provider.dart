import 'package:flutter/material.dart';
import '../repositories/base_repository.dart';
import '../model/user_model.dart';

class StationCleaningProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  String? _selectedStationId;
  String? _selectedStationName;
  String? _selectedPlatformId;
  String? _selectedPlatformName;
  String? _selectedAreaId;
  String? _selectedAreaName;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedStationId => _selectedStationId;
  String? get selectedStationName => _selectedStationName;
  String? get selectedPlatformId => _selectedPlatformId;
  String? get selectedPlatformName => _selectedPlatformName;
  String? get selectedAreaId => _selectedAreaId;
  String? get selectedAreaName => _selectedAreaName;

  void setUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  void setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void setError(String? e) {
    _error = e;
    notifyListeners();
  }

  void selectStation(String id, String name) {
    _selectedStationId = id;
    _selectedStationName = name;
    _selectedPlatformId = null;
    _selectedPlatformName = null;
    _selectedAreaId = null;
    _selectedAreaName = null;
    notifyListeners();
  }

  void selectPlatform(String id, String name) {
    _selectedPlatformId = id;
    _selectedPlatformName = name;
    _selectedAreaId = null;
    _selectedAreaName = null;
    notifyListeners();
  }

  void selectArea(String id, String name) {
    _selectedAreaId = id;
    _selectedAreaName = name;
    notifyListeners();
  }

  void clearSelection() {
    _selectedStationId = null;
    _selectedStationName = null;
    _selectedPlatformId = null;
    _selectedPlatformName = null;
    _selectedAreaId = null;
    _selectedAreaName = null;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchStations() async {
    try {
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/stations',
        parser: (d) => d,
      );
      return (result['stations'] as List? ?? result['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      setError(e.toString());
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPlatforms(String stationId) async {
    try {
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/platforms/by-station/$stationId',
        parser: (d) => d,
      );
      return (result['platforms'] as List? ?? result['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      setError(e.toString());
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAreas(String stationId, {String? platformId}) async {
    try {
      final params = <String, String>{};
      if (platformId != null) params['platformId'] = platformId;
      final result = await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/areas/by-station/$stationId',
        parser: (d) => d,
        queryParams: params.isNotEmpty ? params : null,
      );
      return (result['areas'] as List? ?? result['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      setError(e.toString());
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchWorkerDashboard(String workerId, {String? date}) async {
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      return await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-cleaning/dashboard/worker/$workerId',
        parser: (d) => d,
        queryParams: params.isNotEmpty ? params : null,
      );
    } catch (e) {
      setError(e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSupervisorDashboard(String supervisorId, {String? date}) async {
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      return await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-cleaning/dashboard/supervisor/$supervisorId',
        parser: (d) => d,
        queryParams: params.isNotEmpty ? params : null,
      );
    } catch (e) {
      setError(e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchDailyReport(String stationId, {String? date}) async {
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      return await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-cleaning/reports/daily/$stationId',
        parser: (d) => d,
        queryParams: params.isNotEmpty ? params : null,
      );
    } catch (e) {
      setError(e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchWeeklyReport(String stationId, {String? endDate}) async {
    try {
      final params = <String, String>{};
      if (endDate != null) params['endDate'] = endDate;
      return await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-cleaning/reports/weekly/$stationId',
        parser: (d) => d,
        queryParams: params.isNotEmpty ? params : null,
      );
    } catch (e) {
      setError(e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchMonthlyReport(String stationId, {int? month, int? year}) async {
    try {
      final params = <String, String>{};
      if (month != null) params['month'] = month.toString();
      if (year != null) params['year'] = year.toString();
      return await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-cleaning/reports/monthly/$stationId',
        parser: (d) => d,
        queryParams: params.isNotEmpty ? params : null,
      );
    } catch (e) {
      setError(e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchScoreTrend(String stationId, {int? months}) async {
    try {
      final params = <String, String>{};
      if (months != null) params['months'] = months.toString();
      return await BaseRepository.apiCall(
        method: 'GET',
        path: '/api/station-cleaning/reports/score-trend/$stationId',
        parser: (d) => d,
        queryParams: params.isNotEmpty ? params : null,
      );
    } catch (e) {
      setError(e.toString());
      return null;
    }
  }

  Future<bool> requestMachineReplacement(String machineId, {required String reason, String? replacementMachineType, String? notes}) async {
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/machines/$machineId/replacement/request',
        body: {'reason': reason, if (replacementMachineType != null) 'replacementMachineType': replacementMachineType, if (notes != null) 'notes': notes},
        parser: (d) => d,
      );
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    }
  }

  Future<bool> approveMachineReplacement(String requestId, {required bool approved, String? rejectionReason, String? newSerialNumber, String? newMachineName}) async {
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/machines/replacement/$requestId/approve',
        body: {'approved': approved, if (rejectionReason != null) 'rejectionReason': rejectionReason, if (newSerialNumber != null) 'newSerialNumber': newSerialNumber, if (newMachineName != null) 'newMachineName': newMachineName},
        parser: (d) => d,
      );
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    }
  }

  Future<bool> createMaterialReorderRequest(String materialId, {required int quantity, String? reason, String? stationId}) async {
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/materials/reorder-request',
        body: {'materialId': materialId, 'quantity': quantity, if (reason != null) 'reason': reason, if (stationId != null) 'stationId': stationId},
        parser: (d) => d,
      );
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    }
  }

  Future<bool> approveMaterialReorderRequest(String requestId, {required bool approved, String? rejectionReason}) async {
    try {
      await BaseRepository.apiCall(
        method: 'POST',
        path: '/api/materials/reorder-request/$requestId/approve',
        body: {'approved': approved, if (rejectionReason != null) 'rejectionReason': rejectionReason},
        parser: (d) => d,
      );
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    }
  }
}
