import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// `GET/PUT /v1/child/elders/{elderId}/home-geofence`
final class ChildGeofenceApi {
  ChildGeofenceApi._();

  static const int defaultRadiusMeters = 500;

  static Future<HomeGeofenceConfig?> fetchHome(int elderId) async {
    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/v1/child/elders/$elderId/home-geofence',
      );
      final body = res.data;
      if (body == null) return null;
      final api = ApiResponse.fromJson(body, (raw) {
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        return null;
      });
      if (!api.isSuccess) return null;
      final data = api.data;
      if (data == null || data.isEmpty) return null;
      return HomeGeofenceConfig.fromJson(Map<String, dynamic>.from(data.first as Map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveHome({
    required int elderId,
    required double latitude,
    required double longitude,
    required int radius,
    String name = '家',
  }) async {
    final res = await ApiClient.dio.put<Map<String, dynamic>>(
      '/v1/child/elders/$elderId/home-geofence',
      data: {
        'name': name,
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

  /// 兼容旧调用：取家围栏中心画路线。
  static Future<HomeGeofencePoint?> firstHomePoint(int elderId) async {
    final home = await fetchHome(elderId);
    if (home == null) return null;
    return HomeGeofencePoint(
      latitude: home.latitude,
      longitude: home.longitude,
      name: home.name,
      radius: home.radius,
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

  factory HomeGeofenceConfig.fromJson(Map<String, dynamic> j) {
    final lat = j['centerLatitude'];
    final lng = j['centerLongitude'];
    return HomeGeofenceConfig(
      name: j['name'] as String? ?? '家',
      latitude: lat is num ? lat.toDouble() : double.parse('$lat'),
      longitude: lng is num ? lng.toDouble() : double.parse('$lng'),
      radius: (j['radius'] as num?)?.toInt() ?? ChildGeofenceApi.defaultRadiusMeters,
      enabled: j['enabled'] == true || j['isEnabled'] == true,
    );
  }
}

class HomeGeofencePoint {
  const HomeGeofencePoint({
    required this.latitude,
    required this.longitude,
    this.name,
    this.radius,
  });

  final double latitude;
  final double longitude;
  final String? name;
  final int? radius;
}
