import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/child_local_models.dart';
import 'child_emergency_alerts_api.dart';

const _kManualElders = 'child_manual_elder_ids_v1';
const _kHiddenElderIds = 'child_hidden_elder_ids_v1';

/// 在缺少「我的老人列表」独立接口时：从求助记录合并本地手动填写的 `elderProfileId`。
final class ChildElderDirectoryService {
  ChildElderDirectoryService._();

  static Future<Set<String>> _hidden() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kHiddenElderIds);
    if (raw == null) return {};
    return raw.toSet();
  }

  static Future<void> hideElder(String elderId) async {
    final p = await SharedPreferences.getInstance();
    final s = await _hidden();
    s.add(elderId);
    await p.setStringList(_kHiddenElderIds, s.toList());
  }

  static Future<List<BoundElder>> _loadManual() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kManualElders);
    if (s == null || s.isEmpty) return [];
    final decoded = jsonDecode(s);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map(
          (e) => BoundElder(
            id: '${e['id'] ?? ''}'.trim(),
            displayName: '${e['name'] ?? '老人'}',
            accountHint: e['hint'] as String?,
          ),
        )
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  static Future<void> saveManualElder({required String elderId, required String displayName, String? hint}) async {
    final list = await _loadManual();
    final next = <Map<String, Object?>>[
      ...list.where((e) => e.id != elderId).map(
            (e) => {'id': e.id, 'name': e.displayName, 'hint': e.accountHint},
          ),
      {'id': elderId, 'name': displayName, 'hint': hint},
    ];
    final p = await SharedPreferences.getInstance();
    await p.setString(_kManualElders, jsonEncode(next));
  }

  static Future<void> removeManualElder(String elderId) async {
    final list = await _loadManual();
    list.removeWhere((e) => e.id == elderId);
    final p = await SharedPreferences.getInstance();
    if (list.isEmpty) {
      await p.remove(_kManualElders);
    } else {
      await p.setString(
        _kManualElders,
        jsonEncode(
          list
              .map(
                (e) => {
                  'id': e.id,
                  'name': e.displayName,
                  'hint': e.accountHint,
                },
              )
              .toList(),
        ),
      );
    }
  }

  static Future<List<BoundElder>> resolveElders() async {
    final hidden = await _hidden();
    final manual = await _loadManual();
    final fromAlerts = <BoundElder>[];
    try {
      final page = await ChildEmergencyAlertsApi.list(page: 1, pageSize: 200);
      final list = page['list'];
      if (list is List) {
        final seen = <String>{};
        for (final item in list) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final id = '${m['elderId'] ?? m['elder_id'] ?? ''}'.trim();
          if (id.isEmpty || seen.contains(id)) continue;
          seen.add(id);
          final name = m['elderName'] as String? ?? m['elder_name'] as String? ?? '老人';
          fromAlerts.add(BoundElder(id: id, displayName: name, accountHint: '来自求助记录'));
        }
      }
    } catch (_) {
      // 网络或鉴权失败时只用手动列表
    }
    final merged = <String, BoundElder>{};
    for (final e in fromAlerts) {
      if (hidden.contains(e.id)) continue;
      merged[e.id] = e;
    }
    for (final e in manual) {
      if (hidden.contains(e.id)) continue;
      merged[e.id] = e;
    }
    return merged.values.toList();
  }
}
