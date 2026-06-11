import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_location_guard_setting.dart';
import '../models/elder_location_point.dart';

final class ElderLocationApi {
  ElderLocationApi._();

  static Future<ElderLocationGuardSetting> fetchGuardSetting() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/elder/location-guard');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? ElderLocationGuardSetting.fromJson(raw) : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return api.data!;
  }

  static Future<ElderLocationGuardSetting> startGuard({
    required String mode,
    required int intervalSeconds,
    required int outsideIntervalSeconds,
    required bool foregroundGranted,
    required bool backgroundGranted,
    bool backgroundRequired = true,
    bool batteryOptimizationIgnored = false,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/location-guard/start',
      data: {
        'mode': mode,
        'intervalSeconds': intervalSeconds,
        'outsideIntervalSeconds': outsideIntervalSeconds,
        'backgroundRequired': backgroundRequired,
        'foregroundGranted': foregroundGranted,
        'backgroundGranted': backgroundGranted,
        'batteryOptimizationIgnored': batteryOptimizationIgnored,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? ElderLocationGuardSetting.fromJson(raw) : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return api.data!;
  }

  static Future<ElderLocationGuardSetting> stopGuard() async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>('/v1/elder/location-guard/stop');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? ElderLocationGuardSetting.fromJson(raw) : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return api.data!;
  }

  static Future<ElderLocationGuardSetting> syncGuardPermissions({
    required bool foregroundGranted,
    required bool backgroundGranted,
    bool batteryOptimizationIgnored = false,
  }) async {
    final res = await ApiClient.dio.put<Map<String, dynamic>>(
      '/v1/elder/location-guard/permissions',
      data: {
        'foregroundGranted': foregroundGranted,
        'backgroundGranted': backgroundGranted,
        'batteryOptimizationIgnored': batteryOptimizationIgnored,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? ElderLocationGuardSetting.fromJson(raw) : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return api.data!;
  }

  static Future<void> reportGuardError(String message) async {
    await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/location-guard/error',
      data: {'message': message},
    );
  }

  static Future<LocationPermissionSnapshot> fetchPermission() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/elder/location-permissions');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? LocationPermissionSnapshot.fromJson(raw) : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
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
        // 与子女端提醒等接口一致：发往服务端的时间戳统一用 UTC ISO8601
        'permissionUpdatedAt': permissionUpdatedAt.toUtc().toIso8601String(),
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? LocationPermissionSnapshot.fromJson(raw) : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
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
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
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
    if (!api.isSuccess) throw Exception(api.displayMessage);
    return api.data ?? const <ElderLocationPoint>[];
  }

  static Future<List<HomeGeofenceConfig>> fetchHomeGeofence() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/elder/home-geofence');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) {
        if (raw is! List) return const <HomeGeofenceConfig>[];
        return raw
            .whereType<Map>()
            .map((e) => HomeGeofenceConfig.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
    if (!api.isSuccess) throw Exception(api.displayMessage);
    return api.data ?? const <HomeGeofenceConfig>[];
  }

  static Future<void> saveHomeGeofence({
    required double latitude,
    required double longitude,
    int radius = 500,
  }) async {
    final res = await ApiClient.dio.put<Map<String, dynamic>>(
      '/v1/elder/home-geofence',
      data: {
        'name': '家',
        'centerLatitude': latitude,
        'centerLongitude': longitude,
        'radius': radius,
        'enabled': true,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.displayMessage);
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

class HomeGeofenceConfig {
  const HomeGeofenceConfig({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.enabled,
  });

  final String name;
  final double latitude;
  final double longitude;
  final int radius;
  final bool enabled;

  factory HomeGeofenceConfig.fromJson(Map<String, dynamic> json) {
    final lat = json['centerLatitude'];
    final lng = json['centerLongitude'];
    return HomeGeofenceConfig(
      name: json['name'] as String? ?? '家',
      latitude: lat is num ? lat.toDouble() : double.parse('$lat'),
      longitude: lng is num ? lng.toDouble() : double.parse('$lng'),
      radius: (json['radius'] as num?)?.toInt() ?? 500,
      enabled: json['enabled'] == true || json['isEnabled'] == true,
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
