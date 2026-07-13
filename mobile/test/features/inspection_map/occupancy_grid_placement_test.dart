import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/models/map_info.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/models/ros_navigation_models.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/utils/coordinate_converter.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/utils/occupancy_grid_placement.dart';

void main() {
  const mapInfo = MapInfo(
    mapName: 'yahboomcar',
    imageAsset: 'assets/robot_maps/yahboomcar.png',
    imageFile: 'yahboomcar.png',
    width: 864,
    height: 896,
    imageHeight: 896,
    resolution: 0.05,
    origin: [-22.8, -22.8, 0],
    frameId: 'map',
  );

  test('new map pixel and ROS coordinates round-trip', () {
    final mapPoint = pixelToMap(432, 448, mapInfo);
    expect(mapPoint.x, closeTo(-1.2, 1e-9));
    expect(mapPoint.y, closeTo(-0.4, 1e-9));

    final pixelPoint = mapToPixel(mapPoint.x, mapPoint.y, mapInfo);
    expect(pixelPoint.x, closeTo(432, 1e-9));
    expect(pixelPoint.y, closeTo(448, 1e-9));
  });

  test('places a map-frame grid by its ROS bottom-left origin', () {
    final placement = resolveOccupancyGridPlacement(
      grid: _grid(frameId: 'map', originX: -2.8, originY: -2.8),
      mapInfo: mapInfo,
      tfTree: RosTfTree(),
    );

    expect(placement, isNotNull);
    expect(placement!.originPixelX, closeTo(400, 1e-9));
    expect(placement.originPixelY, closeTo(496, 1e-9));
    expect(placement.width, closeTo(40, 1e-9));
    expect(placement.height, closeTo(20, 1e-9));
    expect(placement.screenRotation, closeTo(0, 1e-9));
  });

  test('transforms and rotates an odom-frame local costmap into map', () {
    final tfTree = RosTfTree()
      ..updateFromMessage({
        'transforms': [
          {
            'header': {'frame_id': 'map'},
            'child_frame_id': 'odom',
            'transform': {
              'translation': {'x': 2.0, 'y': 1.0, 'z': 0.0},
              'rotation': _quaternion(math.pi / 2),
            },
          },
        ],
      });

    final placement = resolveOccupancyGridPlacement(
      grid: _grid(
        frameId: 'odom',
        originX: 1,
        originY: 0,
        originYaw: 0.25,
      ),
      mapInfo: mapInfo,
      tfTree: tfTree,
    );

    expect(placement, isNotNull);
    expect(placement!.originPixelX, closeTo(496, 1e-9));
    expect(placement.originPixelY, closeTo(400, 1e-9));
    expect(
      placement.screenRotation,
      closeTo(-(math.pi / 2 + 0.25), 1e-9),
    );
  });

  test('does not place a grid whose frame has no map TF', () {
    final placement = resolveOccupancyGridPlacement(
      grid: _grid(frameId: 'odom', originX: 0, originY: 0),
      mapInfo: mapInfo,
      tfTree: RosTfTree(),
    );

    expect(placement, isNull);
  });
}

RosOccupancyGrid _grid({
  required String frameId,
  required double originX,
  required double originY,
  double originYaw = 0,
}) {
  const width = 20;
  const height = 10;
  return RosOccupancyGrid(
    frameId: frameId,
    width: width,
    height: height,
    resolution: 0.1,
    origin: RosPose2D(
      x: originX,
      y: originY,
      yaw: originYaw,
      frameId: frameId,
    ),
    data: List<int>.filled(width * height, 0),
  );
}

Map<String, double> _quaternion(double yaw) {
  return {
    'x': 0,
    'y': 0,
    'z': math.sin(yaw / 2),
    'w': math.cos(yaw / 2),
  };
}
