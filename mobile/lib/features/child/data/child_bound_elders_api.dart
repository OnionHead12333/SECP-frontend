import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/child_local_models.dart';

/// `GET /v1/child/bound-elders` — 仅家庭绑定表中的老人。
final class ChildBoundEldersApi {
  ChildBoundEldersApi._();

  static Future<List<BoundElder>> list() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/child/bound-elders');
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

  static BoundElder _fromRow(Map<String, dynamic> j) {
    final id = '${j['elderProfileId'] ?? j['elder_profile_id'] ?? ''}'.trim();
    final name = j['name'] as String? ?? '老人';
    final phone = j['phone'] as String?;
    final relation = j['relation'] as String?;
    final primary = j['isPrimary'] == true || j['is_primary'] == true;
    final hint = <String>[
      if (relation != null && relation.isNotEmpty) '关系：$relation',
      if (primary) '主联系人',
      if (phone != null && phone.isNotEmpty) phone,
    ].join(' · ');
    return BoundElder(
      id: id,
      displayName: name,
      accountHint: hint.isEmpty ? '家庭绑定' : hint,
    );
  }
}
