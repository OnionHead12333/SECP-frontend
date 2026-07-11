import '../../../core/models/api_response.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../models/child_fall_alert.dart';

final class ChildFallAlertsApi {
  ChildFallAlertsApi._();

  static List<Map<String, dynamic>>? _mockAlertsForTest;

  static Future<List<ChildFallAlert>> list() async {
    final mock = _mockAlertsForTest;
    if (mock != null) {
      return ChildFallAlert.sorted(
        mock.map(ChildFallAlert.fromJson).toList(growable: false),
      );
    }

    final res = await ApiClient.dio.get<Object?>(
      '/child/fall-alerts',
      queryParameters: {'childUserId': _currentChildUserId()},
    );
    final payload = _payload(res.data);
    final list = _listPayload(payload);
    return ChildFallAlert.sorted(
      list
          .whereType<Map>()
          .map((item) =>
              ChildFallAlert.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  static Future<ChildFallAlert> detail(int id) async {
    final mock = _mockAlertsForTest;
    if (mock != null) {
      final item = mock.firstWhere(
        (item) => '${item['id'] ?? item['alertId']}' == '$id',
        orElse: () => throw StateError('Fall alert $id not found'),
      );
      return ChildFallAlert.fromJson(item);
    }

    final res = await ApiClient.dio.get<Object?>(
      '/child/fall-alerts/$id',
      queryParameters: {'childUserId': _currentChildUserId()},
    );
    final payload = _payload(res.data);
    if (payload is! Map) {
      throw StateError('Invalid fall alert detail response');
    }
    return ChildFallAlert.fromJson(Map<String, dynamic>.from(payload));
  }

  static void setMockAlertsForTest(List<Map<String, dynamic>> alerts) {
    _mockAlertsForTest = alerts;
  }

  static void clearMockAlertsForTest() {
    _mockAlertsForTest = null;
  }

  static int _currentChildUserId() {
    final id = AuthSession.childUserId;
    if (id == null) {
      throw StateError('Missing childUserId for fall alerts request');
    }
    return id;
  }

  static Object? _payload(Object? body) {
    if (body is Map<String, dynamic>) {
      final api = ApiResponse.fromJson(body, (raw) => raw);
      if (api.code != -1) {
        if (!api.isSuccess) throw Exception(api.displayMessage);
        return api.data;
      }
    }
    if (body is Map) {
      if (body.containsKey('data')) return body['data'];
      return body;
    }
    return body;
  }

  static List<Object?> _listPayload(Object? payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      final list = payload['list'] ?? payload['records'] ?? payload['items'];
      if (list is List) return list;
    }
    throw StateError('Invalid fall alerts response');
  }
}
