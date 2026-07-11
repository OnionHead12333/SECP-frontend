class ObstacleStatus {
  const ObstacleStatus({
    required this.status,
    required this.hasObstacle,
    this.obstacleMarkerId,
    this.distanceMeters,
    this.message,
    this.updatedAt,
  });

  final String status;
  final bool hasObstacle;
  final int? obstacleMarkerId;
  final double? distanceMeters;
  final String? message;
  final String? updatedAt;

  factory ObstacleStatus.fromJson(Map<String, dynamic> json) {
    return ObstacleStatus(
      status: json['status'] as String? ?? 'clear',
      hasObstacle: json['hasObstacle'] as bool? ?? false,
      obstacleMarkerId: _asNullableInt(json['obstacleMarkerId']),
      distanceMeters: _asNullableDouble(json['distanceMeters']),
      message: json['message'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'hasObstacle': hasObstacle,
      'obstacleMarkerId': obstacleMarkerId,
      'distanceMeters': distanceMeters,
      'message': message,
      'updatedAt': updatedAt,
    };
  }

  static int? _asNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _asNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
