import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../../../core/util/api_instant.dart';

/// `GET /v1/child/elders/{elderId}/activity-alerts`
final class ChildActivityAlertsApi {
  ChildActivityAlertsApi._();

  static Future<List<ActivityAlertRecord>> list(int elderId) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/child/elders/$elderId/activity-alerts',
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(
      body,
      (raw) {
        if (raw is! List) return <Map<String, dynamic>>[];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
    if (!api.isSuccess) throw Exception(api.displayMessage);
    final list = api.data ?? const <Map<String, dynamic>>[];
    return list.map(ActivityAlertRecord.fromJson).toList();
  }
}

class ActivityAlertRecord {
  const ActivityAlertRecord({
    required this.id,
    required this.alertType,
    required this.title,
    required this.content,
    this.triggeredAt,
  });

  final String id;
  final String alertType;
  final String title;
  final String content;
  final DateTime? triggeredAt;

  bool get isGoOut => alertType == 'go_out';

  bool get isComeHome => alertType == 'come_home';

  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (isGoOut) return '老人已出门';
    if (isComeHome) return '老人已回家';
    return '位置变化';
  }

  factory ActivityAlertRecord.fromJson(Map<String, dynamic> j) {
    final id = '${j['alertId'] ?? j['id'] ?? ''}'.trim();
    final alertType = (j['alertType'] as String?)?.trim() ?? '';
    final title = (j['title'] as String?)?.trim() ?? '';
    final content = (j['content'] as String?)?.trim() ?? '';
    final goOut = alertType == 'go_out';
    final comeHome = alertType == 'come_home';
    return ActivityAlertRecord(
      id: id,
      alertType: alertType,
      title: title.isNotEmpty
          ? title
          : (goOut
              ? '老人已出门'
              : (comeHome ? '老人已回家' : '位置变化')),
      content: content.isNotEmpty
          ? content
          : (goOut
              ? '检测到老人离开家的范围，请关注出行安全。'
              : (comeHome
                  ? '检测到老人回到家的范围内。'
                  : '检测到老人位置状态变化。')),
      triggeredAt: parseApiInstantToLocal(j['triggeredAt']),
    );
  }
}
