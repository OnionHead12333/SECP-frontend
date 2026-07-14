import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/models/ros_navigation_models.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map_2/application/round_trip_navigation_controller.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map_2/models/round_trip_navigation_state.dart';

void main() {
  test('publishes one outbound goal and one automatic return goal', () async {
    final now = DateTime.utc(2026, 7, 14, 12);
    final goals = <RosPose2D>[];
    var stopCount = 0;
    final controller = RoundTripNavigationController(
      publishGoal: goals.add,
      publishStop: () => stopCount += 1,
      now: () => now,
      autoReturnDelay: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.handleActionStatus(_statusMessage([9], 4));
    controller.updatePose(
      const RosPose2D(x: 1.2, y: -0.4, yaw: 0.3),
      receivedAt: now,
    );
    expect(controller.captureHome(), isTrue);
    expect(
      controller.selectTarget(
        const RosPose2D(x: 2.0, y: 0.5, yaw: -0.2),
      ),
      isTrue,
    );

    expect(controller.startOutbound(), isTrue);
    expect(controller.startOutbound(), isFalse);
    expect(goals, hasLength(1));
    expect(goals.single.x, 2.0);

    controller.handleActionStatus(
      _statusList([
        _statusEntry([9], 4),
        _statusEntry([1, 2, 3], 2),
      ]),
    );
    expect(
      controller.state.phase,
      RoundTripNavigationPhase.outboundActive,
    );

    controller.handleActionStatus(_statusMessage([1, 2, 3], 4));
    controller.handleActionStatus(_statusMessage([1, 2, 3], 4));
    expect(
      controller.state.phase,
      RoundTripNavigationPhase.outboundCooldown,
    );
    expect(goals, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(
      controller.state.phase,
      RoundTripNavigationPhase.returnWaiting,
    );
    expect(goals, hasLength(2));
    expect(goals.last.x, 1.2);
    expect(goals.last.y, -0.4);

    final returnId = base64Encode(const [7, 8, 9]);
    controller.handleActionStatus(_statusMessage(returnId, 1));
    expect(controller.state.phase, RoundTripNavigationPhase.returnActive);
    controller.handleActionStatus(_statusMessage(returnId, 4));
    expect(controller.state.phase, RoundTripNavigationPhase.completed);
    expect(stopCount, 0);
  });

  test('requires fresh AMCL, ignores stale UUIDs, and sends Stop once', () {
    final now = DateTime.utc(2026, 7, 14, 12);
    final goals = <RosPose2D>[];
    var stopCount = 0;
    final controller = RoundTripNavigationController(
      publishGoal: goals.add,
      publishStop: () => stopCount += 1,
      now: () => now,
      autoReturnDelay: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.updatePose(
      const RosPose2D(x: 0, y: 0, yaw: 0),
      receivedAt: now.subtract(const Duration(seconds: 3)),
    );
    expect(controller.captureHome(), isFalse);
    expect(controller.state.phase, RoundTripNavigationPhase.idle);

    controller.updatePose(
      const RosPose2D(x: 0, y: 0, yaw: 0),
      receivedAt: now,
    );
    expect(controller.captureHome(), isTrue);
    expect(
      controller.selectTarget(const RosPose2D(x: 0.5, y: 0, yaw: 0)),
      isTrue,
    );
    expect(controller.startOutbound(), isTrue);

    controller.handleActionStatus(_statusMessage([4], 4));
    expect(
      controller.state.phase,
      RoundTripNavigationPhase.outboundWaiting,
    );
    controller.handleActionStatus(_statusMessage([5], 2));
    expect(
      controller.state.phase,
      RoundTripNavigationPhase.outboundActive,
    );

    expect(controller.stop(), isTrue);
    expect(controller.stop(), isFalse);
    expect(stopCount, 1);
    controller.handleActionStatus(_statusMessage([5], 5));
    expect(controller.state.phase, RoundTripNavigationPhase.stopped);
    expect(goals, hasLength(1));
  });

  test('invalidating pose requires a new AMCL sample before Home', () {
    final now = DateTime.utc(2026, 7, 14, 12);
    final controller = RoundTripNavigationController(
      publishGoal: (_) {},
      publishStop: () {},
      now: () => now,
      poseMaxAge: const Duration(days: 1),
    );
    addTearDown(controller.dispose);

    controller.updatePose(
      const RosPose2D(x: 1, y: 2, yaw: 0.5),
      receivedAt: now,
    );
    controller.invalidatePose();
    expect(controller.captureHome(), isFalse);

    controller.updatePose(
      const RosPose2D(x: 1.1, y: 2.1, yaw: 0.6),
      receivedAt: now,
    );
    expect(controller.captureHome(), isTrue);
    expect(controller.state.home?.x, 1.1);
  });

  test('Stop during cooldown cancels automatic return', () async {
    final now = DateTime.utc(2026, 7, 14, 12);
    final goals = <RosPose2D>[];
    var stopCount = 0;
    final controller = RoundTripNavigationController(
      publishGoal: goals.add,
      publishStop: () => stopCount += 1,
      now: () => now,
      autoReturnDelay: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.updatePose(
      const RosPose2D(x: 1, y: 2, yaw: 0.5),
      receivedAt: now,
    );
    expect(controller.captureHome(), isTrue);
    expect(
      controller.selectTarget(const RosPose2D(x: 3, y: 4, yaw: 0)),
      isTrue,
    );
    expect(controller.startOutbound(), isTrue);
    controller.handleActionStatus(_statusMessage([1], 2));
    controller.handleActionStatus(_statusMessage([1], 4));
    expect(
      controller.state.phase,
      RoundTripNavigationPhase.outboundCooldown,
    );

    expect(controller.stop(), isTrue);
    expect(controller.stop(), isFalse);
    expect(controller.state.phase, RoundTripNavigationPhase.stopped);
    await Future<void>.delayed(const Duration(milliseconds: 15));

    expect(stopCount, 1);
    expect(goals, hasLength(1));
  });

  test('Stop wins when outbound success races with cancellation', () async {
    final now = DateTime.utc(2026, 7, 14, 12);
    final goals = <RosPose2D>[];
    var stopCount = 0;
    final controller = RoundTripNavigationController(
      publishGoal: goals.add,
      publishStop: () => stopCount += 1,
      now: () => now,
      autoReturnDelay: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.updatePose(
      const RosPose2D(x: 1, y: 2, yaw: 0.5),
      receivedAt: now,
    );
    expect(controller.captureHome(), isTrue);
    expect(
      controller.selectTarget(const RosPose2D(x: 3, y: 4, yaw: 0)),
      isTrue,
    );
    expect(controller.startOutbound(), isTrue);
    controller.handleActionStatus(_statusMessage([1], 2));
    expect(controller.stop(), isTrue);

    controller.handleActionStatus(_statusMessage([1], 4));
    expect(controller.state.phase, RoundTripNavigationPhase.stopped);
    await Future<void>.delayed(const Duration(milliseconds: 15));

    expect(stopCount, 1);
    expect(goals, hasLength(1));
  });
}

Map<String, dynamic> _statusMessage(Object uuid, int status) {
  return _statusList([_statusEntry(uuid, status)]);
}

Map<String, dynamic> _statusList(List<Map<String, dynamic>> statuses) {
  return {'status_list': statuses};
}

Map<String, dynamic> _statusEntry(Object uuid, int status) {
  return {
    'goal_info': {
      'goal_id': {'uuid': uuid},
    },
    'status': status,
  };
}
