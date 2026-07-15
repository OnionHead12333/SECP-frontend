import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../inspection_map/models/ros_navigation_models.dart';
import '../data/employee_round_trip_command_gateway.dart';
import '../models/employee_round_trip_state.dart';
import '../models/round_trip_backend_models.dart';

enum _NavigationLeg { outbound, returning }

class EmployeeRoundTripController extends ChangeNotifier {
  EmployeeRoundTripController({
    required EmployeeRoundTripCommandGateway commandGateway,
    DateTime Function()? now,
    this.poseMaxAge = const Duration(days: 1),
    this.autoReturnDelay = const Duration(seconds: 2),
    this.backendPollInterval = const Duration(seconds: 2),
  })  : _commandGateway = commandGateway,
        _now = now ?? DateTime.now;

  final EmployeeRoundTripCommandGateway _commandGateway;
  final DateTime Function() _now;
  final Duration poseMaxAge;
  final Duration autoReturnDelay;
  final Duration backendPollInterval;

  EmployeeRoundTripPhase _phase = EmployeeRoundTripPhase.idle;
  RosPose2D? _latestPose;
  DateTime? _latestPoseAt;
  RosPose2D? _home;
  RosPose2D? _target;
  String? _activeGoalId;
  String? _backendTaskId;
  String? _outboundGoalId;
  String? _returnGoalId;
  String? _backendStatus;
  String? _message;
  _NavigationLeg? _activeLeg;
  Set<String> _goalBaseline = const {};
  final Map<String, RosGoalStatus> _observedGoalStatuses = {};
  bool _commandPending = false;
  bool _stopIssued = false;
  bool _backendPollInFlight = false;
  bool _disposed = false;
  int _operationGeneration = 0;
  Timer? _autoReturnTimer;
  Timer? _backendPollTimer;

  RoundTripCommandMode get commandMode => _commandGateway.mode;

  EmployeeRoundTripState get state => EmployeeRoundTripState(
        commandMode: commandMode,
        phase: _phase,
        latestPose: _latestPose,
        home: _home,
        target: _target,
        activeGoalId: _activeGoalId,
        backendTaskId: _backendTaskId,
        outboundGoalId: _outboundGoalId,
        returnGoalId: _returnGoalId,
        backendStatus: _backendStatus,
        commandPending: _commandPending,
        message: _message,
      );

  bool get hasFreshPose {
    final receivedAt = _latestPoseAt;
    return _latestPose != null &&
        receivedAt != null &&
        !_now().difference(receivedAt).isNegative &&
        _now().difference(receivedAt) <= poseMaxAge;
  }

  void updatePose(RosPose2D pose, {DateTime? receivedAt}) {
    _latestPose = pose;
    _latestPoseAt = receivedAt ?? _now();
    notifyListeners();
  }

  void invalidatePose() {
    _latestPose = null;
    _latestPoseAt = null;
    notifyListeners();
  }

  Future<bool> setInitialPose(RosPose2D pose) async {
    if (_commandPending || state.isBusy) return false;
    final generation = _operationGeneration;
    _latestPose = null;
    _latestPoseAt = null;
    _commandPending = true;
    _message = commandMode == RoundTripCommandMode.directRosbridge
        ? '正在向 rosbridge 发送初始位置。'
        : '正在由后端设置初始位置。';
    notifyListeners();

    var succeeded = false;
    try {
      await _commandGateway.setInitialPose(pose);
      if (!_isCurrentOperation(generation)) return false;
      _message = commandMode == RoundTripCommandMode.directRosbridge
          ? '初始位置已发送，请等待新的 AMCL 定位。'
          : '后端已接收初始位置，请等待新的 AMCL 定位。';
      succeeded = true;
    } catch (error) {
      if (!_isCurrentOperation(generation)) return false;
      _message = '设置初始位置失败：$error';
    } finally {
      if (_isCurrentOperation(generation)) {
        _commandPending = false;
        notifyListeners();
      }
    }
    return succeeded;
  }

  bool captureHome() {
    if (_commandPending || state.isBusy || !hasFreshPose) {
      _setMessage('请等待新的 AMCL 定位后再记录返航点。');
      return false;
    }
    _home = _latestPose;
    _target = null;
    _clearCommandIdentity();
    _activeLeg = null;
    _phase = EmployeeRoundTripPhase.homeCaptured;
    _message = '已使用当前 AMCL 位置记录返航点。';
    _stopIssued = false;
    notifyListeners();
    return true;
  }

