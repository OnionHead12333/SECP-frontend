import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

/// 群聊 / 私聊发送语音、图片时的 multipart 构造。
abstract final class CommunityMessageUpload {
  static Future<FormData> voiceFormData(File file, {int? durationMs}) async {
    final filename = _voiceFilename(file.path);
    final map = <String, dynamic>{
      'kind': 'voice',
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
        contentType: MediaType('audio', 'm4a'),
      ),
    };
    if (durationMs != null && durationMs > 0) {
      map['durationMs'] = durationMs;
      map['duration_ms'] = durationMs;
    }
    return FormData.fromMap(map);
  }

  static Future<FormData> imageFormData(File file) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    final lower = filename.toLowerCase();
    final mediaType = lower.endsWith('.png')
        ? MediaType('image', 'png')
        : lower.endsWith('.webp')
            ? MediaType('image', 'webp')
            : MediaType('image', 'jpeg');
    return FormData.fromMap({
      'kind': 'image',
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
        contentType: mediaType,
      ),
    });
  }

  static String _voiceFilename(String path) {
    final base = path.split(Platform.pathSeparator).last;
    if (base.isEmpty) return 'voice.m4a';
    if (base.contains('.')) return base;
    return '$base.m4a';
  }

  static Options get uploadOptions => Options(
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
        headers: const {'Accept': 'application/json'},
      );
}
