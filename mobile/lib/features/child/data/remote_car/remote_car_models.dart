import 'car_encoder.dart';

enum RemoteCarMode {
  ros2Gateway,
  tcpDirect,
}

enum RemoteCarCommand {
  forward('forward', '前进'),
  backward('backward', '后退'),
  left('left', '左转'),
  right('right', '右转'),
  stop('stop', '停止'),
  emergencyStop('emergency_stop', '紧急停止'),
  resetEmergency('reset_emergency', '解除急停');

  const RemoteCarCommand(this.gatewayValue, this.label);

  final String gatewayValue;
  final String label;

  CarDirection? get tcpDirection {
    switch (this) {
      case RemoteCarCommand.forward:
        return CarDirection.front;
      case RemoteCarCommand.backward:
        return CarDirection.back;
      case RemoteCarCommand.left:
        return CarDirection.leftRotate;
      case RemoteCarCommand.right:
        return CarDirection.rightRotate;
      case RemoteCarCommand.stop:
        return CarDirection.stop;
      case RemoteCarCommand.emergencyStop:
        return CarDirection.brake;
      case RemoteCarCommand.resetEmergency:
        return null;
    }
  }
}

class RosCarState {
  const RosCarState({
    required this.currentCmd,
    required this.fallAlert,
    required this.riskLevel,
    required this.obstacleStatus,
    required this.navigationStatus,
    required this.controlConnected,
    required this.emergencyStop,
    required this.controlBlockReason,
  });

  final String currentCmd;
  final bool fallAlert;
  final String riskLevel;
  final String obstacleStatus;
  final String navigationStatus;
  final bool controlConnected;
  final bool emergencyStop;
  final String controlBlockReason;

  factory RosCarState.fromJson(Map<String, dynamic> json) {
    return RosCarState(
      currentCmd: _asString(json['current_cmd']),
      fallAlert: _asBool(json['fall_alert']),
      riskLevel: _asString(json['risk_level']),
      obstacleStatus: _asString(json['obstacle_status']),
      navigationStatus: _asString(json['navigation_status']),
      controlConnected: _asBool(json['control_connected']),
      emergencyStop: _asBool(json['emergency_stop']),
      controlBlockReason: _asString(json['control_block_reason']),
    );
  }

  Map<String, String> get displayFields {
    return {
      'current_cmd': currentCmd,
      'fall_alert': fallAlert ? 'true' : 'false',
      'risk_level': riskLevel,
      'obstacle_status': obstacleStatus,
      'navigation_status': navigationStatus,
      'control_connected': controlConnected ? 'true' : 'false',
      'emergency_stop': emergencyStop ? 'true' : 'false',
      'control_block_reason': controlBlockReason,
    };
  }

  static String _asString(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? '-' : text;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '${value ?? ''}'.trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }
}
