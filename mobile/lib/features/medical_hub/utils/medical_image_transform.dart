import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 在 isolate 中旋转 JPEG/PNG 字节，避免大图阻塞 UI。
Future<Uint8List> rotateImageBytes(Uint8List input, {required bool clockwise}) {
  return compute(_rotateImageBytesIsolate, _RotateArgs(input, clockwise));
}

class _RotateArgs {
  const _RotateArgs(this.bytes, this.clockwise);
  final Uint8List bytes;
  final bool clockwise;
}

Uint8List _rotateImageBytesIsolate(_RotateArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) {
    throw Exception('无法解析图片');
  }
  final angle = args.clockwise ? 90 : -90;
  final rotated = img.copyRotate(decoded, angle: angle);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
}
