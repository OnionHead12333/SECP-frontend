import '../models/child_local_models.dart';
import 'child_bound_elders_api.dart';

/// 老人列表仅来自服务端 `family_bindings`（见 `GET /v1/child/bound-elders`）。
final class ChildElderDirectoryService {
  ChildElderDirectoryService._();

  static Future<List<BoundElder>> resolveElders() async {
    try {
      return await ChildBoundEldersApi.list();
    } catch (_) {
      return [];
    }
  }
}
