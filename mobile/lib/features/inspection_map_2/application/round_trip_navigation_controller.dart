import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../inspection_map/models/ros_navigation_models.dart';
import '../models/round_trip_navigation_state.dart';

typedef RoundTripGoalPublisher = void Function(RosPose2D pose);
typedef RoundTripStopPublisher = void Function();

enum _RoundTripLeg { outbound, returning }

class RoundTripNavigationController extends ChangeNotifier {
  RoundTripNavigationController({
    required RoundTripGoalPublisher publishGoal,
    required RoundTripStopPublisher publishStop,
    DateTime Function()? now,
    this.poseMaxAge = const Duration(seconds: 2),
    this.autoReturnDelay = const Duration(seconds: 2),
  })  : _publishGoal = publishGoal,
        _publishStop = publishStop,
        _now = now ?? DateTime.now;

  final RoundTripGoalPublisher _publishGoal;
  final RoundTripStopPublisher _publishStop;
  final DateTime Function() _now;
  final Duration poseMaxAge;
  final Duration autoReturnDelay;

  RoundTripNavigationPhase _phase = RoundTripNavigationPhase.idle;
  RosPose2D? _latestPose;
  DateTime? _latestPoseAt;
  RosPose2D? _home;
  RosPose2D? _target;
  String? _activeGoalId;
  String? _message;
  _RoundTripLeg? _activeLeg;
  Set<String> _goalBaseline = const {};
  final Map<String, RosGoalStatus> _observedGoalStatuses = {};
  bool _stopIssued = false;
  Timer? _autoReturnTimer;