  bool selectTarget(RosPose2D pose) {
    if (_commandPending || state.isBusy || _home == null) {
      _setMessage('请先记录返航点，再选择巡检目标。');
      return false;
    }
    _target = pose;
    _phase = EmployeeRoundTripPhase.targetReady;
    _message = '巡检目标已选择。';
    notifyListeners();
    return true;
  }

  Future<bool> startOutbound() async {
    if (!state.canStartOutbound) return false;
    final generation = _operationGeneration;
    final home = _home!;
    final target = _target!;
    _commandPending = true;
    _stopIssued = false;
    _clearCommandIdentity();
    _phase = EmployeeRoundTripPhase.outboundWaiting;

    if (commandMode == RoundTripCommandMode.directRosbridge) {
      _goalBaseline = Set<String>.from(_observedGoalStatuses.keys);
      _activeLeg = _NavigationLeg.outbound;
      _message = '正在向 rosbridge 发送去程目标。';
    } else {
      _activeLeg = null;
      _message = '正在向后端提交完整往返任务。';
    }
    notifyListeners();

    var succeeded = false;
    try {
      final receipt = await _commandGateway.startOutbound(
        home: home,
        target: target,
      );
      if (!_isCurrentOperation(generation)) return false;
      if (commandMode == RoundTripCommandMode.backendMediated) {
        final task = receipt.task;
        if (task == null || task.taskId.trim().isEmpty) {
          throw StateError('后端没有返回有效的 taskId。');
        }
        _applyBackendSnapshot(task);
        _scheduleBackendPoll();
      } else {
        _message = '去程目标已发送。';
      }
      succeeded = true;
    } catch (error) {
      if (!_isCurrentOperation(generation)) return false;
      _setFailed(
        commandMode == RoundTripCommandMode.backendMediated
            ? '后端往返任务提交失败：$error。不会自动切换为 rosbridge 直连。'
            : '发送导航目标失败：$error',
      );
    } finally {
      if (_isCurrentOperation(generation)) {
        _commandPending = false;
        notifyListeners();
      }
    }
    return succeeded;
  }

  Future<bool> stop() async {
    if (_commandPending || !state.canStop || _stopIssued) return false;
    final generation = _operationGeneration;
    final previousPhase = _phase;
    final wasWaitingToReturn =
        previousPhase == EmployeeRoundTripPhase.outboundCooldown;
    _commandPending = true;
    _stopIssued = true;
    _autoReturnTimer?.cancel();
    _phase = EmployeeRoundTripPhase.stopping;
    _message = commandMode == RoundTripCommandMode.directRosbridge
        ? '正在发送统一 Stop。'
        : '正在请求后端停止任务。';
    notifyListeners();

    var succeeded = false;
    try {
      final snapshot = await _commandGateway.stop(taskId: _backendTaskId);
      if (!_isCurrentOperation(generation)) return false;
      if (commandMode == RoundTripCommandMode.backendMediated) {
        if (snapshot == null) {
          throw StateError('后端没有返回停止后的任务状态。');
        }
        _applyBackendSnapshot(snapshot);
        _scheduleBackendPoll();
      } else if (wasWaitingToReturn) {
        _phase = EmployeeRoundTripPhase.stopped;
        _message = '已取消自动返航。';
        _activeGoalId = null;
        _activeLeg = null;
        _stopIssued = false;
      } else {
        _phase = EmployeeRoundTripPhase.stopping;
        _message = '停止命令已发送，正在等待 Nav2 确认。';
      }
      succeeded = true;
    } catch (error) {
      if (!_isCurrentOperation(generation)) return false;
      _phase = previousPhase;
      _stopIssued = false;
      _message = commandMode == RoundTripCommandMode.backendMediated
          ? '后端 Stop 请求失败：$error。任务状态未确认，可重试；不会切换为直连。'
          : '停止失败：$error';
    } finally {
      if (_isCurrentOperation(generation)) {
        _commandPending = false;
        notifyListeners();
      }
    }
    return succeeded;
  }

