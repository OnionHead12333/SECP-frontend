import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/config/app_config.dart';
import '../data/elder_help_service.dart';
import '../models/elder_help_request.dart';

enum _SosSheetResult { revoke, sendNow, timeout }

enum _VoiceWithdrawPhase { speaking, listening, unavailable, submitting }

void _sosLog(String message) {
  debugPrint('[SOS] ${DateTime.now().toIso8601String()} $message');
}

class ElderGlobalSosOverlay extends StatefulWidget {
  const ElderGlobalSosOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<ElderGlobalSosOverlay> createState() => _ElderGlobalSosOverlayState();
}

class _ElderGlobalSosOverlayState extends State<ElderGlobalSosOverlay> {
  static const int _fallbackRevokeSeconds = 10;

  Timer? _sessionWatcher;
  AppRole? _lastRole;
  bool _busy = false;
  int? _currentAlertId;

  bool get _shouldShowSos =>
      AuthSession.isLoggedIn && AuthSession.role == AppRole.elder;

  @override
  void initState() {
    super.initState();
    _lastRole = AuthSession.role;
    _sessionWatcher = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (_lastRole != AuthSession.role) {
        setState(() => _lastRole = AuthSession.role);
      }
    });
  }

  @override
  void dispose() {
    _sessionWatcher?.cancel();
    super.dispose();
  }

  Future<void> _handleSosTap() async {
    if (_busy) {
      _sosLog('tap ignored: overlay busy');
      return;
    }
    setState(() => _busy = true);
    _sosLog(
      'tap: createHelpRequest start apiBase=${AppConfig.apiBase} useMockSos=${AppConfig.useMockSos} token=${AuthSession.token == null ? 'null' : 'present'}',
    );
    try {
      final request = await ElderHelpService.createHelpRequest();
      if (!mounted) return;
      _currentAlertId = request.alertId;
      _sosLog(
        'createHelpRequest success alertId=${request.alertId} status=${request.status} serverTime=${request.serverTime} revokeDeadline=${request.revokeDeadline}',
      );
      final navigatorContext = widget.navigatorKey.currentContext;
      if (navigatorContext == null) {
        _sosLog('show sheet aborted: navigatorContext is null');
        _showMessage('当前页面还未准备好，请稍后再试');
        return;
      }
      if (!navigatorContext.mounted) {
        _sosLog('show sheet aborted: navigatorContext not mounted');
        return;
      }
      final seconds = _resolveSeconds(request);
      _sosLog('show sheet start alertId=$_currentAlertId seconds=$seconds');
      final result = await showModalBottomSheet<_SosSheetResult>(
        context: navigatorContext,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => _GlobalSosCountdownSheet(
          alertId: _currentAlertId!,
          seconds: seconds,
        ),
      );
      _sosLog('sheet closed result=$result alertId=$_currentAlertId');
      if (!mounted || _currentAlertId == null) return;
      switch (result) {
        case _SosSheetResult.revoke:
          _showMessage('老人已确认撤回，本次求助已取消');
          break;
        case _SosSheetResult.sendNow:
          _showMessage('求助已立即发送到子女端');
          break;
        case _SosSheetResult.timeout:
        case null:
          _sosLog(
              'sheet result timeout/null: get status start alertId=$_currentAlertId');
          final current = await ElderHelpService.getHelpRequestStatus(
              alertId: _currentAlertId!);
          _sosLog(
              'get status success alertId=${current.alertId} status=${current.status}');
          if (!mounted) return;
          if (current.status == 'sent' ||
              current.status == 'handled' ||
              current.status == 'false_alarm') {
            _showMessage('撤回时间结束，求助已发送到子女端');
          }
          break;
      }
    } catch (e) {
      _sosLog('tap flow error: $e');
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _sosLog('tap flow finish');
      if (mounted) setState(() => _busy = false);
    }
  }

  int _resolveSeconds(ElderHelpRequest request) {
    final deadline = request.revokeDeadline;
    final reference = request.serverTime ?? DateTime.now();
    if (deadline == null) return _fallbackRevokeSeconds;
    final seconds = deadline.difference(reference).inSeconds;
    return seconds <= 0 ? 1 : seconds;
  }

  void _showMessage(String message) {
    try {
      widget.scaffoldMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      debugPrint(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_shouldShowSos)
          Positioned(
            top: media.padding.top + 64,
            right: 16,
            child: SafeArea(
              child: _GlobalSosButton(
                busy: _busy,
                onTap: _busy ? null : _handleSosTap,
              ),
            ),
          ),
      ],
    );
  }
}

