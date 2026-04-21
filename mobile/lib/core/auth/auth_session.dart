import 'app_role.dart';

/// 简单登录态占位；后续可改为 secure_storage / riverpod 等。
final class AuthSession {
  AuthSession._();

  static String? token;

  /// 当前以何种端展示（子女端 / 老人端等）。
  static AppRole? role;

  /// 老人端首页展示所需的基础状态。
  static String? elderName;
  static bool elderClaimed = false;
  static int elderFamilyCount = 0;
  static String? elderPhone;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  static void saveElderState({
    required String name,
    required String phone,
    required bool claimed,
    required int familyCount,
  }) {
    elderName = name;
    elderPhone = phone;
    elderClaimed = claimed;
    elderFamilyCount = familyCount;
  }

  static void clear() {
    token = null;
    role = null;
    elderName = null;
    elderPhone = null;
    elderClaimed = false;
    elderFamilyCount = 0;
  }
}
