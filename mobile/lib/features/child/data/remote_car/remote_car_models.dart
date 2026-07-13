import 'car_encoder.dart';

enum RemoteCarCommand {
  forward('前进'),
  backward('后退'),
  left('左转'),
  right('右转'),
  stop('停止'),
  emergencyStop('紧急停止');

  const RemoteCarCommand(this.label);

  final String label;

  CarDirection get tcpDirection {
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
    }
  }
}