  void handleActionStatus(Map<String, dynamic> message) {
    if (commandMode != RoundTripCommandMode.directRosbridge) return;
    final statuses = _parseGoalStatuses(message);
    if (statuses.isEmpty) return;
    _observedGoalStatuses.addAll(statuses);

    if (_activeGoalId == null && _isWaitingForGoal) {
      final candidates = statuses.entries
          .where(
            (entry) =>
                !_goalBaseline.contains(entry.key) &&
                _isActiveGoalStatus(entry.value),
          )
          .toList(growable: false);
      if (candidates.length > 1) {
        _fail('检测到多个新的导航任务，已停止本次往返流程。');
        return;
      }
      if (candidates.length == 1) {
        _activeGoalId = candidates.single.key;
      }
    }

    final goalId = _activeGoalId;
    if (goalId == null) return;
    final status = _observedGoalStatuses[goalId];
    if (status == null) return;

    switch (status) {
      case RosGoalStatus.accepted:
      case RosGoalStatus.executing:
        if (_stopIssued) {
          _phase = EmployeeRoundTripPhase.stopping;
          _message = '正在等待 Nav2 完成停止。';
        } else {
          _phase = _activeLeg == _NavigationLeg.outbound
              ? EmployeeRoundTripPhase.outboundActive
              : EmployeeRoundTripPhase.returnActive;
          _message = _activeLeg == _NavigationLeg.outbound
              ? '正在前往巡检目标。'
              : '正在自动返回起点。';
        }
      case RosGoalStatus.canceling:
        _phase = EmployeeRoundTripPhase.stopping;
        _message = 'Nav2 正在取消当前导航。';
      case RosGoalStatus.succeeded:
        if (_stopIssued) {
          _phase = EmployeeRoundTripPhase.stopped;
          _message = '导航已停止，未启动自动返航。';
        } else if (_activeLeg == _NavigationLeg.outbound) {
          _phase = EmployeeRoundTripPhase.outboundCooldown;
          _message = '已到达目标，等待自动返航。';
          _scheduleAutomaticReturn();
        } else {
          _phase = EmployeeRoundTripPhase.completed;
          _message = '已返回记录的起点。';
        }
        _activeGoalId = null;
        _activeLeg = null;
        _stopIssued = false;
      case RosGoalStatus.canceled:
        _phase = EmployeeRoundTripPhase.stopped;
        _message = '导航已取消。';
        _activeGoalId = null;
        _activeLeg = null;
        _stopIssued = false;
      case RosGoalStatus.aborted:
        _fail('Nav2 中止了导航，系统不会自动重试。');
        return;
      case RosGoalStatus.unknown:
        return;
    }
    notifyListeners();
  }

  void handleBackendTaskSnapshot(BackendRoundTripTaskSnapshot snapshot) {
    if (commandMode != RoundTripCommandMode.backendMediated) return;
    final taskId = _backendTaskId;
    if (taskId == null || snapshot.taskId != taskId) return;
    _applyBackendSnapshot(snapshot);
    _scheduleBackendPoll();
    notifyListeners();
  }

  void handleDisconnect() {
    if (commandMode == RoundTripCommandMode.backendMediated) {
      _setMessage(
        state.isBusy
            ? 'ROS 遥测连接已断开；后端任务仍由后端控制，不会切换为直连。'
            : 'ROS 遥测连接不可用；后端控制模式保持不变。',
      );
      return;
    }
    _autoReturnTimer?.cancel();
    if (state.isBusy) {
      _fail('ROS 连接已断开，本次任务不会自动恢复。');
    } else {
      _setMessage('ROS 连接不可用。');
    }
  }

  bool resetTrip() {
    if (_commandPending || state.isBusy) return false;
    _operationGeneration += 1;
    _phase = EmployeeRoundTripPhase.idle;
    _autoReturnTimer?.cancel();
    _backendPollTimer?.cancel();
    _home = null;
    _target = null;
    _clearCommandIdentity();
    _activeLeg = null;
    _message = null;
    _stopIssued = false;
    _backendPollInFlight = false;
    notifyListeners();
    return true;
  }

  bool get _isWaitingForGoal =>
      _phase == EmployeeRoundTripPhase.outboundWaiting ||
      _phase == EmployeeRoundTripPhase.returnWaiting ||
      _phase == EmployeeRoundTripPhase.stopping;

  void _scheduleAutomaticReturn() {
    if (commandMode != RoundTripCommandMode.directRosbridge) return;
    _autoReturnTimer?.cancel();
    final generation = _operationGeneration;
    _autoReturnTimer = Timer(autoReturnDelay, () {
      if (!_isCurrentOperation(generation) ||
          _phase != EmployeeRoundTripPhase.outboundCooldown) {
        return;
      }
      final home = _home;
      if (home == null) {
        _fail('返航点不可用，无法自动返航。');
        return;
      }
      unawaited(_startDirectReturn(home, generation));
    });
  }

