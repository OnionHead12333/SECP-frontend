import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/child_local_models.dart';

/// `GET/POST/PATCH/DELETE` `/v1/children/elders/{elderId}/emergency-contacts`
final class ChildEmergencyContactsApi {
  ChildEmergencyContactsApi._();

  static String _root(int elderId) => '/v1/children/elders/$elderId/emergency-contacts';

  static Future<List<EmergencyContact>> list(int elderId) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(_root(elderId));
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) {
        if (raw is! List) return <Map<String, dynamic>>[];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
    if (!api.isSuccess) throw Exception(api.message);
    final list = api.data ?? const <Map<String, dynamic>>[];
    return list.map(_fromRow).toList();
  }

  static EmergencyContact _fromRow(Map<String, dynamic> j) {
    return EmergencyContact(
      id: '${j['id']}',
      elderId: '${j['elderId'] ?? j['elder_id'] ?? ''}',
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      priority: (j['priority'] as num?)?.toInt() ?? 1,
      relation: j['relation'] as String?,
    );
  }

  static Future<void> add({
    required int elderId,
    required String name,
    required String phone,
    required int priority,
    String? relation,
  }) async {
    final res = await ApiClient.dio.post<Map<String, dynamic>>(
      _root(elderId),
      data: {
        'name': name,
        'phone': phone,
        'priority': priority,
        'relation': relation ?? '联系人',
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.message);
  }

  static Future<void> update({
    required int elderId,
    required int contactId,
    String? name,
    String? phone,
    int? priority,
    String? relation,
  }) async {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (phone != null) map['phone'] = phone;
    if (priority != null) map['priority'] = priority;
    if (relation != null) map['relation'] = relation;
    final res = await ApiClient.dio.patch<Map<String, dynamic>>(
      '${_root(elderId)}/$contactId',
      data: map,
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.message);
  }

  static Future<void> delete({required int elderId, required int contactId}) async {
    final res = await ApiClient.dio.delete<Map<String, dynamic>>('${_root(elderId)}/$contactId');
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.message);
  }
}
