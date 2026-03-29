import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// 全局 HTTP 客户端，统一 Base URL 与超时。
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
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? '请求失败';
  }
}
