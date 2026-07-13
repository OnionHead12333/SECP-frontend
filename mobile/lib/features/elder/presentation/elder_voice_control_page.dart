import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/voice/voice_command_matcher.dart';
import '../../../core/voice/voice_command_models.dart';
import '../../../core/voice/voice_command_recognizer_service.dart';
import '../data/elder_voice_command_executor.dart';

class ElderVoiceControlPage extends StatefulWidget {
  const ElderVoiceControlPage({
    super.key,
    this.recognizerService,
    this.executeOverride,
  });

  final VoiceCommandRecognizerService? recognizerService;
  final Future<VoiceCommandExecutionResult> Function(VoiceCommandMatch match)?
      executeOverride;

  @override
  State<ElderVoiceControlPage> createState() => _ElderVoiceControlPageState();
}

class _ElderVoiceControlPageState extends State<ElderVoiceControlPage> {
  static const int _historyLimit = 8;

  late final VoiceCommandRecognizerService _recognizer;
  late final bool _ownsRecognizer;

  bool _listening = false;
  bool _executing = false;
  String _recognizedText = '';
  VoiceCommandMatch? _latestMatch;
  VoiceCommandExecutionResult? _latestResult;
  final List<VoiceCommandExecutionResult> _history = [];

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
      _executing = false;
      _recognizedText = '';
      _latestMatch = null;
      _latestResult = null;
    });

    try {
      final result = await _recognizer.listenOnce(
        onTranscript: (text) {
          if (!mounted) return;
          setState(() => _recognizedText = text);
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
        _recognizedText = result.transcript;
      });
      await _execute(match);
    } catch (error) {
      if (!mounted) return;
      final now = DateTime.now();
      final failed = VoiceCommandExecutionResult(
        rawText: _recognizedText,
        standardCommand: 'unmatched',
        status: 'failed',
        feedback: error.toString().replaceFirst('Exception: ', ''),
        recognizedAt: now,
      );
      setState(() {
        _listening = false;
        _latestMatch = VoiceCommandMatch(
          rawText: _recognizedText,
          recognizedAt: now,
          feedback: failed.feedback,
        );
        _latestResult = failed;
      });
      _pushHistory(failed);
    }
  }

  Future<void> _execute(VoiceCommandMatch match) async {
    setState(() => _executing = true);
    final result = widget.executeOverride == null
        ? await ElderVoiceCommandExecutor.execute(match)
        : await widget.executeOverride!(match);
    if (!mounted) return;
    setState(() {
      _executing = false;
      _latestResult = result;
    });
    _pushHistory(result);
  }

  void _pushHistory(VoiceCommandExecutionResult result) {
    setState(() {
      _history.insert(0, result);
      if (_history.length > _historyLimit) {
        _history.removeRange(_historyLimit, _history.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final match = _latestMatch;
    final result = _latestResult;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('语音控制'),
        backgroundColor: const Color(0xFFF7F8FC),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '语音控制',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  AppConfig.useMockStt
                      ? '当前使用 Mock 语音识别'
                      : '当前使用讯飞实时听写，配置缺失时会显示降级提示',
                  style: TextStyle(color: Color(0xFF475569), height: 1.5),
                ),
                SizedBox(height: 12),
                Text(
                  '支持：播放音乐 / 跳舞 / 开始表演 / 求助 / help / 停止',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _executing ? null : _toggleListening,
                  child: CircleAvatar(
                    radius: 58,
                    backgroundColor: _listening
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFEFF6FF),
                    child: _executing
                        ? const CircularProgressIndicator()
                        : Icon(
                            _listening ? Icons.stop : Icons.mic,
                            size: 54,
                            color: const Color(0xFF1D4ED8),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _executing
                      ? '正在执行命令...'
                      : _listening
                          ? '监听中，点一下停止'
                          : '点按开始识别',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ResultPanel(
            recognizedText: _recognizedText,
            match: match,
            result: result,
          ),
          const SizedBox(height: 12),
          _HistoryPanel(history: _history),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.recognizedText,
    required this.match,
    required this.result,
  });

  final String recognizedText;
  final VoiceCommandMatch? match;
  final VoiceCommandExecutionResult? result;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '执行结果',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _ResultRow(
            title: '识别文本',
            value: recognizedText.isEmpty ? '等待语音输入' : recognizedText,
          ),
          _ResultRow(
            title: '标准命令',
            value: match?.standardCommand ?? '未识别',
          ),
          _ResultRow(
            title: '执行状态',
            value: result?.status ?? 'pending',
          ),
          _ResultRow(title: 'taskId', value: result?.taskId ?? '-'),
          _ResultRow(title: 'status', value: result?.status ?? '-'),
          _ResultRow(title: 'feedback', value: result?.feedback ?? '-'),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.history});

  final List<VoiceCommandExecutionResult> history;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近记录',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Text('暂无记录', style: TextStyle(color: Color(0xFF94A3B8)))
          else
            for (final item in history) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.rawText.isEmpty ? '（空）' : item.rawText),
                subtitle: Text(
                  '${item.standardCommand} · ${item.status}\n${item.feedback}',
                ),
                trailing: Text(item.taskId ?? '-'),
              ),
              const Divider(height: 12),
            ],
        ],
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
            width: 80,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}
