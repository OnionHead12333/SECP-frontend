class InspectionPlace {
  const InspectionPlace({
    required this.id,
    required this.name,
    required this.pixelX,
    required this.pixelY,
    required this.mapX,
    required this.mapY,
    required this.yaw,
  });

  final String id;
  final String name;
  final double pixelX;
  final double pixelY;
  final double mapX;
  final double mapY;
  final double yaw;

  factory InspectionPlace.fromJson(Map<String, dynamic> json) {
    return InspectionPlace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pixelX: _asDouble(json['pixelX']),
      pixelY: _asDouble(json['pixelY']),
      mapX: _asDouble(json['mapX']),
      mapY: _asDouble(json['mapY']),
      yaw: _asDouble(json['yaw']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pixelX': pixelX,
      'pixelY': pixelY,
      'mapX': mapX,
      'mapY': mapY,
      'yaw': yaw,
    };
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }
}
