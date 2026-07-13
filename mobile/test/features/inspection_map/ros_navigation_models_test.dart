import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/models/ros_navigation_models.dart';

void main() {
  test('parses occupancy grid metadata and cells', () {
    final grid = RosOccupancyGrid.fromMessage({
      'header': {'frame_id': '/map'},
      'info': {
        'width': 3,
        'height': 2,
        'resolution': 0.05,
        'origin': {
          'position': {'x': -1.5, 'y': -2.0, 'z': 0},
          'orientation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
        },
      },
      'data': [-1, 0, 100, 0, 25, 65],
    });

    expect(grid.frameId, 'map');
    expect(grid.width, 3);
    expect(grid.height, 2);
    expect(grid.resolution, 0.05);
    expect(grid.origin.x, -1.5);
    expect(grid.origin.y, -2.0);
    expect(grid.data, [-1, 0, 100, 0, 25, 65]);
    expect(grid.isValid, isTrue);
  });

  test('resolves a two-link 2D TF chain', () {
    final tree = RosTfTree()
      ..updateFromMessage({
        'transforms': [
          {
            'header': {'frame_id': 'map'},
            'child_frame_id': 'base_link',
            'transform': {
              'translation': {'x': 2.0, 'y': 1.0, 'z': 0.0},
              'rotation': _quaternion(math.pi / 2),
            },
          },
          {
            'header': {'frame_id': 'base_link'},
            'child_frame_id': 'laser',
            'transform': {
              'translation': {'x': 0.2, 'y': 0.0, 'z': 0.0},
              'rotation': _quaternion(0),
            },
          },
        ],
      });

    final mapToLaser = tree.resolve('map', 'laser');
    expect(mapToLaser, isNotNull);
    expect(mapToLaser!.x, closeTo(2.0, 1e-9));
    expect(mapToLaser.y, closeTo(1.2, 1e-9));
    expect(mapToLaser.yaw, closeTo(math.pi / 2, 1e-9));

    final point = mapToLaser.transformPoint(const RosPoint2D(1, 0));
    expect(point.x, closeTo(2.0, 1e-9));
    expect(point.y, closeTo(2.2, 1e-9));
  });

  test('parses Nav2 status and feedback', () {
    expect(
      parseGoalStatus({
        'status_list': [
          {'status': 2},
        ],
      }),
      RosGoalStatus.executing,
    );

    final feedback = RosNavigationFeedback.fromMessage({
      'feedback': {
        'current_pose': {
          'header': {'frame_id': 'map'},
          'pose': {
            'position': {'x': 1.2, 'y': -0.4, 'z': 0},
            'orientation': _quaternion(0.5),
          },
        },
        'distance_remaining': 2.75,
        'estimated_time_remaining': {'sec': 12, 'nanosec': 500000000},
        'number_of_recoveries': 1,
      },
    });

    expect(feedback.currentPose?.x, 1.2);
    expect(feedback.currentPose?.yaw, closeTo(0.5, 1e-9));
    expect(feedback.distanceRemaining, 2.75);
    expect(feedback.estimatedTimeRemaining.inMilliseconds, 12500);
    expect(feedback.numberOfRecoveries, 1);
  });

  test('parses sensor_msgs PointCloud cost cloud points', () {
    final cloud = RosPointCloud.fromMessage({
      'header': {'frame_id': '/map'},
      'points': [
        {'x': 1.25, 'y': -2.5, 'z': 0.0},
        {'x': -0.75, 'y': 3.5, 'z': 0.1},
      ],
      'channels': const [],
    });

    expect(cloud.frameId, 'map');
    expect(cloud.points, hasLength(2));
    expect(cloud.points[0].x, 1.25);
    expect(cloud.points[0].y, -2.5);
    expect(cloud.points[1].x, -0.75);
    expect(cloud.points[1].y, 3.5);
  });

  test('parses base64 sensor_msgs PointCloud2 cost cloud points', () {
    final bytes = Uint8List(32);
    final data = ByteData.sublistView(bytes)
      ..setFloat32(0, 1.25, Endian.little)
      ..setFloat32(4, -2.5, Endian.little)
      ..setFloat32(8, 0.0, Endian.little)
      ..setFloat32(16, -0.75, Endian.little)
      ..setFloat32(20, 3.5, Endian.little)
      ..setFloat32(24, 0.1, Endian.little);
    expect(data.lengthInBytes, bytes.length);

    final cloud = RosPointCloud.fromMessage({
      'header': {'frame_id': 'odom'},
      'height': 1,
      'width': 2,
      'fields': [
        {'name': 'x', 'offset': 0, 'datatype': 7, 'count': 1},
        {'name': 'y', 'offset': 4, 'datatype': 7, 'count': 1},
        {'name': 'z', 'offset': 8, 'datatype': 7, 'count': 1},
      ],
      'is_bigendian': false,
      'point_step': 16,
      'row_step': 32,
      'data': base64Encode(bytes),
      'is_dense': true,
    });

    expect(cloud.frameId, 'odom');
    expect(cloud.points, hasLength(2));
    expect(cloud.points[0].x, closeTo(1.25, 1e-6));
    expect(cloud.points[0].y, closeTo(-2.5, 1e-6));
    expect(cloud.points[1].x, closeTo(-0.75, 1e-6));
    expect(cloud.points[1].y, closeTo(3.5, 1e-6));
  });
}

Map<String, double> _quaternion(double yaw) {
  return {
    'x': 0,
    'y': 0,
    'z': math.sin(yaw / 2),
    'w': math.cos(yaw / 2),
  };
}
