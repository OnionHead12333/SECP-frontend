import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// 子女端求助记录：GET/POST `/v1/child/emergency-alerts`
final class ChildEmergencyAlertsApi {
  ChildEmergencyAlertsApi._();

  static Future<Map<String, dynamic>> list({int page = 1, int pageSize = 100, String? status}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/child/emergency-alerts',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.message);
    final data = api.data;
    if (data is! Map) {
      throw Exception('数据格式错误');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<void> handle({
    required int alertId,
    required String action,
    String? remark,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/child/emergency-alerts/$alertId/handle',
      data: {
        'action': action,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.message);
  }
}
