import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../models/inspection_marker.dart';

final class InspectionService {
  InspectionService._();

  static List<InspectionMarker> _mockMarkers = _initialMockMarkers();
  static bool? _useMockOverrideForTest;

  static bool get useMock =>
      _useMockOverrideForTest ?? AppConfig.useMockInspection;

  static Future<InspectionMapInfo> getMapInfo() async {
    if (!useMock) {
      final response = await ApiClient.dio.get<Object?>(
        _inspectionUrl('/inspection/map'),
      );
      final data = _responsePayload(response.data);
      if (data is! Map) {
        throw StateError('Invalid inspection map response');
      }
      return InspectionMapInfo.fromJson(Map<String, dynamic>.from(data));
    }

    try {
      final text =
          await rootBundle.loadString('assets/robot_maps/map_info.json');
      final json = jsonDecode(text) as Map;
      return InspectionMapInfo.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return _assetMapInfoFallback;
    }
  }

  static Future<InspectionNavigationStatus?> getNavigationStatus() async {
    if (useMock) return _mockNavigationStatus();

    try {
      final response = await ApiClient.dio.get<Object?>(
        _inspectionUrl('/navigation/status'),
      );
      final data = _responsePayload(response.data);
      if (data is Map) {
        return InspectionNavigationStatus.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<List<InspectionMarker>> getMarkers() async {
    if (useMock) return List<InspectionMarker>.unmodifiable(_mockMarkers);

    final response = await ApiClient.dio.get<Object?>(
      _inspectionUrl('/inspection/markers'),
    );
    final raw = _responsePayload(response.data);
    final list = raw is List
        ? raw
        : raw is Map
            ? raw['list']
            : null;
    if (list is! List) {
      throw StateError('Invalid inspection markers response');
    }
    return list
        .whereType<Map>()
        .map((item) =>
            InspectionMarker.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Future<List<InspectionMarker>> getEventMarkers() async {
    final markers = await getMarkers();
    return markers.where((marker) => marker.isEvent).toList(growable: false);
  }

  static Future<InspectionMarker> getMarkerDetail(int id) async {
    if (useMock) return _mockMarkerById(id);

    final response = await ApiClient.dio.get<Object?>(
      _inspectionUrl('/inspection/markers/$id'),
    );
    final data = _responsePayload(response.data);
    if (data is! Map) {
      throw StateError('Invalid inspection marker detail response: $id');
    }
    return InspectionMarker.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<InspectionMarker> handleMarker(
    int id,
    String handler,
    String remark,
  ) async {
    if (useMock) return _handleMockMarker(id, handler, remark);

    final response = await ApiClient.dio.put<Object?>(
      _inspectionUrl('/inspection/markers/$id/handle'),
      data: {'handler': handler, 'remark': remark},
    );
    final data = _responsePayload(response.data);
    if (data is Map && data.containsKey('id')) {
      return InspectionMarker.fromJson(Map<String, dynamic>.from(data));
    }
    return getMarkerDetail(id);
  }

  static void resetMockDataForTest() {
    _mockMarkers = _initialMockMarkers();
    _useMockOverrideForTest = true;
  }

  static String _inspectionUrl(String path) {
    final base = AppConfig.inspectionApiBase.endsWith('/')
        ? AppConfig.inspectionApiBase.substring(
            0,
            AppConfig.inspectionApiBase.length - 1,
          )
        : AppConfig.inspectionApiBase;
    return '$base$path';
  }

  static Object? _responsePayload(Object? body) {
    if (body is Map && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  static InspectionMarker _mockMarkerById(int id) {
    return _mockMarkers.firstWhere(
      (marker) => marker.id == id,
      orElse: () => throw StateError('Inspection marker $id not found'),
    );
  }

  static InspectionMarker _handleMockMarker(
    int id,
    String handler,
    String remark,
  ) {
    final index = _mockMarkers.indexWhere((marker) => marker.id == id);
    if (index < 0) {
      throw StateError('Inspection marker $id not found');
    }
    final updated = _mockMarkers[index].copyWith(
      status: InspectionMarkerStatus.handled,
      handler: handler,
      remark: remark,
      handleTime: _formatNow(DateTime.now()),
    );
    _mockMarkers = [
      for (final marker in _mockMarkers) marker.id == id ? updated : marker,
    ];
    return updated;
  }

  static String _formatNow(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
  }

  static const InspectionMapInfo _assetMapInfoFallback = InspectionMapInfo(
    title: 'yahboomcar',
    width: 608,
    height: 384,
    imageAsset: 'assets/robot_maps/yahboomcar.png',
  );

  static InspectionNavigationStatus _mockNavigationStatus() {
    return const InspectionNavigationStatus(
      navigationStatus: 'running',
      obstacleStatus: 'safe',
      robotX: 260,
      robotY: 300,
      targetX: 520,
      targetY: 300,
      targetName: '老人房间A',
    );
  }

  static List<InspectionMarker> _initialMockMarkers() {
    return [
      InspectionMarker.fromJson({
        'id': 1,
        'type': 'fall',
        'title': '张爷爷疑似跌倒',
        'x': 120,
        'y': 240,
        'level': 'danger',
        'status': 'unhandled',
        'locationName': '一层东侧走廊',
        'elderName': '张爷爷',
        'identitySource': 'recent_identity',
        'identityConfidence': 0.89,
        'notifiedChild': true,
        'imageUrl': '/static/mock/fall_001.jpg',
        'time': '2026-07-10 16:30',
      }),
      InspectionMarker.fromJson({
        'id': 2,
        'type': 'fall',
        'title': '未知人员疑似跌倒',
        'x': 300,
        'y': 180,
        'level': 'danger',
        'status': 'unhandled',
        'locationName': '一层大厅',
        'elderName': '未知人员',
        'identitySource': 'unknown',
        'identityConfidence': 0,
        'notifiedChild': false,
        'imageUrl': '/static/mock/fall_unknown.jpg',
        'time': '2026-07-10 16:40',
      }),
      InspectionMarker.fromJson({
        'id': 3,
        'type': 'crack',
        'title': '地面裂缝',
        'x': 360,
        'y': 180,
        'level': 'warning',
        'status': 'unhandled',
        'locationName': '一层大厅入口',
        'imageUrl': '/static/mock/crack_001.jpg',
        'time': '2026-07-10 16:45',
      }),
      InspectionMarker.fromJson({
        'id': 4,
        'type': 'robot',
        'title': '小车当前位置',
        'x': 260,
        'y': 300,
        'level': 'info',
        'status': 'active',
        'locationName': '一层走廊',
        'navigationStatus': 'running',
        'obstacleStatus': 'safe',
        'time': '2026-07-10 16:50',
      }),
      InspectionMarker.fromJson({
        'id': 5,
        'type': 'target',
        'title': '导航目标：老人房间A',
        'x': 520,
        'y': 300,
        'level': 'info',
        'status': 'active',
        'locationName': '老人房间A',
        'time': '2026-07-10 16:50',
      }),
      InspectionMarker.fromJson({
        'id': 6,
        'type': 'obstacle',
        'title': '前方障碍物',
        'x': 430,
        'y': 260,
        'level': 'warning',
        'status': 'unhandled',
        'locationName': '一层走廊中段',
        'time': '2026-07-10 16:52',
      }),
    ];
  }
}
