import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// `GET /v1/child/elders/{elderId}/home-geofence` — 取「家」大致中心，用于画回家路线
final class ChildGeofenceApi {
  ChildGeofenceApi._();

  static Future<HomeGeofencePoint?> firstHomePoint(int elderId) async {
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
      return HomeGeofencePoint.fromJson(Map<String, dynamic>.from(data.first as Map));
    } catch (_) {
      return null;
    }
  }
}

class HomeGeofencePoint {
  const HomeGeofencePoint({required this.latitude, required this.longitude, this.name});

  final double latitude;
  final double longitude;
  final String? name;

  factory HomeGeofencePoint.fromJson(Map<String, dynamic> j) {
    final lat = j['centerLatitude'];
    final lng = j['centerLongitude'];
    return HomeGeofencePoint(
      latitude: lat is num ? lat.toDouble() : double.parse('$lat'),
      longitude: lng is num ? lng.toDouble() : double.parse('$lng'),
      name: j['name'] as String?,
    );
  }
}
