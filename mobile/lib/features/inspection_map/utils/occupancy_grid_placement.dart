import '../models/map_info.dart';
import '../models/ros_navigation_models.dart';
import 'coordinate_converter.dart';

/// Pixel placement for an OccupancyGrid image whose bottom-left corner is the
/// ROS grid origin.
class OccupancyGridPlacement {
  const OccupancyGridPlacement({
    required this.originPixelX,
    required this.originPixelY,
    required this.width,
    required this.height,
    required this.screenRotation,
  });

  final double originPixelX;
  final double originPixelY;
  final double width;
  final double height;

  /// Flutter screen-space rotation. ROS yaw is negated because screen Y grows
  /// downwards while ROS map Y grows upwards.
  final double screenRotation;
}

/// Resolves a costmap/grid from its own frame into the displayed map frame.
///
/// Returns null until the required TF chain is available instead of drawing a
/// grid at an incorrect map position.
OccupancyGridPlacement? resolveOccupancyGridPlacement({
  required RosOccupancyGrid grid,
  required MapInfo mapInfo,
  required RosTfTree tfTree,
}) {
  if (!grid.isValid || mapInfo.resolution <= 0) return null;

  final mapFrame = normalizeRosFrame(mapInfo.frameId);
  final gridFrame = normalizeRosFrame(grid.frameId);
  final frameTransform = mapFrame == gridFrame
      ? RosTransform2D.identity(mapFrame)
      : tfTree.resolve(mapFrame, gridFrame);
  if (frameTransform == null) return null;

  final originInMap = frameTransform.transformPoint(
    RosPoint2D(grid.origin.x, grid.origin.y),
  );
  final originPixel = mapToPixel(originInMap.x, originInMap.y, mapInfo);
  final yawInMap = normalizeYaw(frameTransform.yaw + grid.origin.yaw);

  return OccupancyGridPlacement(
    originPixelX: originPixel.x,
    originPixelY: originPixel.y,
    width: grid.width * grid.resolution / mapInfo.resolution,
    height: grid.height * grid.resolution / mapInfo.resolution,
    screenRotation: -yawInMap,
  );
}