  Future<void> _startDirectReturn(
    RosPose2D home,
    int generation,
  ) async {
    _goalBaseline = Set<String>.from(_observedGoalStatuses.keys);
    _activeGoalId = null;
    _activeLeg = _NavigationLeg.returning;
    _commandPending = true;
    _phase = EmployeeRoundTripPhase.returnWaiting;
    _message = '正在向 rosbridge 发送自动返航目标。';
    notifyListeners();
    try {
      await _commandGateway.startReturn(home);
      if (!_isCurrentOperation(generation)) return;
      _message = '自动返航目标已发送。';
    } catch (error) {
      if (!_isCurrentOperation(generation)) return;
      _setFailed('发送自动返航目标失败：$error');
    } finally {
      if (_isCurrentOperation(generation)) {
        _commandPending = false;
        notifyListeners();
      }
    }
  }

  void _scheduleBackendPoll() {
    _backendPollTimer?.cancel();
    if (commandMode != RoundTripCommandMode.backendMediated ||
        _backendTaskId == null ||
        _isBackendTerminalStatus(_backendStatus)) {
      return;
    }
    final generation = _operationGeneration;
    _backendPollTimer = Timer(
      backendPollInterval,
      () => unawaited(_pollBackendTask(generation)),
    );
  }

  Future<void> _pollBackendTask(int generation) async {
    final taskId = _backendTaskId;
    if (!_isCurrentOperation(generation) ||
        taskId == null ||
        _backendPollInFlight) {
      return;
    }
    _backendPollInFlight = true;
    try {
      final snapshot = await _commandGateway.loadTask(taskId);
      if (!_isCurrentOperation(generation) || _backendTaskId != taskId) return;
      if (snapshot == null || snapshot.taskId != taskId) {
        throw StateError('后端返回了不匹配的往返任务。');
      }
      _applyBackendSnapshot(snapshot);
    } catch (error) {
      if (!_isCurrentOperation(generation) || _backendTaskId != taskId) return;
      _message = '后端状态查询失败：$error。任务可能仍在运行，将继续查询且不会切换为直连。';
    } finally {
      if (_isCurrentOperation(generation)) {
        _backendPollInFlight = false;
        _scheduleBackendPoll();
        notifyListeners();
      }
    }
  }

  void _applyBackendSnapshot(BackendRoundTripTaskSnapshot snapshot) {
    _backendTaskId = snapshot.taskId;
    _outboundGoalId = snapshot.outboundGoalId ?? _outboundGoalId;
    _returnGoalId = snapshot.returnGoalId ?? _returnGoalId;
    _backendStatus = snapshot.status.trim().toUpperCase();
    final status = _backendStatus!;

    if (_stopIssued &&
        status != 'CANCELED' &&
        status != 'CANCELLED' &&
        status != 'STOPPED' &&
        status != 'COMPLETED' &&
        status != 'FAILED' &&
        status != 'ABORTED' &&
        status != 'REJECTED' &&
        status != 'STALE') {
      _phase = EmployeeRoundTripPhase.stopping;
      _message = snapshot.message ?? '后端正在停止往返任务。';
      return;
    }

    switch (status) {
      case 'QUEUED':
      case 'CREATED':
      case 'SUBMITTED':
      case 'ACCEPTED':
      case 'PENDING':
        _phase = EmployeeRoundTripPhase.outboundWaiting;
      case 'OUTBOUND_NAVIGATING':
      case 'OUTBOUND_ACTIVE':
      case 'NAVIGATING':
      case 'NAVIGATING_TO_TARGET':
        _phase = EmployeeRoundTripPhase.outboundActive;
      case 'OUTBOUND_SUCCEEDED':
      case 'TARGET_REACHED':
      case 'RETURN_COOLDOWN':
      case 'WAITING_TO_RETURN':
        _phase = EmployeeRoundTripPhase.outboundCooldown;
      case 'RETURN_QUEUED':
      case 'RETURN_WAITING':
        _phase = EmployeeRoundTripPhase.returnWaiting;
      case 'RETURN_NAVIGATING':
      case 'RETURN_ACTIVE':
      case 'NAVIGATING_HOME':
        _phase = EmployeeRoundTripPhase.returnActive;
      case 'COMPLETED':
      case 'SUCCEEDED':
        _phase = EmployeeRoundTripPhase.completed;
        _stopIssued = false;
        _backendPollTimer?.cancel();
      case 'CANCEL_REQUESTED':
      case 'CANCELING':
      case 'CANCELLING':
      case 'STOPPING':
        _phase = EmployeeRoundTripPhase.stopping;
      case 'CANCELED':
      case 'CANCELLED':
      case 'STOPPED':
        _phase = EmployeeRoundTripPhase.stopped;
        _stopIssued = false;
        _backendPollTimer?.cancel();
      case 'FAILED':
      case 'ABORTED':
      case 'REJECTED':
      case 'STALE':
        _phase = EmployeeRoundTripPhase.failed;
        _stopIssued = false;
        _backendPollTimer?.cancel();
      default:
        _message = snapshot.message ?? '后端返回未知任务状态：$status。';
        return;
    }
    _message = snapshot.message ?? _defaultBackendMessage(_phase);
  }

