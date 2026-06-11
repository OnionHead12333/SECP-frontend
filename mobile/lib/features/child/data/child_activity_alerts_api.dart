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

  factory ActivityAlertRecord.fromJson(Map<String, dynamic> j) {
    final id = '${j['alertId'] ?? j['id'] ?? ''}'.trim();
    final title = (j['title'] as String?)?.trim() ?? '';
    final content = (j['content'] as String?)?.trim() ?? '';
    return ActivityAlertRecord(
      id: id,
      alertType: (j['alertType'] as String?)?.trim() ?? '',
      title: title.isNotEmpty ? title : '活动预警',
      content: content.isNotEmpty ? content : '检测到异常活动状态，请关注老人情况。',
      triggeredAt: parseApiInstantToLocal(j['triggeredAt']),
    );
  }
}
