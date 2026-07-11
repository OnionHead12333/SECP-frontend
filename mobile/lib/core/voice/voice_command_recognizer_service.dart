import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import 'xfyun_iat_stream_helpers.dart';
import 'voice_command_models.dart';

class VoiceCommandRecognizerService {
  VoiceCommandRecognizerService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  StreamSubscription<Uint8List>? _recordSub;
  StreamSubscription<dynamic>? _resultSub;
  WebSocketChannel? _channel;
  Completer<VoiceRecognitionResult>? _sessionCompleter;
  void Function(String)? _onTranscript;
  Timer? _mockTimer;

  String _transcript = '';
  bool _isListening = false;
  bool _closed = false;
  int _frameStatus = 0;

  bool get isListening => _isListening;

  Future<VoiceRecognitionResult> listenOnce({
    required void Function(String) onTranscript,
  }) async {
    if (_sessionCompleter != null) {
      throw StateError('已有进行中的语音识别任务');
    }
    _sessionCompleter = Completer<VoiceRecognitionResult>();
    _onTranscript = onTranscript;
    _transcript = '';
    _isListening = true;

    if (AppConfig.useMockStt) {
      _mockTimer = Timer(const Duration(milliseconds: 900), () {
        _mergeTranscript('停止');
        _completeSuccess(
          VoiceRecognitionResult(transcript: _transcript, usedMock: true),
        );
      });
      return _sessionCompleter!.future.whenComplete(_resetSessionState);
    }

    if (!_hasXfyunConfig) {
      _completeError('语音识别不可用：讯飞配置缺失');
      return _sessionCompleter!.future.whenComplete(_resetSessionState);
    }

    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        _completeError('语音识别不可用：麦克风权限未开启');
        return _sessionCompleter!.future.whenComplete(_resetSessionState);
      }
      final recorderPermission = await _recorder.hasPermission();
      if (!recorderPermission) {
        _completeError('语音识别不可用：麦克风权限未开启');
        return _sessionCompleter!.future.whenComplete(_resetSessionState);
      }

      final uri = XfyunIatStreamHelpers.defaultIatWsUriFromConfig();
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _closed = false;
      _frameStatus = 0;
      _resultSub = channel.stream.listen(
        _handleMessage,
        onError: (Object error) {
          _completeError(_friendlyStartError(error));
        },
        onDone: () {
          if (_sessionCompleter?.isCompleted == false) {
            _completeSuccess(
              VoiceRecognitionResult(
                transcript: _transcript,
                usedMock: false,
              ),
            );
          }
        },
      );
      await channel.ready.timeout(const Duration(seconds: 6));
      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          streamBufferSize: 1280,
        ),
      );
      _recordSub = audioStream.listen(
        _sendAudioChunk,
        onError: (Object error) {
          _completeError('录音流异常：$error');
        },
      );
    } catch (error) {
      _completeError(_friendlyStartError(error));
    }

    return _sessionCompleter!.future.whenComplete(_resetSessionState);
  }

  Future<void> stop() async {
    if (_sessionCompleter == null) return;
    _mockTimer?.cancel();
    _mockTimer = null;
    if (_channel != null && !_closed) {
      _channel!.sink.add(
        jsonEncode(XfyunIatStreamHelpers.closingAudioPayload()),
      );
      _closed = true;
    }
    await _cleanupTransport();
    _completeSuccess(
      VoiceRecognitionResult(
        transcript: _transcript,
        usedMock: AppConfig.useMockStt,
      ),
    );
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }

  bool get _hasXfyunConfig =>
      AppConfig.xfyunIatAppId.isNotEmpty &&
      AppConfig.xfyunIatApiKey.isNotEmpty &&
      AppConfig.xfyunIatApiSecret.isNotEmpty;

  void _sendAudioChunk(Uint8List chunk) {
    final channel = _channel;
    if (channel == null || _closed || chunk.isEmpty) return;
    final frame = _frameStatus == 0
        ? XfyunIatStreamHelpers.firstAudioFramePayload(chunk: chunk)
        : XfyunIatStreamHelpers.continuationAudioFramePayload(chunk: chunk);
    channel.sink.add(jsonEncode(frame));
    _frameStatus = 1;
  }

  void _handleMessage(dynamic message) {
    if (message is! String) return;
    try {
      final payload = jsonDecode(message) as Map<String, dynamic>;
      final codeValue = payload['code'];
      final code =
          codeValue is int ? codeValue : int.tryParse('$codeValue') ?? -1;
      if (code != 0) {
        _completeError('讯飞识别错误：$code');
        return;
      }
      final data = payload['data'] as Map<String, dynamic>?;
      final result = data?['result'] as Map<String, dynamic>?;
      final words = XfyunIatStreamHelpers.extractWords(result);
      if (words.isNotEmpty) {
        _mergeTranscript(words);
      }
      if (data?['status'] == 2) {
        unawaited(_cleanupTransport());
        _completeSuccess(
          VoiceRecognitionResult(transcript: _transcript, usedMock: false),
        );
      }
    } catch (error) {
      _completeError('语音结果解析失败：$error');
    }
  }

  void _mergeTranscript(String latestChunk) {
    final chunk = latestChunk.trim();
    if (chunk.isEmpty) return;
    if (_transcript.isEmpty) {
      _transcript = chunk;
    } else if (chunk.contains(_transcript)) {
      _transcript = chunk;
    } else if (_transcript.contains(chunk)) {
      // Keep the longer transcript.
    } else {
      _transcript += chunk;
    }
    _onTranscript?.call(_transcript);
  }

  void _completeSuccess(VoiceRecognitionResult result) {
    final completer = _sessionCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(result);
    unawaited(_cleanupTransport());
  }

  void _completeError(String message) {
    final completer = _sessionCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.completeError(Exception(message));
    unawaited(_cleanupTransport());
  }

  Future<void> _cleanupTransport() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    await _recordSub?.cancel().catchError((_) {});
    _recordSub = null;
    final recording = await _recorder.isRecording().catchError((_) => false);
    if (recording) {
      await _recorder.stop().catchError((_) => null);
    }
    await _resultSub?.cancel().catchError((_) {});
    _resultSub = null;
    await _channel?.sink.close(ws_status.normalClosure).catchError((_) {});
    _channel = null;
    _closed = true;
  }

  void _resetSessionState() {
    _sessionCompleter = null;
    _onTranscript = null;
    _isListening = false;
    _closed = true;
    _frameStatus = 0;
  }

  String _friendlyStartError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return '语音识别不可用：讯飞连接超时';
    }
    if (lower.contains('permission')) {
      return '语音识别不可用：麦克风权限未开启';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused')) {
      return '语音识别不可用：无法连接讯飞服务，请检查外网';
    }
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return '语音识别不可用：讯飞鉴权失败';
    }
    return '语音识别启动失败：$raw';
  }
}
