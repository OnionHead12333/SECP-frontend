import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_emergency_contact.dart';

final class ElderEmergencyContactsApi {
  ElderEmergencyContactsApi._();

  /// 根据登录态解析老人手机号，无需传 `elderPhone`（推荐）。
  static Future<List<ElderEmergencyContact>> fetchContactsForCurrentElder() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/elder/emergency-contacts/self',
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is List
          ? raw.whereType<Map<String, dynamic>>().map(ElderEmergencyContact.fromJson).toList()
          : const <ElderEmergencyContact>[],
    );
    if (!api.isSuccess) throw Exception(api.message);
    return api.data ?? const <ElderEmergencyContact>[];
  }

  static Future<List<ElderEmergencyContact>> fetchContacts({required String elderPhone}) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/elder/emergency-contacts',
      queryParameters: {'elderPhone': elderPhone},
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is List
          ? raw.whereType<Map<String, dynamic>>().map(ElderEmergencyContact.fromJson).toList()
          : const <ElderEmergencyContact>[],
    );
    if (!api.isSuccess) throw Exception(api.message);
    return api.data ?? const <ElderEmergencyContact>[];
  }

  static Future<List<ElderEmergencyContact>> addContact({
    required String elderPhone,
    required String name,
    required String relation,
    required String contactPhone,
    required String note,
    required bool makePrimary,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      '/v1/elder/emergency-contacts',
      data: {
        'elderPhone': elderPhone,
        'name': name,
        'relation': relation,
        'phone': contactPhone,
        'note': note,
        'isPrimary': makePrimary,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) => raw is List
          ? raw.whereType<Map<String, dynamic>>().map(ElderEmergencyContact.fromJson).toList()
          : const <ElderEmergencyContact>[],
    );
    if (!api.isSuccess) throw Exception(api.message);
    return api.data ?? const <ElderEmergencyContact>[];
  }
}
