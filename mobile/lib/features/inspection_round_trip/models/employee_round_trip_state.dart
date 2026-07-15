import '../../inspection_map/models/ros_navigation_models.dart';
import 'round_trip_backend_models.dart';

enum EmployeeRoundTripPhase {
  idle,
  homeCaptured,
  targetReady,
  outboundWaiting,
  outboundActive,
  outboundCooldown,
  returnWaiting,
  returnActive,
  completed,
  stopping,
  stopped,
  failed,
}

extension EmployeeRoundTripPhaseLabel on EmployeeRoundTripPhase {
  String get label => switch (this) {
        EmployeeRoundTripPhase.idle => '设置起点并记录返航点',
        EmployeeRoundTripPhase.homeCaptured => '返航点已记录',
        EmployeeRoundTripPhase.targetReady => '目标点已选择',
        EmployeeRoundTripPhase.outboundWaiting => '正在发送去程目标',
        EmployeeRoundTripPhase.outboundActive => '正在前往目标点',
        EmployeeRoundTripPhase.outboundCooldown => '即将自动返航',
        EmployeeRoundTripPhase.returnWaiting => '正在发送返航目标',
        EmployeeRoundTripPhase.returnActive => '正在返回起点',
        EmployeeRoundTripPhase.completed => '往返巡检完成',
        EmployeeRoundTripPhase.stopping => '正在停止',
        EmployeeRoundTripPhase.stopped => '已停止',
        EmployeeRoundTripPhase.failed => '导航失败',
      };
}

class EmployeeRoundTripState {
  const EmployeeRoundTripState({
    required this.commandMode,
    required this.phase,
    required this.latestPose,
    required this.home,
    required this.target,
    required this.activeGoalId,
    required this.backendTaskId,
    required this.outboundGoalId,
    required this.returnGoalId,
    required this.backendStatus,
    required this.commandPending,
    required this.message,
  });

  final RoundTripCommandMode commandMode;
  final EmployeeRoundTripPhase phase;
  final RosPose2D? latestPose;
  final RosPose2D? home;
  final RosPose2D? target;
  final String? activeGoalId;
  final String? backendTaskId;
  final String? outboundGoalId;
  final String? returnGoalId;
  final String? backendStatus;
  final bool commandPending;
  final String? message;

  bool get isBusy => switch (phase) {
        EmployeeRoundTripPhase.outboundWaiting ||
        EmployeeRoundTripPhase.outboundActive ||
        EmployeeRoundTripPhase.outboundCooldown ||
        EmployeeRoundTripPhase.returnWaiting ||
        EmployeeRoundTripPhase.returnActive ||
        EmployeeRoundTripPhase.stopping =>
          true,
        _ => false,
      };

  bool get canStartOutbound =>
      !commandPending &&
      phase == EmployeeRoundTripPhase.targetReady &&
      home != null &&
      target != null;

  bool get canStop {
    if (commandPending && backendTaskId == null) return false;
    if (commandMode == RoundTripCommandMode.backendMediated &&
        backendTaskId == null) {
      return false;
    }
    return switch (phase) {
      EmployeeRoundTripPhase.outboundWaiting ||
      EmployeeRoundTripPhase.outboundActive ||
      EmployeeRoundTripPhase.outboundCooldown ||
      EmployeeRoundTripPhase.returnWaiting ||
      EmployeeRoundTripPhase.returnActive =>
        true,
      _ => false,
    };
  }
}
