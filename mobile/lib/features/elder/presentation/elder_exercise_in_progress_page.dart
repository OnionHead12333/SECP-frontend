import 'dart:async';

import 'package:flutter/material.dart';

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
  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _submitting = false;

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

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(startedAt));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _complete({required String source}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ElderExerciseReminderService.completeExercise(
        elderId: _elderId,
        reminderId: widget.reminderId,
        source: source,
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
            const Text('坚持一下，完成后点“已完成运动”。', style: TextStyle(color: Color(0xFF475569))),
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
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : () => _complete(source: 'manual'),
                child: Text(_submitting ? '提交中...' : '已完成运动'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _submitting ? null : () => _complete(source: 'sensor'),
                child: const Text('模拟传感器判定已完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

