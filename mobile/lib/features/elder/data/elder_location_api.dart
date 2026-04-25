import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_location_point.dart';

final class ElderLocationApi {
  ElderLocationApi._();

  static Future<LocationPermissionSnapshot> fetchPermission() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/elder/location-permissions');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? LocationPermissionSnapshot.fromJson(raw) : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  static Future<LocationPermissionSnapshot> updatePermission({
    required bool foregroundGranted,
    required bool backgroundGranted,
    required DateTime permissionUpdatedAt,
  }) async {
    final res = await ApiClient.dio.put<Map<String, dynamic>>(
      '/v1/elder/location-permissions',
      data: {
        'foregroundGranted': foregroundGranted,
        'backgroundGranted': backgroundGranted,
        'permissionUpdatedAt': permissionUpdatedAt.toLocal().toIso8601String(),
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? LocationPermissionSnapshot.fromJson(raw) : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    return api.data!;
  }

  static Future<int> uploadLocation({
    required double latitude,
    required double longitude,
    required String locationType,
    required String source,
    required DateTime recordedAt,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/location-tracks',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'locationType': locationType,
        'source': source,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    final locationId = api.data!['locationId'];
    if (locationId is int) return locationId;
    if (locationId is num) return locationId.toInt();
    throw Exception('定位上传响应缺少 locationId');
  }

  static Future<List<ElderLocationPoint>> fetchTrack({required String elderPhone}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/elder/location-tracks',
      queryParameters: {'elderPhone': elderPhone},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is List
          ? raw.whereType<Map<String, dynamic>>().map(_pointFromJson).toList()
          : const <ElderLocationPoint>[],
    );
    if (!api.isSuccess) throw Exception(api.message);
    return api.data ?? const <ElderLocationPoint>[];
  }

  static ElderLocationPoint _pointFromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (json['longitude'] as num?)?.toDouble() ?? 0;
    final recordedAtRaw = json['recordedAt']?.toString();
    final recordedAt = recordedAtRaw == null ? DateTime.now() : DateTime.tryParse(recordedAtRaw)?.toLocal() ?? DateTime.now();
    final locationType = json['locationType']?.toString() ?? 'outdoor';
    final source = json['source']?.toString() ?? 'gaode';
    final isHome = json['isHome'] == true || locationType == 'indoor';
    return ElderLocationPoint(
      latitude: latitude,
      longitude: longitude,
      label: json['label']?.toString() ?? (isHome ? '家附近轨迹点' : '外出轨迹点'),
      recordedAt: recordedAt,
      isHome: isHome,
      source: source,
      locationType: locationType,
      uploaded: true,
    );
  }
}

class LocationPermissionSnapshot {
  const LocationPermissionSnapshot({
    required this.foregroundGranted,
    required this.backgroundGranted,
    this.permissionUpdatedAt,
  });

  final bool foregroundGranted;
  final bool backgroundGranted;
  final DateTime? permissionUpdatedAt;

  factory LocationPermissionSnapshot.fromJson(Map<String, dynamic> json) {
    final updatedRaw = json['permissionUpdatedAt']?.toString();
    return LocationPermissionSnapshot(
      foregroundGranted: json['foregroundGranted'] == true,
      backgroundGranted: json['backgroundGranted'] == true,
      permissionUpdatedAt: updatedRaw == null ? null : DateTime.tryParse(updatedRaw)?.toLocal(),
    );
  }
}
