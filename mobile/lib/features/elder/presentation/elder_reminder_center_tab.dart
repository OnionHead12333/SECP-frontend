import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_exercise_reminder_service.dart';
import '../data/elder_outing_reminder_service.dart';
import '../data/elder_water_reminder_service.dart';
import '../models/elder_exercise_progress.dart';
import '../models/elder_outing_status.dart';
import '../models/elder_water_progress.dart';

class ElderReminderCenterTab extends StatefulWidget {
  const ElderReminderCenterTab({super.key, required this.onOpenLocationPage});
  final VoidCallback onOpenLocationPage;

  @override
  State<ElderReminderCenterTab> createState() => _ElderReminderCenterTabState();
}

class _ElderReminderCenterTabState extends State<ElderReminderCenterTab> {
  bool _loading = true;
  bool _waterSubmitting = false;
  bool _exerciseSubmitting = false;
  String? _error;

  ElderWaterProgress? _water;
  ElderExerciseProgress? _exercise;
  ElderOutingStatus? _outing;

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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final water = await ElderWaterReminderService.fetchTodayProgress(elderId: _elderId);
      final exercise = await ElderExerciseReminderService.fetchTodayProgress(elderId: _elderId);
      final outing = await ElderOutingReminderService.fetchStatus(elderId: _elderId);
      if (!mounted) return;
      setState(() {
        _water = water;
        _exercise = exercise;
        _outing = outing;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _confirmWater() async {
    final water = _water;
    if (water == null || _waterSubmitting) return;
    setState(() => _waterSubmitting = true);
    try {
      final latest = await ElderWaterReminderService.confirmWater(elderId: _elderId, reminderId: water.activeReminderId);
      if (!mounted) return;
      setState(() => _water = latest);
      _toast('已记录喝水');
    } finally {
      if (mounted) setState(() => _waterSubmitting = false);
    }
  }

  Future<void> _completeExercise() async {
    final ex = _exercise;
    if (ex == null || _exerciseSubmitting) return;
    setState(() => _exerciseSubmitting = true);
    try {
      final latest = await ElderExerciseReminderService.completeExercise(
        elderId: _elderId,
        reminderId: ex.activeReminderId,
        source: 'manual',
      );
      if (!mounted) return;
      setState(() => _exercise = latest);
      _toast('已完成运动');
    } finally {
      if (mounted) setState(() => _exerciseSubmitting = false);
    }
  }

  Future<void> _refreshOutingStatus() async {
    final latest = await ElderOutingReminderService.fetchStatus(elderId: _elderId);
    if (!mounted) return;
    setState(() => _outing = latest);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const Text('提醒中心', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('越简单越好：先看提醒，再点一下，最后看结果。', style: TextStyle(color: Color(0xFF475569))),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        ],
        const SizedBox(height: 14),
        _box(
          title: '喝水提醒',
          step: '1. 看提醒  2. 点已喝水  3. 看结果',
          child: _water == null
              ? const Text('暂无数据')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('计划 ${_water!.plannedCount} 次 · 已确认 ${_water!.confirmedCount} 次 · 待执行 ${_water!.pendingCount} 次'),
                  const SizedBox(height: 6),
                  Text('进度 ${_water!.completionPercent.toStringAsFixed(1)}%'),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _waterSubmitting ? null : _confirmWater, child: Text(_waterSubmitting ? '提交中...' : '已喝水')),
                ]),
        ),
        const SizedBox(height: 12),
        _box(
          title: '运动提醒',
          step: '1. 看提醒  2. 点已完成运动  3. 看结果',
          child: _exercise == null
              ? const Text('暂无数据')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('计划 ${_exercise!.plannedCount} 次 · 完成 ${_exercise!.completedCount} 次 · 未完成 ${_exercise!.missedCount} 次'),
                  const SizedBox(height: 6),
                  Text('最近状态：${_statusLabel(_exercise!.lastCompletionStatus)}'),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _exerciseSubmitting ? null : _completeExercise,
                    child: Text(_exerciseSubmitting ? '提交中...' : '已完成运动'),
                  ),
                ]),
        ),
        const SizedBox(height: 12),
        _box(
          title: '外出提醒',
          step: '1. 看状态  2. 系统自动处理  3. 看结果',
          child: _outing == null
              ? const Text('暂无数据')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('定位：${_outing!.locationEnabled ? '已开启' : '未开启'} · 状态：${_outing!.currentState == 'outside' ? '外出中' : '在家'}'),
                  const SizedBox(height: 6),
                  Text('最近位置：${_outing!.lastLocationDesc ?? '-'}'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    OutlinedButton(onPressed: _refreshOutingStatus, child: const Text('刷新状态')),
                    FilledButton(onPressed: widget.onOpenLocationPage, child: const Text('查看详情')),
                  ]),
                ]),
        ),
      ],
    );
  }

  Widget _box({required String title, required String step, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(step, style: const TextStyle(color: Color(0xFF475569))),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'self_confirmed':
        return '已完成';
      case 'sensor_verified':
        return '已完成';
      case 'missed':
        return '未完成';
      default:
        return '待完成';
    }
  }
}
