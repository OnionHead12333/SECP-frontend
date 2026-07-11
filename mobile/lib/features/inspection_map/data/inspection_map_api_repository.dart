import 'package:dio/dio.dart';

import '../models/inspection_marker.dart';
import '../models/inspection_place.dart';
import '../models/inspection_route.dart';
import '../models/map_info.dart';
import '../models/navigation_status.dart';
import '../models/obstacle_status.dart';
import '../utils/coordinate_converter.dart';
import 'inspection_map_repository.dart';

class InspectionMapApiRepository implements InspectionMapRepository {
  InspectionMapApiRepository({
    this.baseUrl = 'http://localhost:8080/api',
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 5),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final String baseUrl;
  final Dio _dio;

  MapInfo? _cachedMapInfo;

  @override
  Future<MapInfo> loadMapInfo() async {
    final response = await _dio.get<Object?>('/v1/inspection/map');
    final data = _extractData(response);
    final mapInfo = MapInfo.fromJson(_normalizeMapInfo(data));
    _cachedMapInfo = mapInfo;
    return mapInfo;
  }

  @override
  Future<List<InspectionMarker>> loadMarkers() async {
    final response = await _dio.get<Object?>('/v1/inspection/markers');
    final data = _extractData(response);
    final mapInfo = await _ensureMapInfo();
    return _asList(data)
        .map((item) =>
            InspectionMarker.fromJson(_normalizeMarker(item, mapInfo)))
        .toList(growable: false);
  }

  @override
  Future<List<InspectionPlace>> loadPlaces() async {
    final response = await _dio.get<Object?>('/v1/inspection/places');
    final data = _extractData(response);
    final mapInfo = await _ensureMapInfo();
    return _asList(data)
        .map((item) => InspectionPlace.fromJson(_normalizePlace(item, mapInfo)))
        .toList(growable: false);
  }

  @override
  Future<List<InspectionRoute>> loadRoutes() async {
    final response = await _dio.get<Object?>('/v1/inspection/routes');
    final data = _extractData(response);
    return _asList(data)
        .map((item) => InspectionRoute.fromJson(item))
        .toList(growable: false);
  }

  @override
  Future<NavigationStatus> loadNavigationStatus() async {
    final response = await _dio.get<Object?>('/v1/navigation/status');
    final data = _extractData(response);
    return NavigationStatus.fromJson(_normalizeNavigationStatus(data));
  }

  @override
  Future<ObstacleStatus> loadObstacleStatus() async {
    final response = await _dio.get<Object?>('/v1/obstacle/status');
    final data = _extractData(response);
    return ObstacleStatus.fromJson(_normalizeObstacleStatus(data));
  }

  @override
  Future<InspectionMarker> handleMarker(
    int markerId, {
    String? handler,
    String? remark,
  }) async {
    final response = await _dio.put<Object?>(
      '/v1/inspection/markers/$markerId/handle',
      data: {
        if (handler != null) 'handler': handler,
        if (remark != null) 'remark': remark,
      },
    );
    final data = _extractData(response);
    final mapInfo = await _ensureMapInfo();
    return InspectionMarker.fromJson(_normalizeMarker(_asMap(data), mapInfo));
  }

  @override
  Future<NavigationStatus> startNavigation({
    required String targetName,
    required int targetX,
    required int targetY,
  }) async {
    final response = await _dio.post<Object?>(
      '/v1/navigation/start',
      data: {
        'targetName': targetName,
        'targetX': targetX,
        'targetY': targetY,
      },
    );
    final data = _extractData(response);
    return NavigationStatus.fromJson(_normalizeNavigationStatus(data));
  }

  @override
  Future<NavigationStatus> cancelNavigation() async {
    final response = await _dio.post<Object?>('/v1/navigation/cancel');
    final data = _extractData(response);
    return NavigationStatus.fromJson(_normalizeNavigationStatus(data));
  }

  @override
  Future<NavigationStatus> returnHome() async {
    final response = await _dio.post<Object?>('/v1/navigation/return-home');
    final data = _extractData(response);
    return NavigationStatus.fromJson(_normalizeNavigationStatus(data));
  }

  Object? _extractData(Response<Object?> response) {
    final body = response.data;
    if (body is! Map) {
      throw StateError('Invalid API response body');
    }
    final json = Map<String, dynamic>.from(body);
    final success = json['success'] as bool? ?? false;
    final message = json['message'] as String? ?? 'request failed';
    if (!success) {
      throw StateError(message);
    }
    return json['data'];
  }

  Future<MapInfo> _ensureMapInfo() async {
    return _cachedMapInfo ?? await loadMapInfo();
  }

  Map<String, dynamic> _normalizeMapInfo(Object? data) {
    final json = _asMap(data);
    final mapImage = json['mapImage'] as String? ?? '';
    final imageParts = mapImage.split('/').where((part) => part.isNotEmpty);
    final imageFile = imageParts.isEmpty ? 'yahboomcar.png' : imageParts.last;
    return {
      'mapName': json['mapName'],
      'imageAsset': 'assets/robot_maps/yahboomcar.png',
      'imageFile': imageFile,
      'width': json['width'],
      'height': json['height'],
      'imageHeight': json['imageHeight'] ?? json['height'],
      'resolution': json['resolution'],
      'origin': [
        json['originX'] ?? -10,
        json['originY'] ?? -10,
        json['originYaw'] ?? 0,
      ],
      'frameId': json['frameId'] ?? 'map',
    };
  }

  Map<String, dynamic> _normalizeMarker(
    Map<String, dynamic> json,
    MapInfo mapInfo,
  ) {
    final pixelX = _asDouble(json['pixelX'] ?? json['x']);
    final pixelY = _asDouble(json['pixelY'] ?? json['y']);
    final mapPoint = pixelToMap(pixelX, pixelY, mapInfo);
    return {
      ...json,
      'pixelX': pixelX,
      'pixelY': pixelY,
      'mapX': json['mapX'] ?? mapPoint.x,
      'mapY': json['mapY'] ?? mapPoint.y,
    };
  }

  Map<String, dynamic> _normalizePlace(
    Map<String, dynamic> json,
    MapInfo mapInfo,
  ) {
    final pixelX = _asDouble(json['pixelX'] ?? json['x']);
    final pixelY = _asDouble(json['pixelY'] ?? json['y']);
    final mapPoint = pixelToMap(pixelX, pixelY, mapInfo);
    return {
      ...json,
      'pixelX': pixelX,
      'pixelY': pixelY,
      'mapX': json['mapX'] ?? mapPoint.x,
      'mapY': json['mapY'] ?? mapPoint.y,
      'yaw': json['yaw'] ?? 0,
      'name': json['name'] ?? json['locationName'] ?? json['id'],
    };
  }

  Map<String, dynamic> _normalizeNavigationStatus(Object? data) {
    final json = _asMap(data);
    final targetX = json['targetX'];
    final targetY = json['targetY'];
    final targetName = json['targetName'] as String?;
    return {
      ...json,
      'status': json['status'] ?? json['navigationStatus'],
      'currentTargetId':
          targetX == null || targetY == null ? targetName : '$targetX,$targetY',
      'currentTargetName': targetName,
    };
  }

  Map<String, dynamic> _normalizeObstacleStatus(Object? data) {
    final json = _asMap(data);
    final status = '${json['status'] ?? json['obstacleStatus'] ?? 'safe'}';
    return {
      ...json,
      'status': status,
      'hasObstacle': status == 'obstacle',
    };
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw StateError('Expected object data from API');
    }
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) {
      throw StateError('Expected list data from API');
    }
    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }
}
