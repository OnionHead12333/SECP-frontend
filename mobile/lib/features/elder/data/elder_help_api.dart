import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_help_request.dart';

final class ElderHelpApi {
  ElderHelpApi._();

  static Future<ElderHelpRequest> createHelpRequest() async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/emergency-alerts',
      data: {
        'alertType': 'sos',
        'triggerMode': 'button',
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    return ElderHelpRequest.fromJson(api.data!);
  }

  static Future<ElderHelpRequest> revokeHelpRequest({
    required int alertId,
    required String cancelMode,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/emergency-alerts/$alertId/revoke',
      data: {'cancelMode': cancelMode},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    return ElderHelpRequest.fromJson(api.data!);
  }

  static Future<ElderHelpRequest> sendNow({required int alertId}) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/emergency-alerts/$alertId/send-now',
      data: const {},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    return ElderHelpRequest.fromJson(api.data!);
  }

  static Future<ElderHelpRequest> getHelpRequestStatus({required int alertId}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/elder/emergency-alerts/$alertId');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    return ElderHelpRequest.fromJson(api.data!);
  }
}
