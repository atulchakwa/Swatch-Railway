import 'base_repository.dart';
import '../model/platform_model.dart';

class PlatformRepository {
  static Future<List<Platform>> getByStation(String stationId) async {
    final all = await BaseRepository.apiCallList<Platform>(
      method: 'GET',
      path: '/api/platforms/by-station/$stationId',
      parser: (json) => Platform.fromJson(json),
      dataKey: 'platforms',
    );
    // Deduplicate by uid/platformNumber to prevent Flutter dropdown assertion errors
    final seenIds = <String>{};
    return all.where((p) {
      final id = p.uid ?? p.platformNumber;
      if (id.isEmpty) return false;
      return seenIds.add(id);
    }).toList();
  }

  static Future<List<Platform>> getAll({String? stationId, String? status}) async {
    final params = <String, String>{};
    if (stationId != null) params['stationId'] = stationId;
    if (status != null) params['status'] = status;
    return BaseRepository.apiCallList<Platform>(
      method: 'GET',
      path: '/api/platforms',
      queryParams: params.isNotEmpty ? params : null,
      parser: (json) => Platform.fromJson(json),
      dataKey: 'platforms',
    );
  }

  static Future<Platform> getById(String uid) async {
    return BaseRepository.apiCall<Platform>(
      method: 'GET',
      path: '/api/platforms/$uid',
      parser: (json) => Platform.fromJson(json),
    );
  }

  static Future<void> create(Map<String, dynamic> data) async {
    await BaseRepository.apiCall(
      method: 'POST',
      path: '/api/platforms',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<void> update(String uid, Map<String, dynamic> data) async {
    await BaseRepository.apiCall(
      method: 'PUT',
      path: '/api/platforms/$uid',
      body: data,
      parser: (d) => d,
    );
  }

  static Future<void> delete(String uid) async {
    await BaseRepository.apiCall(
      method: 'DELETE',
      path: '/api/platforms/$uid',
      parser: (d) => d,
    );
  }
}
