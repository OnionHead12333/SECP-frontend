import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/features/inspection_map/models/ros_navigation_models.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/data/backend_round_trip_api.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/data/employee_round_trip_command_gateway.dart';
import 'package:smart_elderly_care_mobile/features/inspection_round_trip/models/round_trip_backend_models.dart';

void main() {
  test('后端网关提交完整 Home、Target、地图和自动返航策略', () async {
    final now = DateTime.utc(2026, 7, 14, 8, 30);
    final api = _RecordingBackendRoundTripApi();
    final gateway = BackendMediatedRoundTripGateway(
      api: api,
      robotId: 7,
      map: const RoundTripMapPayload(
        mapId: 3,
        mapRevision: 'yahboomcar-r2',
        mapName: 'yahboomcar',
        width: 864,
        height: 896,
        resolution: 0.05,
        origin: [-22.8, -22.8, 0],
        frameId: 'map',
      ),
      autoReturnDelay: const Duration(seconds: 2),
      now: () => now,
    );

    await gateway.setInitialPose(
      const RosPose2D(x: 1, y: 2, yaw: 0.2),
    );
    final receipt = await gateway.startOutbound(
      home: const RosPose2D(x: 1.2, y: -0.4, yaw: 0.3),
      target: const RosPose2D(x: 2, y: 0.5, yaw: -0.2),
    );

    expect(api.initialPoseRobotId, 7);
    expect(api.initialPose?.source, 'map_tap');
    expect(api.initialPoseRequestId, startsWith('android-7-initial-pose-'));
    expect(api.createdRobotId, 7);
    expect(receipt.task?.taskId, 'task-api');
    final json = api.submission!.toJson();
    expect(json['mapId'], 3);
    expect(json['mapRevision'], 'yahboomcar-r2');
    expect(json['createdAt'], '2026-07-14T08:30:00.000Z');
    expect(json['home'], {
      'x': 1.2,
      'y': -0.4,
      'yaw': 0.3,
      'frameId': 'map',
      'source': 'amcl',
    });
    expect(json['target'], {
      'x': 2.0,
      'y': 0.5,
      'yaw': -0.2,
      'frameId': 'map',
      'source': 'map_tap',
    });
    expect(json['policy'], {
      'autoReturn': true,
      'autoReturnDelayMs': 2000,
    });
    expect(
      api.submission!.clientRequestId,
      isNot(api.initialPoseRequestId),
    );

    expect(
      () => gateway.startReturn(
        const RosPose2D(x: 1.2, y: -0.4, yaw: 0.3),
      ),
      throwsStateError,
    );
    final stopped = await gateway.stop(taskId: 'task-api');
    expect(stopped?.status, 'CANCEL_REQUESTED');
    expect(api.stoppedTaskId, 'task-api');
    expect(api.stopRequestId, startsWith('android-7-stop-'));
  });

  test('未知 transport 配置不会静默退回直连模式', () {
    expect(
      () => RoundTripCommandMode.parse('direct_rosbrigde'),
      throwsArgumentError,
    );
    expect(
      RoundTripCommandMode.parse('direct_rosbridge'),
      RoundTripCommandMode.directRosbridge,
    );
    expect(
      RoundTripCommandMode.parse('backend_mediated'),
      RoundTripCommandMode.backendMediated,
    );
  });
}

class _RecordingBackendRoundTripApi implements BackendRoundTripApi {
  int? initialPoseRobotId;
  RoundTripPosePayload? initialPose;
  String? initialPoseRequestId;
  int? createdRobotId;
  RoundTripSubmission? submission;
  String? stoppedTaskId;
  String? stopRequestId;

  @override
  Future<void> setInitialPose({
    required int robotId,
    required RoundTripMapPayload map,
    required RoundTripPosePayload pose,
    required String clientRequestId,
  }) async {
    initialPoseRobotId = robotId;
    initialPose = pose;
    initialPoseRequestId = clientRequestId;
  }

  @override
  Future<BackendRoundTripTaskSnapshot> createRoundTrip({
    required int robotId,
    required RoundTripSubmission submission,
  }) async {
    createdRobotId = robotId;
    this.submission = submission;
    return const BackendRoundTripTaskSnapshot(
      taskId: 'task-api',
      status: 'QUEUED',
    );
  }

  @override
  Future<BackendRoundTripTaskSnapshot> loadTask({
    required int robotId,
    required String taskId,
  }) async {
    return BackendRoundTripTaskSnapshot(taskId: taskId, status: 'QUEUED');
  }

  @override
  Future<BackendRoundTripTaskSnapshot> stopTask({
    required int robotId,
    required String taskId,
    required String clientRequestId,
  }) async {
    stoppedTaskId = taskId;
    stopRequestId = clientRequestId;
    return BackendRoundTripTaskSnapshot(
      taskId: taskId,
      status: 'CANCEL_REQUESTED',
    );
  }
}
