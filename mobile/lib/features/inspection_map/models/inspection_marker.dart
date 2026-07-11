enum InspectionMarkerType {
  robot,
  target,
  fall,
  crack,
  obstacle;

  static InspectionMarkerType fromString(String value) {
    return InspectionMarkerType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => InspectionMarkerType.target,
    );
  }
}

class InspectionMarker {
  InspectionMarker({
    required this.id,
    required this.type,
    required this.pixelX,
    required this.pixelY,
    required this.mapX,
    required this.mapY,
    required this.title,
    required this.message,
    required this.status,
    this.elderId,
    this.elderName,
    this.identitySource,
    this.identityConfidence,
    this.notifiedChild,
    this.level,
    this.imageUrl,
    this.time,
    this.locationName,
  });

  final int id;
  final InspectionMarkerType type;
  final double pixelX;
  final double pixelY;
  final double mapX;
  final double mapY;
  final String title;
  final String message;
  String status;
  final int? elderId;
  final String? elderName;
  final String? identitySource;
  final double? identityConfidence;
  final bool? notifiedChild;
  final String? level;
  final String? imageUrl;
  final String? time;
  final String? locationName;

  bool get canHandle =>
      (type == InspectionMarkerType.fall ||
          type == InspectionMarkerType.crack) &&
      status == 'unhandled';

  factory InspectionMarker.fromJson(Map<String, dynamic> json) {
    return InspectionMarker(
      id: _asInt(json['id']),
      type: InspectionMarkerType.fromString('${json['type'] ?? ''}'),
      pixelX: _asDouble(json['pixelX'] ?? json['x']),
      pixelY: _asDouble(json['pixelY'] ?? json['y']),
      mapX: _asDouble(json['mapX']),
      mapY: _asDouble(json['mapY']),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'unhandled',
      elderId: _asNullableInt(json['elderId']),
      elderName: json['elderName'] as String?,
      identitySource: json['identitySource'] as String?,
      identityConfidence: _asNullableDouble(json['identityConfidence']),
      notifiedChild: json['notifiedChild'] as bool?,
      level: json['level'] as String?,
      imageUrl: json['imageUrl'] as String?,
      time: json['time'] as String?,
      locationName: json['locationName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'pixelX': pixelX,
      'pixelY': pixelY,
      'mapX': mapX,
      'mapY': mapY,
      'title': title,
      'message': message,
      'status': status,
      'elderId': elderId,
      'elderName': elderName,
      'identitySource': identitySource,
      'identityConfidence': identityConfidence,
      'notifiedChild': notifiedChild,
      'level': level,
      'imageUrl': imageUrl,
      'time': time,
      'locationName': locationName,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static int? _asNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static double? _asNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
