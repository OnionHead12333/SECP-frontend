import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/voice/voice_command_api.dart';
import '../../../core/voice/voice_command_matcher.dart';
import '../../../core/voice/voice_command_models.dart';
import '../../../core/voice/voice_command_recognizer_service.dart';
import '../data/elder_help_service.dart';

class ElderVoiceControlPage extends StatefulWidget {
  const ElderVoiceControlPage({
    super.key,
    this.recognizerService,
    this.executeMatchOverride,
  });

  final VoiceCommandRecognizerService? recognizerService;
  final Future<VoiceCommandMatch> Function(VoiceCommandMatch match)?
      executeMatchOverride;

  @override
  State<ElderVoiceControlPage> createState() => _ElderVoiceControlPageState();
}

class _ElderVoiceControlPageState extends State<ElderVoiceControlPage> {
  static const int _historyLimit = 8;

  late final VoiceCommandRecognizerService _recognizer;
  late final bool _ownsRecognizer;

  bool _listening = false;
  bool _executing = false;
  String _liveTranscript = '';
  VoiceCommandMatch? _latestMatch;
  final List<VoiceCommandMatch> _history = <VoiceCommandMatch>[];

  @override
  void initState() {
    super.initState();
    _ownsRecognizer = widget.recognizerService == null;
    _recognizer = widget.recognizerService ?? VoiceCommandRecognizerService();
  }

  @override
  void dispose() {
    if (_ownsRecognizer) {
      unawaited(_recognizer.dispose());
    }
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _recognizer.stop();
      return;
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    setState(() {
      _listening = true;
      _liveTranscript = '';
      _latestMatch = null;
    });
    try {
      final result = await _recognizer.listenOnce(
        onTranscript: (String transcript) {
          if (!mounted) return;
          setState(() => _liveTranscript = transcript);
        },
      );
      if (!mounted) return;
      final match = VoiceCommandMatcher.match(
        result.transcript,
        usedMockRecognition: result.usedMock,
      );
      setState(() {
        _listening = false;
        _latestMatch = match;
      });
      await _handleMatch(match);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _latestMatch = VoiceCommandMatch(
          rawText: _liveTranscript,
          recognizedAt: DateTime.now(),
          status: VoiceCommandExecutionStatus.failed,
          detailMessage: error.toString().replaceFirst('Exception: ', ''),
        );
      });
    }
  }

  Future<void> _handleMatch(VoiceCommandMatch match) async {
    if (!match.isMatched) {
      _pushHistory(match);
      return;
    }
    setState(() {
      _executing = true;
      _latestMatch = match.copyWith(
        status: VoiceCommandExecutionStatus.submitted,
        detailMessage: '正在处理语音命令...',
      );
    });
    final executed = widget.executeMatchOverride != null
        ? await widget.executeMatchOverride!(match)
        : await _executeMatch(match);
    if (!mounted) return;
    setState(() {
      _executing = false;
      _latestMatch = executed;
    });
    _pushHistory(executed);
  }

  Future<VoiceCommandMatch> _executeMatch(VoiceCommandMatch match) async {
    if (!match.isMatched || match.commandType == null) {
      return match.copyWith(
        status: VoiceCommandExecutionStatus.unmatched,
        detailMessage: '未匹配到标准命令',
      );
    }
    if (match.commandType == VoiceCommandType.help) {
      try {
        await ElderHelpService.createHelpRequest(triggerMode: 'voice');
        final status = AppConfig.useMockSos
            ? VoiceCommandExecutionStatus.mockOnly
            : VoiceCommandExecutionStatus.executed;
        return match.copyWith(
          status: status,
          detailMessage: AppConfig.useMockSos ? '已通过 Mock 发起求助' : '已发起紧急求助',
        );
      } catch (error) {
        return match.copyWith(
          status: VoiceCommandExecutionStatus.failed,
          detailMessage: error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }

    final submitResult = await VoiceCommandApi.submit(
      text: match.rawText,
      commandType: match.commandType!,
      confidence: match.confidence,
    );
    return match.copyWith(
      status: submitResult.status,
      detailMessage: submitResult.message,
    );
  }

  void _pushHistory(VoiceCommandMatch match) {
    setState(() {
      _history.insert(0, match);
      if (_history.length > _historyLimit) {
        _history.removeRange(_historyLimit, _history.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final match = _latestMatch;
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音控制'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '成员 B：语音命令入口',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  '把语音识别成标准命令，并优先上报后端；如果后端还没接好，也保留前端可演示闭环。',
                  style: TextStyle(color: Color(0xFF475569), height: 1.6),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    const _StatusChip(
                      label: AppConfig.useMockStt
                          ? '当前识别：Mock STT'
                          : '当前识别：讯飞实时听写',
                      color: AppConfig.useMockStt
                          ? Color(0xFF92400E)
                          : Color(0xFF1D4ED8),
                    ),
                    _StatusChip(
                      label: AppConfig.xfyunIatAppId.isEmpty
                          ? '讯飞配置：缺失'
                          : '讯飞配置：已注入',
                      color: AppConfig.xfyunIatAppId.isEmpty
                          ? const Color(0xFFB45309)
                          : const Color(0xFF166534),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '标准命令：stop / start_patrol / play_music / dance / help',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            child: Column(
              children: [
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _executing ? null : _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF8FAFC),
                      border: Border.all(
                        color: _listening
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFCBD5E1),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_listening
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF0F172A))
                              .withValues(alpha: 0.10),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _executing
                        ? const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            _listening ? Icons.stop_rounded : Icons.mic_rounded,
                            size: 54,
                            color: _listening
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF334155),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _executing
                      ? '正在执行命令...'
                      : _listening
                          ? '监听中，点一下停止'
                          : '点按开始语音命令识别',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('实时转写',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  _liveTranscript.isEmpty ? '等待语音输入...' : _liveTranscript,
                  style: TextStyle(
                    fontSize: 16,
                    color: _liveTranscript.isEmpty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0F172A),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('命中结果',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (match == null)
                  const Text(
                    '还没有本次识别结果。',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  )
                else ...[
                  _ResultRow(
                      title: '原始文本',
                      value: match.rawText.isEmpty ? '（空）' : match.rawText),
                  _ResultRow(
                    title: '标准命令',
                    value: match.isMatched
                        ? '${match.commandType!.label} (${match.commandText})'
                        : '未匹配',
                  ),
                  _ResultRow(title: '状态', value: match.status.label),
                  if (match.detailMessage != null &&
                      match.detailMessage!.isNotEmpty)
                    _ResultRow(title: '反馈', value: match.detailMessage!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('最近记录',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (_history.isEmpty)
                  const Text(
                    '暂无历史记录。',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  )
                else
                  ..._history.map(
                    (VoiceCommandMatch item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.rawText.isEmpty ? '（空）' : item.rawText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.isMatched
                                ? '${item.commandText} · ${item.status.label}'
                                : item.status.label,
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                          if (item.detailMessage != null &&
                              item.detailMessage!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.detailMessage!,
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
