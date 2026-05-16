import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_outing_status.dart';

final class ElderOutingReminderService {
  ElderOutingReminderService._();

  static Future<ElderOutingStatus> fetchStatus({required int elderId}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/elder/outing/status',
      queryParameters: {'elderId': elderId},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return ElderOutingStatus.fromJson(api.data!);
  }

  static Future<void> uploadLocation({
    required int elderId,
    required double latitude,
    required double longitude,
    required String source,
  }) async {
    await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/location/upload',
      data: {
        'elderId': elderId,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}
