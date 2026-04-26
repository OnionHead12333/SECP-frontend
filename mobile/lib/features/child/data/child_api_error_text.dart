import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';

/// 将接口异常转成用户可读说明（不暴露敏感堆栈）。
String describeChildApiError(Object? error) {
  if (error == null) return '未知错误';
  if (error is DioException) {
    final sc = error.response?.statusCode;
    if (sc == 401) {
      return '未授权（HTTP 401）\n'
          '请用子女端账号正常登录，且 token 能通过后端的 JWT 校验。\n'
          '仅输入「123123」等演示账号时，需后端在 dev 环境支持 demo token；'
          '否则请使用数据库里已存在的子女用户密码登录。';
    }
    if (sc == 403) {
      return '无访问权限（HTTP 403）\n'
          '可能原因：当前不是子女角色、或该老人与账号无 family 绑定。';
    }
    if (sc == 404) {
      return '未找到（HTTP 404）\n请确认已绑定该老人，且后端存在对应数据。';
    }
    if (sc != null && sc >= 500) {
      return '服务器错误（HTTP $sc）\n请稍后重试或查看后端日志。';
    }
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
      return '连接超时\n请检查手机与「${AppConfig.apiBase}」网络互通（同 Wi‑Fi、端口、防火墙）';
    }
    if (error.type == DioExceptionType.connectionError) {
      return '无法连接服务器\n请确认后端已启动，且能访问\n${AppConfig.apiBase}';
    }
    final d = error.response?.data;
    if (d is Map && d['message'] is String) {
      final m = d['message'] as String;
      if (m.isNotEmpty) return '服务端：$m';
    }
    final msg = error.message;
    if (msg != null && msg.isNotEmpty) {
      return msg;
    }
  }
  var s = error.toString();
  if (s.startsWith('Exception: ')) {
    s = s.substring(11);
  }
  return s;
}
