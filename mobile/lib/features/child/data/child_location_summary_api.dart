import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// `GET /v1/child/elders/{elderId}/location-summary`
final class ChildLocationSummaryApi {
  ChildLocationSummaryApi._();

  static Future<ChildLocationSummary?> fetch(int elderId) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/child/elders/$elderId/location-summary',
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) {
        if (raw is! Map) return null;
        return Map<String, dynamic>.from(raw);
      },
    );
    if (!api.isSuccess) throw Exception(api.message);
    final m = api.data;
    if (m == null) return null;
    return ChildLocationSummary.fromJson(m);
  }
}

class ChildLocationSummary {
  const ChildLocationSummary({
    required this.latitude,
    required this.longitude,
    this.address,
    this.isHome,
    this.presenceSource,
    this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final String? address;
  final bool? isHome;
  final String? presenceSource;
  final String? updatedAt;

  factory ChildLocationSummary.fromJson(Map<String, dynamic> j) {
    final lat = j['latitude'];
    final lng = j['longitude'];
    return ChildLocationSummary(
      latitude: lat is num ? lat.toDouble() : double.parse('$lat'),
      longitude: lng is num ? lng.toDouble() : double.parse('$lng'),
      address: j['address'] as String?,
      isHome: j['isHome'] as bool?,
      presenceSource: j['presenceSource'] as String?,
      updatedAt: j['updatedAt'] as String?,
    );
  }
}
