import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/models/ros_navigation_models.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/application/employee_round_trip_controller.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/data/employee_round_trip_command_gateway.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/models/employee_round_trip_state.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/models/round_trip_backend_models.dart';

void main() {
  test('直连控制器自动发布去程和返航两个独立目标', () async {
    final now = DateTime.utc(2026, 7, 14, 12);
    final gateway = _FakeRoundTripGateway.direct();
    final controller = EmployeeRoundTripController(
      commandGateway: gateway,
      now: () => now,
      autoReturnDelay: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

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
    expect(await controller.startOutbound(), isTrue);
    expect(await controller.startOutbound(), isFalse);
    expect(gateway.outboundTargets, hasLength(1));

    controller.handleActionStatus(_statusMessage([1, 2, 3], 2));
    expect(controller.state.phase, EmployeeRoundTripPhase.outboundActive);
    controller.handleActionStatus(_statusMessage([1, 2, 3], 4));
    expect(controller.state.phase, EmployeeRoundTripPhase.outboundCooldown);
    await Future<void>.delayed(const Duration(milliseconds: 15));

    expect(controller.state.phase, EmployeeRoundTripPhase.returnWaiting);
    expect(gateway.returnTargets, hasLength(1));
    expect(gateway.returnTargets.single.x, 1.2);
    expect(gateway.returnTargets.single.y, -0.4);

    final returnId = base64Encode(const [7, 8, 9]);
    controller.handleActionStatus(_statusMessage(returnId, 2));
    expect(controller.state.phase, EmployeeRoundTripPhase.returnActive);
    controller.handleActionStatus(_statusMessage(returnId, 4));
    expect(controller.state.phase, EmployeeRoundTripPhase.completed);
  });

  test('直连 Stop 只发送一次并取消等待中的自动返航', () async {
    final now = DateTime.utc(2026, 7, 14, 12);
    final gateway = _FakeRoundTripGateway.direct();
    final controller = EmployeeRoundTripController(
      commandGateway: gateway,
      now: () => now,
      autoReturnDelay: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.updatePose(
      const RosPose2D(x: 1.1, y: 2.1, yaw: 0.1),
      receivedAt: now,
    );
    expect(controller.captureHome(), isTrue);
    expect(
      controller.selectTarget(const RosPose2D(x: 3, y: 4, yaw: 0)),
      isTrue,
    );
    expect(await controller.startOutbound(), isTrue);
    controller.handleActionStatus(_statusMessage([1], 2));
    controller.handleActionStatus(_statusMessage([1], 4));

    expect(await controller.stop(), isTrue);
    expect(await controller.stop(), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 15));

    expect(controller.state.phase, EmployeeRoundTripPhase.stopped);
    expect(gateway.stopCount, 1);
    expect(gateway.returnTargets, isEmpty);
  });

  test('后端模式只创建一个任务并完全忽略 ROS action status', () async {
    final now = DateTime.utc(2026, 7, 14, 12);
    final gateway = _FakeRoundTripGateway.backend(
      startSnapshot: const BackendRoundTripTaskSnapshot(
        taskId: 'task-1',
        status: 'QUEUED',
      ),
    );
    final controller = EmployeeRoundTripController(
      commandGateway: gateway,
      now: () => now,
      backendPollInterval: const Duration(days: 1),
    );
    addTearDown(controller.dispose);

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

    final firstStart = controller.startOutbound();
    final duplicateStart = controller.startOutbound();
    expect(await duplicateStart, isFalse);
    expect(await firstStart, isTrue);
    expect(gateway.outboundTargets, hasLength(1));
    expect(controller.state.backendTaskId, 'task-1');

    controller.handleActionStatus(_statusMessage([1, 2, 3], 4));
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(gateway.returnTargets, isEmpty);
    expect(controller.state.phase, EmployeeRoundTripPhase.outboundWaiting);

    controller.handleBackendTaskSnapshot(
      const BackendRoundTripTaskSnapshot(
        taskId: 'task-1',
        status: 'OUTBOUND_NAVIGATING',
        outboundGoalId: 'outbound-1',
      ),
    );
    expect(controller.state.phase, EmployeeRoundTripPhase.outboundActive);
    controller.handleBackendTaskSnapshot(
      const BackendRoundTripTaskSnapshot(
        taskId: 'task-1',
        status: 'RETURN_NAVIGATING',
        returnGoalId: 'return-1',
      ),
    );
    expect(controller.state.phase, EmployeeRoundTripPhase.returnActive);
    controller.handleBackendTaskSnapshot(
      const BackendRoundTripTaskSnapshot(
        taskId: 'task-1',
        status: 'COMPLETED',
      ),
    );
    expect(controller.state.phase, EmployeeRoundTripPhase.completed);
    expect(controller.state.outboundGoalId, 'outbound-1');
    expect(controller.state.returnGoalId, 'return-1');
  });

  test('后端 Stop 使用 taskId 且连续点击只请求一次', () async {
    final gateway = _FakeRoundTripGateway.backend(
      startSnapshot: const BackendRoundTripTaskSnapshot(
        taskId: 'task-stop',
        status: 'OUTBOUND_NAVIGATING',
      ),
      stopSnapshot: const BackendRoundTripTaskSnapshot(
        taskId: 'task-stop',
        status: 'CANCEL_REQUESTED',
      ),
    );
    final controller = EmployeeRoundTripController(
      commandGateway: gateway,
      backendPollInterval: const Duration(days: 1),
    );
    addTearDown(controller.dispose);

    controller.updatePose(const RosPose2D(x: 1, y: 2, yaw: 0));
    expect(controller.captureHome(), isTrue);
    expect(
      controller.selectTarget(const RosPose2D(x: 3, y: 4, yaw: 0)),
      isTrue,
    );
    expect(await controller.startOutbound(), isTrue);

    final firstStop = controller.stop();
    final duplicateStop = controller.stop();
    expect(await duplicateStop, isFalse);
    expect(await firstStop, isTrue);
    expect(gateway.stopCount, 1);
    expect(gateway.stoppedTaskIds, ['task-stop']);
    expect(controller.state.phase, EmployeeRoundTripPhase.stopping);
  });

  test('后端提交失败不会尝试直连或本地返航', () async {
    final gateway = _FakeRoundTripGateway.backend(
      startError: StateError('offline'),
    );
    final controller = EmployeeRoundTripController(
      commandGateway: gateway,
      autoReturnDelay: const Duration(milliseconds: 1),
    );
    addTearDown(controller.dispose);

    controller.updatePose(const RosPose2D(x: 1, y: 2, yaw: 0));
    expect(controller.captureHome(), isTrue);
    expect(
      controller.selectTarget(const RosPose2D(x: 3, y: 4, yaw: 0)),
      isTrue,
    );
    expect(await controller.startOutbound(), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(controller.state.phase, EmployeeRoundTripPhase.failed);
    expect(controller.state.message, contains('不会自动切换'));
    expect(gateway.outboundTargets, hasLength(1));
    expect(gateway.returnTargets, isEmpty);
    expect(gateway.stopCount, 0);
  });
}

Map<String, dynamic> _statusMessage(Object uuid, int status) {
  return {
    'status_list': [
      {
        'goal_info': {
          'goal_id': {'uuid': uuid},
        },
        'status': status,
      },
    ],
  };
}

class _FakeRoundTripGateway implements EmployeeRoundTripCommandGateway {
  _FakeRoundTripGateway.direct()
      : mode = RoundTripCommandMode.directRosbridge,
        startSnapshot = null,
        stopSnapshot = null,
        startError = null;

  _FakeRoundTripGateway.backend({
    this.startSnapshot,
    this.stopSnapshot,
    this.startError,
  }) : mode = RoundTripCommandMode.backendMediated;

  @override
  final RoundTripCommandMode mode;
  final BackendRoundTripTaskSnapshot? startSnapshot;
  final BackendRoundTripTaskSnapshot? stopSnapshot;
  final Object? startError;

  final initialPoses = <RosPose2D>[];
  final outboundHomes = <RosPose2D>[];
  final outboundTargets = <RosPose2D>[];
  final returnTargets = <RosPose2D>[];
  final stoppedTaskIds = <String?>[];
  int stopCount = 0;

  @override
  Future<void> setInitialPose(RosPose2D pose) async {
    initialPoses.add(pose);
  }

  @override
  Future<RoundTripStartReceipt> startOutbound({
    required RosPose2D home,
    required RosPose2D target,
  }) async {
    outboundHomes.add(home);
    outboundTargets.add(target);
    final error = startError;
    if (error != null) throw error;
    return RoundTripStartReceipt(task: startSnapshot);
  }

  @override
  Future<void> startReturn(RosPose2D home) async {
    returnTargets.add(home);
  }

  @override
  Future<BackendRoundTripTaskSnapshot?> stop({String? taskId}) async {
    stopCount += 1;
    stoppedTaskIds.add(taskId);
    return stopSnapshot;
  }

  @override
  Future<BackendRoundTripTaskSnapshot?> loadTask(String taskId) async {
    return startSnapshot;
  }
}
