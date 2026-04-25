import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

final class LoginResult {
  const LoginResult({
    required this.token,
    required this.role,
    this.name,
    this.phone,
    this.nickname,
    this.claimed,
    this.familyCount,
  });

  final String token;
  final String role;
  final String? name;
  final String? phone;
  final String? nickname;
  final bool? claimed;
  final int? familyCount;
}

final class RegisterResult {
  const RegisterResult({
    this.userId,
    this.username,
    this.role,
    this.name,
    this.phone,
    this.nickname,
  });

  final int? userId;
  final String? username;
  final String? role;
  final String? name;
  final String? phone;
  final String? nickname;
}

/// 与计划中的后端约定：POST /api/v1/auth/login、/register
final class AuthApi {
  AuthApi._();

  static Future<LoginResult> login({
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
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    final data = api.data!;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('登录成功但未返回 token');
    }
    final role = data['role'] as String?;
    if (role == null || role.isEmpty) {
      throw Exception('登录成功但未返回 role');
    }
    return LoginResult(
      token: token,
      role: role,
      name: data['name'] as String?,
      phone: data['phone'] as String?,
      nickname: data['nickname'] as String?,
      claimed: data['claimed'] as bool?,
      familyCount: data['familyCount'] as int?,
    );
  }

  static Future<void> register({
    required String username,
    required String password,
    required String role,
    String? phone,
    String? name,
    String? nickname,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {
        'username': username,
        'password': password,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (name != null && name.isNotEmpty) 'name': name,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
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

  /// 子女注册并一次创建/绑定多个老人主体（按 `注册绑定流程设计.md` 首版设计）。
  static Future<void> registerChildWithElders({
    required String childName,
    required String childPhone,
    required String password,
    required List<Map<String, String>> elders,
    String? childNickname,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/auth/register-child-with-elders',
      data: {
        'child': {
          'name': childName,
          'phone': childPhone,
          if (childNickname != null && childNickname.isNotEmpty) 'nickname': childNickname,
          'password': password,
        },
        'elders': elders,
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
