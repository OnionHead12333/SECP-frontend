import 'app_role.dart';

/// 简单登录态占位；后续可改为 secure_storage / riverpod 等。
final class AuthSession {
  AuthSession._();

  static String? token;

  /// 当前以何种端展示（子女端 / 老人端等）。
  static AppRole? role;

  /// 老人端首页展示所需的基础状态。
  static String? elderName;
  /// 与后端 users.gender 一致：male / female / unknown
  static String? elderGender;
  /// yyyy-MM-dd，未设置时为 null
  static String? elderBirthday;
  static bool elderClaimed = false;
  static int elderFamilyCount = 0;
  static String? elderPhone;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  static void saveElderState({
    required String name,
    required String phone,
    required bool claimed,
    required int familyCount,
    String? gender,
    String? birthday,
  }) {
    elderName = name;
    elderPhone = phone;
    elderClaimed = claimed;
    elderFamilyCount = familyCount;
    elderGender = gender;
    elderBirthday = birthday;
  }

  static void clear() {
    token = null;
    role = null;
    elderName = null;
    elderPhone = null;
    elderGender = null;
    elderBirthday = null;
    elderClaimed = false;
    elderFamilyCount = 0;
  }
}
