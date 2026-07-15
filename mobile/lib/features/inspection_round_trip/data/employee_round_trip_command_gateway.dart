import '../../inspection_map/data/rosbridge_navigation_client.dart';
import '../../inspection_map/models/ros_navigation_models.dart';
import '../models/round_trip_backend_models.dart';
import 'backend_round_trip_api.dart';

class RoundTripStartReceipt {
  const RoundTripStartReceipt({this.task});

  final BackendRoundTripTaskSnapshot? task;
}

abstract interface class EmployeeRoundTripCommandGateway {
  RoundTripCommandMode get mode;

  Future<void> setInitialPose(RosPose2D pose);

  Future<RoundTripStartReceipt> startOutbound({
    required RosPose2D home,
    required RosPose2D target,
  });

  Future<void> startReturn(RosPose2D home);

  Future<BackendRoundTripTaskSnapshot?> stop({String? taskId});

  Future<BackendRoundTripTaskSnapshot?> loadTask(String taskId);
}

class DirectRosbridgeRoundTripGateway
    implements EmployeeRoundTripCommandGateway {
  DirectRosbridgeRoundTripGateway(this._client);

  final RosbridgeNavigationClient _client;

  @override
  RoundTripCommandMode get mode => RoundTripCommandMode.directRosbridge;

  @override
  Future<void> setInitialPose(RosPose2D pose) async {
    _client.publishInitialPose(x: pose.x, y: pose.y, yaw: pose.yaw);
  }

  @override
  Future<RoundTripStartReceipt> startOutbound({
    required RosPose2D home,
    required RosPose2D target,
  }) async {
    _client.publishGoalPose(x: target.x, y: target.y, yaw: target.yaw);
    return const RoundTripStartReceipt();
  }

  @override
  Future<void> startReturn(RosPose2D home) async {
    _client.publishGoalPose(x: home.x, y: home.y, yaw: home.yaw);
  }

  @override
  Future<BackendRoundTripTaskSnapshot?> stop({String? taskId}) async {
    _client.stopNavigation();
    return null;
  }

  @override
  Future<BackendRoundTripTaskSnapshot?> loadTask(String taskId) async => null;
}

class BackendMediatedRoundTripGateway
    implements EmployeeRoundTripCommandGateway {
  BackendMediatedRoundTripGateway({
    required BackendRoundTripApi api,
    required this.robotId,
    required this.map,
    required this.autoReturnDelay,
    DateTime Function()? now,
  })  : _api = api,
        _now = now ?? DateTime.now;

  final BackendRoundTripApi _api;
  final int robotId;
  final RoundTripMapPayload map;
  final Duration autoReturnDelay;
  final DateTime Function() _now;

  int _requestSequence = 0;

  @override
  RoundTripCommandMode get mode => RoundTripCommandMode.backendMediated;

  @override
  Future<void> setInitialPose(RosPose2D pose) {
    return _api.setInitialPose(
      robotId: robotId,
      map: map,
      pose: RoundTripPosePayload.fromPose(pose, source: 'map_tap'),
      clientRequestId: _nextRequestId('initial-pose'),
    );
  }

  @override
  Future<RoundTripStartReceipt> startOutbound({
    required RosPose2D home,
    required RosPose2D target,
  }) async {
    final requestId = _nextRequestId('round-trip');
    final task = await _api.createRoundTrip(
      robotId: robotId,
      submission: RoundTripSubmission(
        clientRequestId: requestId,
        home: RoundTripPosePayload.fromPose(home, source: 'amcl'),
        target: RoundTripPosePayload.fromPose(target, source: 'map_tap'),
        map: map,
        autoReturnDelay: autoReturnDelay,
        createdAt: _now(),
      ),
    );
    return RoundTripStartReceipt(task: task);
  }

  @override
  Future<void> startReturn(RosPose2D home) {
    throw StateError('后端模式由后端负责自动返航，前端不能再次发送 Home。');
  }

  @override
  Future<BackendRoundTripTaskSnapshot?> stop({String? taskId}) {
    if (taskId == null || taskId.isEmpty) {
      throw StateError('后端任务尚未建立，无法发送任务 Stop。');
    }
    return _api.stopTask(
      robotId: robotId,
      taskId: taskId,
      clientRequestId: _nextRequestId('stop'),
    );
  }

  @override
  Future<BackendRoundTripTaskSnapshot?> loadTask(String taskId) {
    return _api.loadTask(robotId: robotId, taskId: taskId);
  }

  String _nextRequestId(String operation) {
    _requestSequence += 1;
    return 'android-$robotId-$operation-'
        '${_now().toUtc().microsecondsSinceEpoch}-$_requestSequence';
  }
}
