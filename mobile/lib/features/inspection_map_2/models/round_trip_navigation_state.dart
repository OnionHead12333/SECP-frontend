import '../../inspection_map/models/ros_navigation_models.dart';

enum RoundTripNavigationPhase {
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

extension RoundTripNavigationPhaseLabel on RoundTripNavigationPhase {
  String get label => switch (this) {
        RoundTripNavigationPhase.idle => 'Set start and capture home',
        RoundTripNavigationPhase.homeCaptured => 'Home captured',
        RoundTripNavigationPhase.targetReady => 'Target ready',
        RoundTripNavigationPhase.outboundWaiting => 'Sending outbound goal',
        RoundTripNavigationPhase.outboundActive => 'Navigating to target',
        RoundTripNavigationPhase.outboundCooldown =>
          'Waiting to return automatically',
        RoundTripNavigationPhase.returnWaiting => 'Sending automatic return',
        RoundTripNavigationPhase.returnActive => 'Returning home',
        RoundTripNavigationPhase.completed => 'Round trip complete',
        RoundTripNavigationPhase.stopping => 'Stopping',
        RoundTripNavigationPhase.stopped => 'Stopped',
        RoundTripNavigationPhase.failed => 'Navigation failed',
      };
}

class RoundTripNavigationState {
  const RoundTripNavigationState({
    required this.phase,
    required this.latestPose,
    required this.home,
    required this.target,
    required this.activeGoalId,
    required this.message,
  });

  const RoundTripNavigationState.initial()
      : phase = RoundTripNavigationPhase.idle,
        latestPose = null,
        home = null,
        target = null,
        activeGoalId = null,
        message = null;

  final RoundTripNavigationPhase phase;
  final RosPose2D? latestPose;
  final RosPose2D? home;
  final RosPose2D? target;
  final String? activeGoalId;
  final String? message;

  bool get isBusy => switch (phase) {
        RoundTripNavigationPhase.outboundWaiting ||
        RoundTripNavigationPhase.outboundActive ||
        RoundTripNavigationPhase.outboundCooldown ||
        RoundTripNavigationPhase.returnWaiting ||
        RoundTripNavigationPhase.returnActive ||
        RoundTripNavigationPhase.stopping =>
          true,
        _ => false,
      };

  bool get canStartOutbound =>
      phase == RoundTripNavigationPhase.targetReady &&
      home != null &&
      target != null;

  bool get canStop => switch (phase) {
        RoundTripNavigationPhase.outboundWaiting ||
        RoundTripNavigationPhase.outboundActive ||
        RoundTripNavigationPhase.outboundCooldown ||
        RoundTripNavigationPhase.returnWaiting ||
        RoundTripNavigationPhase.returnActive =>
          true,
        _ => false,
      };
}