  RoundTripNavigationState get state => RoundTripNavigationState(
        phase: _phase,
        latestPose: _latestPose,
        home: _home,
        target: _target,
        activeGoalId: _activeGoalId,
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

  bool captureHome() {
    if (_stateBlocksEditing || !hasFreshPose) {
      _setMessage('A fresh AMCL pose is required before capturing home.');
      return false;
    }
    _home = _latestPose;
    _target = null;
    _activeGoalId = null;
    _activeLeg = null;
    _phase = RoundTripNavigationPhase.homeCaptured;
    _message = 'Home saved from the latest AMCL pose.';
    _stopIssued = false;
    notifyListeners();
    return true;
  }

  bool selectTarget(RosPose2D pose) {
    if (_stateBlocksEditing || _home == null) {
      _setMessage('Capture home before selecting a destination.');
      return false;
    }
    _target = pose;
    _phase = RoundTripNavigationPhase.targetReady;
    _message = 'Destination selected.';
    notifyListeners();
    return true;
  }

  bool startOutbound() {
    if (!state.canStartOutbound) return false;
    return _startLeg(
      pose: _target!,
      leg: _RoundTripLeg.outbound,
      waitingPhase: RoundTripNavigationPhase.outboundWaiting,
      message: 'Outbound goal published once.',
    );
  }

  bool stop() {
    if (!state.canStop || _stopIssued) return false;
    final wasWaitingToReturn =
        _phase == RoundTripNavigationPhase.outboundCooldown;
    try {
      _publishStop();
      _autoReturnTimer?.cancel();
      _stopIssued = true;
      if (wasWaitingToReturn) {
        _phase = RoundTripNavigationPhase.stopped;
        _message = 'Automatic return was canceled by Stop.';
        _activeGoalId = null;
        _activeLeg = null;
      } else {
        _phase = RoundTripNavigationPhase.stopping;
        _message = 'One Stop request was published.';
      }
      notifyListeners();
      return true;
    } catch (error) {
      _fail('Stop failed: $error');
      return false;
    }
  }

  void handleActionStatus(Map<String, dynamic> message) {
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
        _fail(
          'Multiple new Nav2 goals were observed. The trip was not resumed.',
        );
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
          _phase = RoundTripNavigationPhase.stopping;
          _message = 'Stop is pending while Nav2 confirms the goal.';
        } else {
          _phase = _activeLeg == _RoundTripLeg.outbound
              ? RoundTripNavigationPhase.outboundActive
              : RoundTripNavigationPhase.returnActive;
          _message = _activeLeg == _RoundTripLeg.outbound
              ? 'Outbound goal accepted by Nav2.'
              : 'Return goal accepted by Nav2.';
        }
      case RosGoalStatus.canceling:
        _phase = RoundTripNavigationPhase.stopping;
        _message = 'Nav2 is canceling the active goal.';
      case RosGoalStatus.succeeded:
        if (_stopIssued) {
          _phase = RoundTripNavigationPhase.stopped;
          _message = 'Navigation stopped. Automatic return was not started.';
        } else if (_activeLeg == _RoundTripLeg.outbound) {
          _phase = RoundTripNavigationPhase.outboundCooldown;
          _message = 'Destination reached. Automatic return is pending.';
          _scheduleAutomaticReturn();
        } else {
          _phase = RoundTripNavigationPhase.completed;
          _message = 'The robot returned to the captured home pose.';
        }
        _activeGoalId = null;
        _activeLeg = null;
        _stopIssued = false;
      case RosGoalStatus.canceled:
        _phase = RoundTripNavigationPhase.stopped;
        _message = 'Navigation was canceled.';
        _activeGoalId = null;
        _activeLeg = null;
        _stopIssued = false;
      case RosGoalStatus.aborted:
        _fail('Nav2 aborted the active goal. No automatic retry was sent.');
      case RosGoalStatus.unknown:
        return;
    }
    notifyListeners();
  }

  void handleDisconnect() {
    _autoReturnTimer?.cancel();
    if (state.isBusy) {
      _fail('ROS connection was lost. The trip will not resume automatically.');
    } else {
      _setMessage('ROS connection is not available.');
    }
  }

  bool resetTrip() {
    if (state.isBusy) return false;
    _phase = RoundTripNavigationPhase.idle;
    _autoReturnTimer?.cancel();
    _home = null;
    _target = null;
    _activeGoalId = null;
    _activeLeg = null;
    _message = null;
    _stopIssued = false;
    notifyListeners();
    return true;
  }

  bool _startLeg({
    required RosPose2D pose,
    required _RoundTripLeg leg,
    required RoundTripNavigationPhase waitingPhase,
    required String message,
  }) {
    _goalBaseline = Set<String>.from(_observedGoalStatuses.keys);
    _activeGoalId = null;
    _activeLeg = leg;
    _stopIssued = false;
    try {
      _publishGoal(pose);
      _phase = waitingPhase;
      _message = message;
      notifyListeners();
      return true;
    } catch (error) {
      _fail('Goal publish failed: $error');
      return false;
    }
  }

  bool get _isWaitingForGoal =>
      _phase == RoundTripNavigationPhase.outboundWaiting ||
      _phase == RoundTripNavigationPhase.returnWaiting ||
      _phase == RoundTripNavigationPhase.stopping;

  bool get _stateBlocksEditing => state.isBusy;

  void _setMessage(String message) {
    _message = message;
    notifyListeners();
  }

  void _fail(String message) {
    _autoReturnTimer?.cancel();
    _phase = RoundTripNavigationPhase.failed;
    _message = message;
    _activeGoalId = null;
    _activeLeg = null;
    _stopIssued = false;
    notifyListeners();
  }

  void _scheduleAutomaticReturn() {
    _autoReturnTimer?.cancel();
    _autoReturnTimer = Timer(autoReturnDelay, () {
      if (_phase != RoundTripNavigationPhase.outboundCooldown) return;
      final home = _home;
      if (home == null) {
        _fail('Automatic return failed because the home pose is unavailable.');
        return;
      }
      _startLeg(
        pose: home,
        leg: _RoundTripLeg.returning,
        waitingPhase: RoundTripNavigationPhase.returnWaiting,
        message: 'Automatic return goal published once.',
      );
    });
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
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
