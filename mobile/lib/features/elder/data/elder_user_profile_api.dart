import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';

/// 与后端 [ElderUserProfileView] 对应。
class ElderUserProfile {
  const ElderUserProfile({
    required this.name,
    required this.phone,
    this.gender,
    this.birthday,
    this.claimed,
    this.familyCount,
  });

  final String name;
  final String phone;
  final String? gender;
  final String? birthday;
  final bool? claimed;
  final int? familyCount;

  static ElderUserProfile? fromData(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return ElderUserProfile(
      name: raw['name'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      gender: raw['gender'] as String?,
      birthday: raw['birthday'] as String?,
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
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
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
    if (!api.isSuccess || api.data == null) throw Exception(api.message);
    return api.data!;
  }
}
