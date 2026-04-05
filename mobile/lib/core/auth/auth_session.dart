/// 简单登录态占位；后续可改为 secure_storage / riverpod 等。
final class AuthSession {
  AuthSession._();

  static String? token;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  static void clear() => token = null;
}
