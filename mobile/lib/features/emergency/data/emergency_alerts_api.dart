import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../../../core/util/api_instant.dart';

final class EmergencyAlertsApi {
  EmergencyAlertsApi._();

  static Future<List<EmergencyAlertRecord>> list({
    int page = 1,
    int pageSize = 100,
    String? status,
  }) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/emergency-alerts',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.displayMessage);
    return _recordsFromData(api.data);
  }

  static Future<EmergencyAlertRecord> getById(int alertId) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/v1/emergency-alerts/$alertId',
    );
    final body = res.data;
    if (body == null) throw Exception('空响应');
    final api = ApiResponse.fromJson(body, (raw) => raw);
    if (!api.isSuccess) throw Exception(api.displayMessage);
    final data = api.data;
    if (data is! Map) {
      throw Exception('数据格式错误');
    }
    return EmergencyAlertRecord.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> markHandled({
    required int alertId,
    String remark = '员工已到达',
  }) {
    return updateStatus(alertId: alertId, status: 'handled', remark: remark);
  }

  static Future<void> updateStatus({
    required int alertId,
    required String status,
    String? remark,
  }) async {
    final res = await ApiClient.dio.put<Map<String, dynamic>>(
      '/v1/emergency-alerts/$alertId/status',
      data: {
        'status': status,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      },
    );
    final body = res.data;
    if (body == null) {
      if (_isSuccessStatusCode(res.statusCode)) return;
      throw Exception('空响应');
    }
    if (body.containsKey('code')) {
      final api = ApiResponse.fromJson(body, (raw) => raw);
      if (!api.isSuccess) throw Exception(api.displayMessage);
      return;
    }
    if (_isSuccessStatusCode(res.statusCode) ||
        EmergencyAlertRecord._stringValue(body['status'], fallback: '') ==
            status) {
      return;
    }
    throw Exception('状态更新响应格式错误');
  }

  static bool _isSuccessStatusCode(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  static List<EmergencyAlertRecord> _recordsFromData(Object? data) {
    final rawList = switch (data) {
      {'list': final List list} => list,
      {'items': final List list} => list,
      {'records': final List list} => list,
      final List list => list,
      _ => const [],
    };
    return rawList
        .whereType<Map>()
        .map((item) => EmergencyAlertRecord.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.id != null)
        .toList();
  }
}

final class EmergencyAlertRecord {
  const EmergencyAlertRecord({
    required this.id,
    required this.elderName,
    required this.status,
    required this.alertType,
    this.triggeredAt,
    this.sentAt,
    this.remark,
  });

  final int? id;
  final String elderName;
  final String status;
  final String alertType;
  final DateTime? triggeredAt;
  final DateTime? sentAt;
  final String? remark;

  bool get canHandle => status.trim().toLowerCase() == 'sent';

  DateTime? get displayTime => sentAt ?? triggeredAt;

  factory EmergencyAlertRecord.fromJson(Map<String, dynamic> json) {
    return EmergencyAlertRecord(
      id: _intValue(json['alertId'] ?? json['id']),
      elderName: _stringValue(
        json['elderName'] ?? json['elder_name'],
        fallback: '老人',
      ),
      status: _stringValue(json['status'], fallback: ''),
      alertType: _stringValue(
        json['alertType'] ?? json['alert_type'],
        fallback: 'sos',
      ),
      triggeredAt: parseApiInstantToLocal(
        json['triggerTime'] ?? json['trigger_time'] ?? json['createdAt'],
      ),
      sentAt: parseApiInstantToLocal(json['sentTime'] ?? json['sent_time']),
      remark: _nullableString(json['remark']),
    );
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static String _stringValue(Object? value, {required String fallback}) {
    final text = _nullableString(value);
    return text ?? fallback;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
