import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_exercise_reminder_service.dart';

class ElderExerciseInProgressPage extends StatefulWidget {
  const ElderExerciseInProgressPage({
    super.key,
    required this.reminderId,
    required this.onCompleted,
  });

  final int reminderId;
  final Future<void> Function() onCompleted;

  @override
  State<ElderExerciseInProgressPage> createState() => _ElderExerciseInProgressPageState();
}

class _ElderExerciseInProgressPageState extends State<ElderExerciseInProgressPage> {
  static const double _motionThreshold = 0.8;
  static const int _requiredActiveSeconds = 8;

  Timer? _timer;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSubscription;
  DateTime? _startedAt;
  DateTime? _lastMotionAt;
  Duration _elapsed = Duration.zero;
  int _activeSeconds = 0;
  int _sensorSamples = 0;
  int _activeSamples = 0;
  double _motionScore = 0;
  double _rawMagnitude = 0;
  String _sensorSource = '等待传感器数据';
  bool _submitting = false;
  bool _sensorVerified = false;
  String? _sensorError;

  int get _elderId {
    switch (AuthSession.elderPhone) {
      case '13800138001':
        return 1;
      case '13800138002':
        return 2;
      case '13800138003':
        return 3;
      default:
        return 1;
    }
  }

  double get _sensorProgress => (_activeSeconds / _requiredActiveSeconds).clamp(0, 1).toDouble();

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _startTimer();
    _startMotionDetection();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt == null) return;
      final now = DateTime.now();
      final hasRecentMotion = _lastMotionAt != null && now.difference(_lastMotionAt!) <= const Duration(milliseconds: 1800);
      if (!mounted) return;
      setState(() {
        _elapsed = now.difference(startedAt);
        if (hasRecentMotion && !_sensorVerified) {
          _activeSeconds = min(_activeSeconds + 1, _requiredActiveSeconds);
          if (_activeSeconds >= _requiredActiveSeconds) {
            _sensorVerified = true;
          }
        }
      });
    });
  }

  void _startMotionDetection() {
    try {
      _userAccelerometerSubscription = userAccelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen(
        (event) {
          final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          _recordSensorSample(
            score: magnitude,
            rawMagnitude: magnitude,
            source: '去重力加速度',
            canTriggerMotion: true,
          );
        },
        onError: (_) => _markSensorError(),
        cancelOnError: false,
      );

      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen(
        (event) {
          final raw = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          final score = (raw - 9.8).abs();
          _recordSensorSample(
            score: score,
            rawMagnitude: raw,
            source: '普通加速度',
            canTriggerMotion: false,
          );
        },
        onError: (_) => _markSensorError(),
        cancelOnError: false,
      );
    } catch (_) {
      _markSensorError();
    }
  }

  void _recordSensorSample({
    required double score,
    required double rawMagnitude,
    required String source,
    required bool canTriggerMotion,
  }) {
    final safeScore = score.isFinite ? score : 0.0;
    final safeRaw = rawMagnitude.isFinite ? rawMagnitude : 0.0;
    final isActive = canTriggerMotion && safeScore >= _motionThreshold;
    if (!mounted) return;
    setState(() {
      _sensorSamples += 1;
      _motionScore = safeScore;
      _rawMagnitude = safeRaw;
      _sensorSource = source;
      _sensorError = null;
      if (isActive) {
        _activeSamples += 1;
        _lastMotionAt = DateTime.now();
      }
    });
  }

  void _markSensorError() {
    if (!mounted) return;
    setState(() => _sensorError = '传感器不可用，暂不能完成运动');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accelerometerSubscription?.cancel();
    _userAccelerometerSubscription?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _completeVerifiedExercise() async {
    if (_submitting || !_sensorVerified) return;
    setState(() => _submitting = true);
    try {
      await ElderExerciseReminderService.completeExercise(
        elderId: _elderId,
        reminderId: widget.reminderId,
        source: 'sensor',
      );
      if (!mounted) return;
      await widget.onCompleted();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('运动进行中')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('正在运动', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('需要先完成传感器验证，验证通过后老人再点击完成。', style: TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('已运动时长', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(_format(_elapsed), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _sensorVerified ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _sensorVerified ? const Color(0xFF14B8A6) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('传感器验证进度', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800)),
                      Text('$_activeSeconds/$_requiredActiveSeconds 秒', style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _sensorProgress,
                      minHeight: 12,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF14B8A6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _sensorVerified ? '传感器验证已通过，请点击下方“已完成运动”。' : '传感器未验证完成，暂不能点击完成。',
                    style: TextStyle(
                      color: _sensorVerified ? const Color(0xFF047857) : const Color(0xFFB45309),
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '强度 ${_motionScore.toStringAsFixed(3)} / 阈值 ${_motionThreshold.toStringAsFixed(1)} · 来源 $_sensorSource',
                    style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '样本 $_sensorSamples · 有效 $_activeSamples · 原始 ${_rawMagnitude.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                  ),
                  if (_sensorError != null) ...[
                    const SizedBox(height: 8),
                    Text(_sensorError!, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_submitting || !_sensorVerified) ? null : _completeVerifiedExercise,
                child: Text(_submitting ? '提交中...' : (_sensorVerified ? '已完成运动' : '请先完成传感器验证')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
