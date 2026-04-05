import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// 与计划中的后端约定：POST /api/v1/auth/login、/register
final class AuthApi {
  AuthApi._();

  static Future<String> login({
    required String username,
    required String password,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {'username': username, 'password': password},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess) throw Exception(api.message);
    final token = api.data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('登录成功但未返回 token');
    }
    return token;
  }

  static Future<void> register({
    required String username,
    required String password,
    required String role,
    String? phone,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {
        'username': username,
        'password': password,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    if (!api.isSuccess) throw Exception(api.message);
  }
}
