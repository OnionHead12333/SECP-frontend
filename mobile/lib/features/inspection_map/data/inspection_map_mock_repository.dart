import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/inspection_marker.dart';
import '../models/inspection_place.dart';
import '../models/inspection_route.dart';
import '../models/map_info.dart';
import '../models/navigation_status.dart';
import '../models/obstacle_status.dart';
import 'inspection_map_repository.dart';

class InspectionMapMockRepository implements InspectionMapRepository {
  InspectionMapMockRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  List<InspectionMarker>? _markers;
  NavigationStatus? _navigationStatus;

  @override
  Future<MapInfo> loadMapInfo() async {
    final json = await _loadMap('assets/robot_maps/map_info.json');
    return MapInfo.fromJson(json);
  }

  @override
  Future<List<InspectionMarker>> loadMarkers() async {
    if (_markers != null) return List.unmodifiable(_markers!);
    final list = await _loadList('assets/robot_maps/mock_markers.json');
    _markers = list
        .map((item) => InspectionMarker.fromJson(item))
        .toList(growable: true);
    return List.unmodifiable(_markers!);
  }

  @override
  Future<List<InspectionPlace>> loadPlaces() async {
    final list = await _loadList('assets/robot_maps/places.json');
    return list.map(InspectionPlace.fromJson).toList(growable: false);
  }

  @override
  Future<List<InspectionRoute>> loadRoutes() async {
    final list = await _loadList('assets/robot_maps/routes.json');
    return list.map(InspectionRoute.fromJson).toList(growable: false);
  }

  @override
  Future<NavigationStatus> loadNavigationStatus() async {
    if (_navigationStatus != null) return _navigationStatus!;
    final json = await _loadMap('assets/robot_maps/navigation_status.json');
    _navigationStatus = NavigationStatus.fromJson(json);
    return _navigationStatus!;
  }

  @override
  Future<ObstacleStatus> loadObstacleStatus() async {
    final json = await _loadMap('assets/robot_maps/obstacle_status.json');
    return ObstacleStatus.fromJson(json);
  }

  @override
  Future<InspectionMarker> handleMarker(
    int markerId, {
    String? handler,
    String? remark,
  }) async {
    final markers = _markers ?? (await loadMarkers()).toList(growable: true);
    _markers = markers;
    final index = markers.indexWhere((marker) => marker.id == markerId);
    if (index < 0) {
      throw StateError('Inspection marker not found: $markerId');
    }
    final marker = markers[index];
    if (marker.type == InspectionMarkerType.fall ||
        marker.type == InspectionMarkerType.crack) {
      marker.status = 'handled';
    }
    return marker;
  }

  @override
  Future<NavigationStatus> startNavigation({
    required String targetName,
    required int targetX,
    required int targetY,
  }) async {
    _navigationStatus = NavigationStatus(
      status: NavigationState.running,
      currentTargetId: '$targetX,$targetY',
      currentTargetName: targetName,
      message: 'running to $targetName',
      updatedAt: DateTime.now().toIso8601String(),
    );
    return _navigationStatus!;
  }

  @override
  Future<NavigationStatus> cancelNavigation() async {
    _navigationStatus = NavigationStatus(
      status: NavigationState.idle,
      message: 'navigation canceled',
      updatedAt: DateTime.now().toIso8601String(),
    );
    return _navigationStatus!;
  }

  @override
  Future<NavigationStatus> returnHome() async {
    _navigationStatus = NavigationStatus(
      status: NavigationState.running,
      currentTargetId: 'home',
      currentTargetName: 'home',
      message: 'running to home',
      updatedAt: DateTime.now().toIso8601String(),
    );
    return _navigationStatus!;
  }

  Future<Map<String, dynamic>> _loadMap(String assetPath) async {
    final text = await _bundle.loadString(assetPath);
    return Map<String, dynamic>.from(jsonDecode(text) as Map);
  }

  Future<List<Map<String, dynamic>>> _loadList(String assetPath) async {
    final text = await _bundle.loadString(assetPath);
    final raw = jsonDecode(text) as List;
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }
}