class _GlobalSosButton extends StatelessWidget {
  const _GlobalSosButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEF2F2),
      shape: const CircleBorder(),
      elevation: 10,
      shadowColor: const Color(0xFF991B1B).withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEF4444), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Color(0xFFDC2626)),
                )
              else
                const Icon(Icons.sos_outlined,
                    color: Color(0xFFDC2626), size: 26),
              const SizedBox(height: 5),
              const Text(
                '紧急\n求助',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF991B1B),
                    height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalSosCountdownSheet extends StatefulWidget {
  const _GlobalSosCountdownSheet({
    required this.alertId,
    required this.seconds,
  });

  final int alertId;
  final int seconds;

  @override
  State<_GlobalSosCountdownSheet> createState() =>
      _GlobalSosCountdownSheetState();
}

class _GlobalSosCountdownSheetState extends State<_GlobalSosCountdownSheet>
    with SingleTickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();

  late final AnimationController _micPulseController;
  late int _secondsLeft;
  Timer? _countdownTimer;
  Timer? _mockSpeechTimer;
  StreamSubscription<Uint8List>? _recordSub;
  StreamSubscription<dynamic>? _xfResultSub;
  WebSocketChannel? _xfChannel;
  _VoiceWithdrawPhase _voicePhase = _VoiceWithdrawPhase.speaking;
  String? _lastRecognizedWords;
  String? _voiceUnavailableReason;
  bool _isSubmitting = false;
  bool _xfIatStartInFlight = false;
  bool _xfIatClosed = false;
  int _xfFrameStatus = 0;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.seconds;
    _sosLog('sheet init alertId=${widget.alertId} seconds=${widget.seconds}');
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.92,
      upperBound: 1.08,
    );
    _startCountdown();
    unawaited(_startVoiceWithdrawFlow());
  }

  @override
  void dispose() {
    _sosLog('sheet dispose alertId=${widget.alertId}');
    _stopCountdown();
    _stopSpeechListening();
    _mockSpeechTimer?.cancel();
    _micPulseController.dispose();
    unawaited(_tts.stop());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  void _startCountdown() {
    _sosLog('countdown start alertId=${widget.alertId} seconds=$_secondsLeft');
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _isSubmitting) return;
      if (_secondsLeft <= 1) {
        _sosLog(
            'countdown reached timeout alertId=${widget.alertId}; submit send-now');
        await _submitSendNow(_SosSheetResult.timeout);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  void _stopCountdown() {
    if (_countdownTimer != null) {
      _sosLog(
          'countdown stop alertId=${widget.alertId} secondsLeft=$_secondsLeft');
    }
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> _startVoiceWithdrawFlow() async {
    _sosLog('voice flow start alertId=${widget.alertId}');
    await _playTtsPrompt();
    if (!mounted || _isSubmitting) return;
    await _startSpeechListening();
  }

  Future<void> _playTtsPrompt() async {
    try {
      _sosLog('tts start alertId=${widget.alertId}');
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.42);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak('误触请说撤回');
      _sosLog('tts completed alertId=${widget.alertId}');
    } catch (_) {
      _sosLog('tts failed; fallback delay alertId=${widget.alertId}');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
  }

  bool _containsWithdrawKeyword(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    return normalized.contains('撤回') ||
        normalized.contains('撤了') ||
        normalized.contains('撤销') ||
        normalized.contains('取消求助') ||
        normalized.contains('取消') ||
        normalized.contains('不要发送') ||
        normalized.contains('不用发送') ||
        normalized.contains('别发送') ||
        normalized.contains('不要发') ||
        normalized.contains('不用发') ||
        normalized.contains('别发') ||
        normalized.contains('误触') ||
        normalized.contains('车回') ||
        normalized.contains('策回');
  }

  void _stopSpeechListening() {
    _sosLog('xfyun stop requested alertId=${widget.alertId}');
    unawaited(_stopXfyunIat(sendFinalFrame: false));
    _micPulseController.stop();
  }

  Future<void> _startSpeechListening() async {
    if (AppConfig.useMockStt) {
      _startMockSpeechListening();
      return;
    }
    if (_xfIatStartInFlight || _xfChannel != null) {
      _sosLog('xfyun start skipped: already active alertId=${widget.alertId}');
      return;
    }
    _xfIatStartInFlight = true;
    try {
      if (!_hasXfyunConfig) {
        _setVoiceUnavailable('讯飞配置缺失');
        return;
      }
      final permissionStatus = await Permission.microphone.request();
      _sosLog(
          'microphone permission alertId=${widget.alertId} status=$permissionStatus');
      if (!mounted || _isSubmitting) return;
      if (!permissionStatus.isGranted) {
        _setVoiceUnavailable('麦克风权限未开启');
        return;
      }
      final hasPermission = await _recorder.hasPermission();
      _sosLog(
          'record permission alertId=${widget.alertId} granted=$hasPermission');
      if (!mounted || _isSubmitting) return;
      if (!hasPermission) {
        _setVoiceUnavailable('麦克风权限未开启');
        return;
      }
      final uri = _buildXfyunIatUri();
      final channel = WebSocketChannel.connect(uri);
      _xfChannel = channel;
      _xfIatClosed = false;
      _xfFrameStatus = 0;
      _sosLog(
          'xfyun websocket connect alertId=${widget.alertId} host=${uri.host}');
      _xfResultSub = channel.stream.listen(
        _handleXfyunMessage,
        onError: (error) {
          _sosLog('xfyun websocket error alertId=${widget.alertId}: $error');
          if (mounted && !_isSubmitting) _setVoiceUnavailable('讯飞连接异常');
        },
        onDone: () {
          _sosLog('xfyun websocket done alertId=${widget.alertId}');
          _xfChannel = null;
        },
      );
      await channel.ready.timeout(const Duration(seconds: 6));
      _sosLog('xfyun websocket ready alertId=${widget.alertId}');
      if (!mounted || _isSubmitting || _xfChannel == null) return;
      setState(() {
        _voicePhase = _VoiceWithdrawPhase.listening;
        _lastRecognizedWords = null;
        _voiceUnavailableReason = null;
      });
      _micPulseController.repeat(reverse: true);
      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          streamBufferSize: 1280,
        ),
      );
      _sosLog('xfyun record stream start alertId=${widget.alertId}');
      _recordSub = audioStream.listen(
        _sendXfyunAudioChunk,
        onError: (error) {
          _sosLog('record stream error alertId=${widget.alertId}: $error');
          if (mounted && !_isSubmitting) _setVoiceUnavailable('录音流异常');
        },
        onDone: () => _sosLog('record stream done alertId=${widget.alertId}'),
      );
    } catch (e, st) {
      _sosLog('xfyun initialize/listen failed alertId=${widget.alertId}: $e');
      debugPrintStack(stackTrace: st);
      await _stopXfyunIat(sendFinalFrame: false);
      if (!mounted || _isSubmitting) return;
      _setVoiceUnavailable(_friendlyXfyunStartError(e));
    } finally {
      _xfIatStartInFlight = false;
    }
  }

  void _startMockSpeechListening() {
    _sosLog('mock STT listen start alertId=${widget.alertId}');
    if (!mounted || _isSubmitting) return;
    setState(() {
      _voicePhase = _VoiceWithdrawPhase.listening;
      _lastRecognizedWords = null;
      _voiceUnavailableReason = null;
    });
    _micPulseController.repeat(reverse: true);
    _mockSpeechTimer?.cancel();
    _mockSpeechTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted ||
          _isSubmitting ||
          _voicePhase != _VoiceWithdrawPhase.listening) {
        return;
      }
      _handleRecognizedWords('撤回', finalResult: true);
    });
  }

  void _setVoiceUnavailable(String reason) {
    _sosLog('speech unavailable alertId=${widget.alertId} reason=$reason');
    if (!mounted) return;
    setState(() {
      _voicePhase = _VoiceWithdrawPhase.unavailable;
      _voiceUnavailableReason = reason;
    });
    unawaited(_stopXfyunIat(sendFinalFrame: false));
    _micPulseController.stop();
  }

  Future<void> _openPermissionSettings() async {
    _sosLog(
        'open app settings for microphone permission alertId=${widget.alertId}');
    await openAppSettings();
  }

  bool get _hasXfyunConfig =>
      AppConfig.xfyunIatAppId.isNotEmpty &&
      AppConfig.xfyunIatApiKey.isNotEmpty &&
      AppConfig.xfyunIatApiSecret.isNotEmpty;

  String _friendlyXfyunStartError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('not upgraded') ||
        lower.contains('handshakeexception')) {
      return '讯飞鉴权失败，请检查 APIKey/APISecret 或应用权限';
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return '讯飞连接超时，请检查手机网络';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('software caused connection abort')) {
      return '无法连接讯飞服务，请检查外网';
    }
    if (lower.contains('permission')) {
      return '麦克风权限未开启';
    }
    if (lower.contains('encoder') ||
        lower.contains('recorder') ||
        lower.contains('record')) {
      return '录音启动失败，请检查麦克风';
    }
    return '讯飞语音启动失败：$raw';
  }

  Uri _buildXfyunIatUri() {
    final host = AppConfig.xfyunIatHost;
    final path = AppConfig.xfyunIatPath;
    final date = HttpDate.format(DateTime.now().toUtc());
    final signatureOrigin = 'host: $host\ndate: $date\nGET $path HTTP/1.1';
    final signature = base64Encode(
      Hmac(sha256, utf8.encode(AppConfig.xfyunIatApiSecret))
          .convert(utf8.encode(signatureOrigin))
          .bytes,
    );
    final authorizationOrigin =
        'api_key="${AppConfig.xfyunIatApiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="$signature"';
    final authorization = base64Encode(utf8.encode(authorizationOrigin));
    final query = [
      'authorization=${Uri.encodeComponent(authorization)}',
      'date=${Uri.encodeComponent(date)}',
      'host=${Uri.encodeComponent(host)}',
    ].join('&');
    return Uri.parse('wss://$host$path?$query');
  }

  void _sendXfyunAudioChunk(Uint8List chunk) {
    final channel = _xfChannel;
    if (channel == null || _xfIatClosed || _isSubmitting || chunk.isEmpty) {
      return;
    }
    final status = _xfFrameStatus == 0 ? 0 : 1;
    final frame = <String, dynamic>{
      if (status == 0) 'common': {'app_id': AppConfig.xfyunIatAppId},
      if (status == 0)
        'business': {
          'language': 'zh_cn',
          'domain': 'iat',
          'accent': 'mandarin',
          'vad_eos': 3000,
        },
      'data': {
        'status': status,
        'format': 'audio/L16;rate=16000',
        'encoding': 'raw',
        'audio': base64Encode(chunk),
      },
    };
    channel.sink.add(jsonEncode(frame));
    _xfFrameStatus = 1;
  }

  void _sendXfyunFinalFrame() {
    final channel = _xfChannel;
    if (channel == null || _xfIatClosed) return;
    channel.sink.add(jsonEncode({
      'data': {
        'status': 2,
        'format': 'audio/L16;rate=16000',
        'encoding': 'raw',
        'audio': '',
      },
    }));
    _xfIatClosed = true;
    _sosLog('xfyun final frame sent alertId=${widget.alertId}');
  }

  void _handleXfyunMessage(dynamic message) {
    if (_isSubmitting) return;
    try {
      if (message is! String) {
        _sosLog(
            'xfyun non-text frame ignored alertId=${widget.alertId} type=${message.runtimeType}');
        return;
      }
      final payload = jsonDecode(message) as Map<String, dynamic>;
      final codeValue = payload['code'];
      if (codeValue == null) {
        _sosLog(
            'xfyun result missing code alertId=${widget.alertId} raw=$message');
        return;
      }
      final code =
          codeValue is int ? codeValue : int.tryParse('$codeValue') ?? -1;
      if (code != 0) {
        _sosLog(
            'xfyun result error alertId=${widget.alertId} code=$code message=${payload['message']} raw=$message');
        _setVoiceUnavailable('讯飞识别错误：$code');
        return;
      }
      final data = payload['data'] as Map<String, dynamic>?;
      final result = data?['result'] as Map<String, dynamic>?;
      final words = _extractXfyunWords(result);
      if (words.isNotEmpty) {
        _handleRecognizedWords(words, finalResult: data?['status'] == 2);
      }
      if (data?['status'] == 2) {
        _sosLog('xfyun result final alertId=${widget.alertId}');
        unawaited(_stopXfyunIat(sendFinalFrame: false));
      }
    } catch (e) {
      _sosLog(
          'xfyun result parse failed alertId=${widget.alertId}: $e raw=$message');
    }
  }

  String _extractXfyunWords(Map<String, dynamic>? result) {
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

  Future<void> _stopXfyunIat({required bool sendFinalFrame}) async {
    _mockSpeechTimer?.cancel();
    _mockSpeechTimer = null;
    await _recordSub?.cancel().catchError((_) {});
    _recordSub = null;
    final recording = await _recorder.isRecording().catchError((_) => false);
    if (recording) {
      await _recorder.stop().catchError((_) => null);
    }
    if (sendFinalFrame) _sendXfyunFinalFrame();
    await _xfResultSub?.cancel().catchError((_) {});
    _xfResultSub = null;
    await _xfChannel?.sink.close(ws_status.normalClosure).catchError((_) {});
    _xfChannel = null;
  }

  void _handleRecognizedWords(String words, {required bool finalResult}) {
    if (_isSubmitting) return;
    if (words.isNotEmpty) {
      _sosLog(
        'speech recognized alertId=${widget.alertId} final=$finalResult words="$words"',
      );
      if (mounted) {
        setState(() => _lastRecognizedWords = words);
      }
    }
    final matched = _containsWithdrawKeyword(words);
    _sosLog(
        'speech keyword check alertId=${widget.alertId} matched=$matched words="$words"');
    if (!matched) return;
    _sosLog(
        'speech keyword matched; submit voice revoke alertId=${widget.alertId}');
    unawaited(_stopXfyunIat(sendFinalFrame: false));
    unawaited(_submitRevoke(cancelMode: 'voice'));
  }

  Future<void> _submitRevoke({required String cancelMode}) async {
    if (_isSubmitting) {
      _sosLog(
          'revoke ignored: already submitting alertId=${widget.alertId} mode=$cancelMode');
      return;
    }
    _isSubmitting = true;
    _sosLog('revoke submit start alertId=${widget.alertId} mode=$cancelMode');
    if (mounted) setState(() => _voicePhase = _VoiceWithdrawPhase.submitting);
    _stopCountdown();
    _stopSpeechListening();
    await _tts.stop();
    try {
      await ElderHelpService.revokeHelpRequest(
          alertId: widget.alertId, cancelMode: cancelMode);
      _sosLog(
          'revoke submit success alertId=${widget.alertId} mode=$cancelMode');
      if (mounted) Navigator.of(context).pop(_SosSheetResult.revoke);
    } catch (e) {
      _sosLog(
          'revoke submit failed alertId=${widget.alertId} mode=$cancelMode error=$e');
      _isSubmitting = false;
      if (!mounted) return;
      setState(() => _voicePhase = _VoiceWithdrawPhase.listening);
      _startCountdown();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(_friendlySubmitError('撤回', e))),
      );
      unawaited(_startSpeechListening());
    }
  }

  Future<void> _submitSendNow(_SosSheetResult result) async {
    if (_isSubmitting) {
      _sosLog(
          'send-now ignored: already submitting alertId=${widget.alertId} result=$result');
      return;
    }
    _isSubmitting = true;
    _sosLog('send-now submit start alertId=${widget.alertId} result=$result');
    if (mounted) setState(() => _voicePhase = _VoiceWithdrawPhase.submitting);
    _stopCountdown();
    _stopSpeechListening();
    await _tts.stop();
    try {
      await ElderHelpService.sendNow(alertId: widget.alertId);
      _sosLog(
          'send-now submit success alertId=${widget.alertId} result=$result');
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      _sosLog(
          'send-now submit failed alertId=${widget.alertId} result=$result error=$e');
      _isSubmitting = false;
      if (!mounted) return;
      setState(() => _voicePhase = _VoiceWithdrawPhase.listening);
      _startCountdown();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(_friendlySubmitError('发送', e))),
      );
      unawaited(_startSpeechListening());
    }
  }

  String _friendlySubmitError(String action, Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();
    if (lower.contains('connection timeout') ||
        lower.contains('receivetimeout') ||
        lower.contains('sendtimeout') ||
        lower.contains('connecttimeout') ||
        lower.contains('timed out')) {
      return '$action失败：连接后端超时，请检查手机和电脑网络';
    }
    if (lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable')) {
      return '$action失败：无法连接后端，请检查 API 地址和防火墙';
    }
    return '$action失败：$raw';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('求助已发起，$_secondsLeft 秒内可撤回',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('倒计时结束后，系统将自动发送给子女端。',
                style: TextStyle(
                    fontSize: 16, color: Color(0xFF475569), height: 1.6)),
            const SizedBox(height: 14),
            _VoiceWithdrawStatusRow(
              phase: _voicePhase,
              recognizedWords: _lastRecognizedWords,
              unavailableReason: _voiceUnavailableReason,
              onOpenSettings: _voiceUnavailableReason == '麦克风权限未开启'
                  ? _openPermissionSettings
                  : null,
              pulseAnimation: _micPulseController,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _secondsLeft / widget.seconds,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFDC2626)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => unawaited(_submitRevoke(cancelMode: 'button')),
                    child: const Text('确认撤回'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : () =>
                            unawaited(_submitSendNow(_SosSheetResult.sendNow)),
                    child: const Text('立即发送'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceWithdrawStatusRow extends StatelessWidget {
  const _VoiceWithdrawStatusRow({
    required this.phase,
    required this.recognizedWords,
    required this.unavailableReason,
    required this.onOpenSettings,
    required this.pulseAnimation,
  });

  final _VoiceWithdrawPhase phase;
  final String? recognizedWords;
  final String? unavailableReason;
  final VoidCallback? onOpenSettings;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final listening = phase == _VoiceWithdrawPhase.listening;
    final submitting = phase == _VoiceWithdrawPhase.submitting;
    final iconColor =
        listening ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);
    final label = switch (phase) {
      _VoiceWithdrawPhase.speaking => '系统播报中...',
      _VoiceWithdrawPhase.listening => '您可以直接说“撤回”',
      _VoiceWithdrawPhase.unavailable => unavailableReason == null
          ? '语音撤回不可用，请使用按钮撤回'
          : '语音撤回不可用：$unavailableReason',
      _VoiceWithdrawPhase.submitting => '正在处理请求...',
    };

    final icon = Icon(
      submitting ? Icons.hourglass_top_rounded : Icons.mic_rounded,
      color: iconColor,
      size: 22,
    );

    final content = Row(
      children: [
        AnimatedBuilder(
          animation: pulseAnimation,
          child: icon,
          builder: (context, child) {
            final scale = listening ? pulseAnimation.value : 1.0;
            final opacity = listening
                ? ((pulseAnimation.value - 0.92) / 0.16 * 0.45 + 0.55)
                : 0.55;
            return Transform.scale(
              scale: scale,
              child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0).toDouble(), child: child),
            );
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            recognizedWords == null || recognizedWords!.isEmpty
                ? label
                : '$label（识别到：$recognizedWords）',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color:
                  listening ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
    if (onOpenSettings == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onOpenSettings,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}
