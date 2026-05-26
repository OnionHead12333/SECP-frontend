import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../config/app_config.dart';
import '../util/api_user_message.dart';

/// 全局 HTTP 客户端，统一 Base URL、超时和 token 注入。
final class ApiClient {
  ApiClient._();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AuthSession.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          handler.next(options);
        },
        onError: (e, handler) {
          final msg = _extractMessage(e);
          handler.next(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: Exception(msg),
              message: msg,
            ),
          );
        },
      ),
    );

  static String _extractMessage(DioException e) {
    final data = e.response?.data;
    String raw;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) {
        raw = msg;
      } else {
        raw = e.message ?? '请求失败';
      }
      final code = data['code'];
      if (code != null && code != 0 && raw == (e.message ?? '')) {
        raw = '$raw (code=$code)';
      }
    } else {
      raw = e.message ?? '请求失败';
    }
    final status = e.response?.statusCode;
    if (status != null && status >= 400 && !raw.contains('$status')) {
      raw = '$raw (HTTP $status)';
    }
    return userFacingApiMessage(raw);
  }
}
