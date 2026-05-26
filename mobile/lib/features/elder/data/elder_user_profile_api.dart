import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// 与后端 [ElderUserProfileView] 对应。
class ElderUserProfile {
  const ElderUserProfile({
    required this.name,
    required this.phone,
    this.gender,
    this.birthday,
    this.avatarUrl,
    this.claimed,
    this.familyCount,
  });

  final String name;
  final String phone;
  final String? gender;
  final String? birthday;
  final String? avatarUrl;
  final bool? claimed;
  final int? familyCount;

  static ElderUserProfile? fromData(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return ElderUserProfile(
      name: raw['name'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      gender: raw['gender'] as String?,
      birthday: raw['birthday'] as String?,
      avatarUrl: raw['avatarUrl'] as String? ?? raw['avatar_url'] as String?,
      claimed: raw['claimed'] as bool?,
      familyCount: raw['familyCount'] as int?,
    );
  }
}

final class ElderUserProfileApi {
  ElderUserProfileApi._();

  static Future<ElderUserProfile> fetchProfile() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/elder/profile');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, ElderUserProfile.fromData);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return api.data!;
  }

  static Future<ElderUserProfile> update({
    required String name,
    required String gender,
    String? birthday,
  }) async {
    final res = await ApiClient.dio.patch<Map<String, dynamic>>(
      '/v1/elder/profile',
      data: {
        'name': name,
        'gender': gender,
        'birthday': birthday,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, ElderUserProfile.fromData);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    return api.data!;
  }

  /// POST `/v1/elder/profile/avatar` — 上传头像，返回 `avatarUrl` 路径。
  static Future<String> uploadAvatar(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
    });
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/profile/avatar',
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw is Map<String, dynamic> ? raw : null);
    if (!api.isSuccess || api.data == null) throw Exception(api.displayMessage);
    final data = api.data!;
    final url = data['avatarUrl'] as String? ?? data['avatar_url'] as String?;
    if (url == null || url.isEmpty) throw Exception('未返回头像地址');
    return url;
  }
}