  void _clearCommandIdentity() {
    _activeGoalId = null;
    _backendTaskId = null;
    _outboundGoalId = null;
    _returnGoalId = null;
    _backendStatus = null;
  }

  void _setMessage(String message) {
    _message = message;
    notifyListeners();
  }

  void _setFailed(String message) {
    _autoReturnTimer?.cancel();
    _backendPollTimer?.cancel();
    _phase = EmployeeRoundTripPhase.failed;
    _message = message;
    _activeGoalId = null;
    _activeLeg = null;
    _stopIssued = false;
  }

  void _fail(String message) {
    _setFailed(message);
    notifyListeners();
  }

  bool _isCurrentOperation(int generation) =>
      !_disposed && generation == _operationGeneration;

  @override
  void dispose() {
    _disposed = true;
    _operationGeneration += 1;
    _autoReturnTimer?.cancel();
    _backendPollTimer?.cancel();
    super.dispose();
  }
}

Map<String, RosGoalStatus> _parseGoalStatuses(Map<String, dynamic> message) {
  final rawStatuses = message['status_list'];
  if (rawStatuses is! List) return const {};
  final result = <String, RosGoalStatus>{};
  for (final rawStatus in rawStatuses) {
    final status = _asMap(rawStatus);
    final goalInfo = _asMap(status['goal_info']);
    final goalId = _asMap(goalInfo['goal_id']);
    final normalizedId = _normalizeGoalId(goalId['uuid']);
    if (normalizedId == null) continue;
    result[normalizedId] = switch (_asInt(status['status'])) {
      1 => RosGoalStatus.accepted,
      2 => RosGoalStatus.executing,
      3 => RosGoalStatus.canceling,
      4 => RosGoalStatus.succeeded,
      5 => RosGoalStatus.canceled,
      6 => RosGoalStatus.aborted,
      _ => RosGoalStatus.unknown,
    };
  }
  return result;
}

String? _normalizeGoalId(Object? rawUuid) {
  if (rawUuid is List) {
    final bytes = rawUuid.map(_asInt).toList(growable: false);
    if (bytes.isEmpty) return null;
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
  if (rawUuid is String && rawUuid.trim().isNotEmpty) {
    final value = rawUuid.trim();
    try {
      final bytes = base64Decode(value);
      if (bytes.isNotEmpty) {
        return bytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
      }
    } on FormatException {
      return value;
    }
    return value;
  }
  return null;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

bool _isActiveGoalStatus(RosGoalStatus status) =>
    status == RosGoalStatus.accepted ||
    status == RosGoalStatus.executing ||
    status == RosGoalStatus.canceling;

bool _isBackendTerminalStatus(String? status) {
  return switch (status?.toUpperCase()) {
    'COMPLETED' ||
    'SUCCEEDED' ||
    'CANCELED' ||
    'CANCELLED' ||
    'STOPPED' ||
    'FAILED' ||
    'ABORTED' ||
    'REJECTED' ||
    'STALE' =>
      true,
    _ => false,
  };
}

String _defaultBackendMessage(EmployeeRoundTripPhase phase) {
  return switch (phase) {
    EmployeeRoundTripPhase.outboundWaiting => '后端已建立任务，等待去程导航。',
    EmployeeRoundTripPhase.outboundActive => '后端正在控制小车前往巡检目标。',
    EmployeeRoundTripPhase.outboundCooldown => '小车已到达目标，后端正在安排自动返航。',
    EmployeeRoundTripPhase.returnWaiting => '后端正在发送返航目标。',
    EmployeeRoundTripPhase.returnActive => '后端正在控制小车返回起点。',
    EmployeeRoundTripPhase.completed => '后端确认往返巡检完成。',
    EmployeeRoundTripPhase.stopping => '后端正在停止往返任务。',
    EmployeeRoundTripPhase.stopped => '后端确认任务已停止。',
    EmployeeRoundTripPhase.failed => '后端报告往返任务失败。',
    _ => phase.label,
  };
}
