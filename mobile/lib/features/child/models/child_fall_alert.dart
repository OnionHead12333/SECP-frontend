class ChildFallAlert {
  const ChildFallAlert({
    required this.id,
    required this.title,
    required this.status,
    this.elderName,
    this.identitySource,
    this.identityConfidence,
    this.notifiedChild,
    this.locationName,
    this.time,
    this.level,
    this.imageUrl,
    this.message,
    this.description,
    this.handler,
    this.remark,
    this.handleTime,
  });

  final int id;
  final String title;
  final String status;
  final String? elderName;
  final String? identitySource;
  final double? identityConfidence;
  final bool? notifiedChild;
  final String? locationName;
  final String? time;
  final String? level;
  final String? imageUrl;
  final String? message;
  final String? description;
  final String? handler;
  final String? remark;
  final String? handleTime;

  String get displayElderName {
    final name = elderName?.trim();
    return name == null || name.isEmpty ? '未知人员' : name;
  }

  String get displayTitle {
    if (identitySource == 'unknown' || displayElderName == '未知人员') {
      return '未知人员疑似跌倒';
    }
    final text = title.trim();
    return text.isEmpty ? '$displayElderName疑似跌倒' : text;
  }

  String get displayMessage {
    final text = description ?? message;
    return text == null || text.trim().isEmpty ? '-' : text;
  }

  static List<ChildFallAlert> sorted(List<ChildFallAlert> alerts) {
    final result = [...alerts];
    result.sort((a, b) {
      final status = _statusRank(a.status).compareTo(_statusRank(b.status));
      if (status != 0) return status;
      return b.timeText.compareTo(a.timeText);
    });
    return result;
  }

  String get timeText => time ?? '';

  factory ChildFallAlert.fromJson(Map<String, dynamic> json) {
    return ChildFallAlert(
      id: _intValue(json['id'] ?? json['alertId']),
      title: _stringValue(json['title']),
      status: _stringValue(json['status'], fallback: 'unhandled'),
      elderName: _nullableString(json['elderName']),
      identitySource: _nullableString(json['identitySource']),
      identityConfidence: _doubleValue(json['identityConfidence']),
      notifiedChild: _boolValue(json['notifiedChild']),
      locationName: _nullableString(json['locationName']),
      time: _nullableString(json['time']),
      level: _nullableString(json['level']),
      imageUrl: _nullableString(json['imageUrl']),
      message: _nullableString(json['message']),
      description: _nullableString(json['description']),
      handler: _nullableString(json['handler']),
      remark: _nullableString(json['remark']),
      handleTime: _nullableString(json['handleTime']),
    );
  }

  static int _statusRank(String status) {
    switch (status.trim().toLowerCase()) {
      case 'unhandled':
        return 0;
      case 'handled':
        return 2;
      default:
        return 1;
    }
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  static double? _doubleValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static bool? _boolValue(Object? value) {
    if (value is bool) return value;
    final text = '${value ?? ''}'.trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    return _nullableString(value) ?? fallback;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }
}
