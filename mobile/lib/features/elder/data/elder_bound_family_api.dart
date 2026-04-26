import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../models/elder_bound_child.dart';

/// `GET /v1/elder/bound-children` — 当前登录老人在 `family_bindings` 中的子女。
final class ElderBoundFamilyApi {
  ElderBoundFamilyApi._();

  static Future<List<ElderBoundChild>> list() async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>('/v1/elder/bound-children');
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
    return list.map(ElderBoundChild.fromJson).toList();
  }
}
