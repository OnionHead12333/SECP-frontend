import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../config/app_config.dart';

/// 讯飞语音识别（实时转写 WebSocket）的鉴权 URI 构建与帧打包。
abstract final class XfyunIatStreamHelpers {
  static Uri buildIatWsUri({
    required String host,
    required String path,
    required String apiKey,
    required String apiSecret,
  }) {
    final date = HttpDate.format(DateTime.now().toUtc());
    final signatureOrigin = 'host: $host\ndate: $date\nGET $path HTTP/1.1';
    final signature = base64Encode(
      Hmac(sha256, utf8.encode(apiSecret))
          .convert(utf8.encode(signatureOrigin))
          .bytes,
    );
    final authorizationOrigin =
        'api_key="$apiKey", algorithm="hmac-sha256", headers="host date request-line", signature="$signature"';
    final authorization = base64Encode(utf8.encode(authorizationOrigin));
    final query = [
      'authorization=${Uri.encodeComponent(authorization)}',
      'date=${Uri.encodeComponent(date)}',
      'host=${Uri.encodeComponent(host)}',
    ].join('&');
    return Uri.parse('wss://$host$path?$query');
  }

  static Uri defaultIatWsUriFromConfig() => buildIatWsUri(
        host: AppConfig.xfyunIatHost,
        path: AppConfig.xfyunIatPath,
        apiKey: AppConfig.xfyunIatApiKey,
        apiSecret: AppConfig.xfyunIatApiSecret,
      );

  static Map<String, dynamic> firstAudioFramePayload({required Uint8List chunk}) {
    return <String, dynamic>{
      'common': {'app_id': AppConfig.xfyunIatAppId},
      'business': const {
        'language': 'zh_cn',
        'domain': 'iat',
        'accent': 'mandarin',
        'vad_eos': 3000,
      },
      'data': {
        'status': 0,
        'format': 'audio/L16;rate=16000',
        'encoding': 'raw',
        'audio': base64Encode(chunk),
      },
    };
  }

  static Map<String, dynamic> continuationAudioFramePayload({required Uint8List chunk}) {
    return <String, dynamic>{
      'data': {
        'status': 1,
        'format': 'audio/L16;rate=16000',
        'encoding': 'raw',
        'audio': base64Encode(chunk),
      },
    };
  }

  static Map<String, dynamic> closingAudioPayload() {
    return <String, dynamic>{
      'data': {
        'status': 2,
        'format': 'audio/L16;rate=16000',
        'encoding': 'raw',
        'audio': '',
      },
    };
  }

  static String extractWords(Map<String, dynamic>? result) {
    if (result == null) return '';
    final buffer = StringBuffer();
    final ws = result['ws'];
    if (ws is List) {
      for (final item in ws) {
        if (item is! Map) continue;
        final cw = item['cw'];
        if (cw is! List) continue;
        for (final candidate in cw) {
          if (candidate is Map && candidate['w'] is String) {
            buffer.write(candidate['w'] as String);
          }
        }
      }
    }
    return buffer.toString();
  }
}
