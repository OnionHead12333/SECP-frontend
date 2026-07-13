import '../models/inspection_marker.dart';
import '../models/inspection_place.dart';
import '../models/inspection_route.dart';
import '../models/map_info.dart';
import '../models/navigation_status.dart';
import '../models/obstacle_status.dart';

abstract class InspectionMapRepository {
  Future<MapInfo> loadMapInfo();

  Future<List<InspectionMarker>> loadMarkers();

  Future<List<InspectionPlace>> loadPlaces();

  Future<List<InspectionRoute>> loadRoutes();

  Future<NavigationStatus> loadNavigationStatus();

  Future<ObstacleStatus> loadObstacleStatus();

  Future<InspectionMarker> handleMarker(
    int markerId, {
    String? handler,
    String? remark,
  });

  Future<NavigationStatus> startNavigation({
    required String targetName,
    required int targetX,
    required int targetY,
  });

  Future<NavigationStatus> cancelNavigation();

  Future<NavigationStatus> returnHome();
}
