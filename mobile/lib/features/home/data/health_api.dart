import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// 健康检查：GET /api/v1/health
final class HealthApi {
  HealthApi._();

  static Future<ApiResponse<Map<String, dynamic>>> fetchHealth() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/health');
    final body = res.data;
    if (body == null) {
      return const ApiResponse(code: -1, message: '空响应', data: null);
    }
    return ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
  }
}
