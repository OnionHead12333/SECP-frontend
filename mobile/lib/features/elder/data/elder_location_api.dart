import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

final class ElderLocationApi {
  ElderLocationApi._();

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
}
