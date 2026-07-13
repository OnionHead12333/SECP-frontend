class MapInfo {
  const MapInfo({
    required this.mapName,
    required this.imageAsset,
    required this.imageFile,
    required this.width,
    required this.height,
    required this.imageHeight,
    required this.resolution,
    required this.origin,
    required this.frameId,
  });

  final String mapName;
  final String imageAsset;
  final String imageFile;
  final int width;
  final int height;
  final int imageHeight;
  final double resolution;
  final List<double> origin;
  final String frameId;

  double get originX => origin.isNotEmpty ? origin[0] : 0;
  double get originY => origin.length > 1 ? origin[1] : 0;
  double get originYaw => origin.length > 2 ? origin[2] : 0;

  factory MapInfo.fromJson(Map<String, dynamic> json) {
    return MapInfo(
      mapName: json['mapName'] as String? ?? '',
      imageAsset: json['imageAsset'] as String? ?? '',
      imageFile: json['imageFile'] as String? ?? '',
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      imageHeight: _asInt(json['imageHeight'] ?? json['height']),
      resolution: _asDouble(json['resolution']),
      origin: _asDoubleList(json['origin']),
      frameId: json['frameId'] as String? ?? 'map',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mapName': mapName,
      'imageAsset': imageAsset,
      'imageFile': imageFile,
      'width': width,
      'height': height,
      'imageHeight': imageHeight,
      'resolution': resolution,
      'origin': origin,
      'frameId': frameId,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static List<double> _asDoubleList(Object? value) {
    if (value is! List) return const [0, 0, 0];
    return value.map(_asDouble).toList(growable: false);
  }
}
