import 'app_role.dart';

/// 简单登录态占位；后续可改为 secure_storage / riverpod 等。
final class AuthSession {
  AuthSession._();

  static String? token;

  /// 当前以何种端展示（子女端 / 老人端等）。
  static AppRole? role;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  static void clear() {
    token = null;
    role = null;
  }
}
