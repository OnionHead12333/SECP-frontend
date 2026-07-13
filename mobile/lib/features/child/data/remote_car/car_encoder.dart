enum CarDirection {
  stop(0),
  front(1),
  back(2),
  left(3),
  right(4),
  leftRotate(5),
  rightRotate(6),
  brake(7);

  const CarDirection(this.value);

  final int value;
}

class CarEncoder {
  const CarEncoder._();

  static String button(CarDirection direction) {
    return _base('15', [_hex(direction.value)]);
  }

  static String rocker(num x, num y) {
    return _base('10', [_signedHex(x), _signedHex(y)]);
  }

  static String wheelSpeeds(
    num leftFront,
    num leftRear,
    num rightFront,
    num rightRear,
  ) {
    return _base('21', [
      _signedHex(leftFront),
      _signedHex(leftRear),
      _signedHex(rightFront),
      _signedHex(rightRear),
    ]);
  }

  static String takePhoto() => _base('60');

  static String startRecording() => _base('61');

  static String stopRecording() => _base('62');

  static String trackingOpen() => _base('63');

  static String trackingClose() => _base('64');

  static String _base(String type, [List<String> data = const []]) {
    final info = data.join();
    final size = _hex(info.length + 2);
    var code = '01$type$size$info';
    code += _hex(_checksum(code));
    return '\$$code#';
  }

  static String _signedHex(num value) {
    var rounded = value.round();
    if (rounded < 0) {
      rounded += 256;
    }
    return _hex(rounded);
  }

  static String _hex(int value) {
    return value.toRadixString(16).padLeft(2, '0').toUpperCase();
  }

  static int _checksum(String data) {
    var calculatedChecksum = 0;
    for (var i = 0; i < data.length; i += 2) {
      final byte = int.parse(data.substring(i, i + 2), radix: 16);
      calculatedChecksum = (calculatedChecksum + byte) % 256;
    }
    return calculatedChecksum;
  }
}
