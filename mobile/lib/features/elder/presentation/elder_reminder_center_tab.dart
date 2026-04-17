import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_exercise_reminder_service.dart';
import '../data/elder_medicine_reminder_service.dart';
import '../data/elder_outing_reminder_service.dart';
import '../data/elder_water_reminder_service.dart';
import 'elder_exercise_in_progress_page.dart';
import 'elder_outing_summary_page.dart';
import '../models/elder_exercise_progress.dart';
import '../models/elder_medicine_progress.dart';
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
  bool _medicineSubmitting = false;
  String? _error;

  ElderWaterProgress? _water;
  ElderExerciseProgress? _exercise;
  ElderOutingStatus? _outing;
  ElderMedicineProgress? _medicine;

  bool _waterDialogOpen = false;
  DateTime? _waterLastPromptAt;
  int _waterSnoozeCount = 0;

  bool _medicineDialogOpen = false;
  DateTime? _medicineLastPromptAt;
  int _medicineSnoozeCount = 0;

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
      final medicine = await ElderMedicineReminderService.fetchTodayProgress(elderId: _elderId);
      if (!mounted) return;
      setState(() {
        _water = water;
        _exercise = exercise;
        _outing = outing;
        _medicine = medicine;
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

  Future<void> _postponeWaterOnce() async {
    final latest = await ElderWaterReminderService.postponeOnceMock();
    if (!mounted) return;
    setState(() => _water = latest);
  }

  Future<void> _missWaterOnce() async {
    final latest = await ElderWaterReminderService.markMissedMock();
    if (!mounted) return;
    setState(() => _water = latest);
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

  Future<void> _confirmMedicine() async {
    final m = _medicine;
    if (m == null || _medicineSubmitting) return;
    setState(() => _medicineSubmitting = true);
    try {
      final latest = await ElderMedicineReminderService.confirmTaken(elderId: _elderId, reminderId: m.activeReminderId);
      if (!mounted) return;
      setState(() => _medicine = latest);
      _toast('已记录吃药');
    } finally {
      if (mounted) setState(() => _medicineSubmitting = false);
    }
  }

  Future<void> _postponeMedicineOnce() async {
    final latest = await ElderMedicineReminderService.postponeOnceMock();
    if (!mounted) return;
    setState(() => _medicine = latest);
  }

  Future<void> _missMedicineOnce() async {
    final latest = await ElderMedicineReminderService.markMissedMock();
    if (!mounted) return;
    setState(() => _medicine = latest);
  }

  Future<void> _refreshOutingStatus() async {
    final latest = await ElderOutingReminderService.fetchStatus(elderId: _elderId);
    if (!mounted) return;
    setState(() => _outing = latest);
  }

  Future<void> _simulateMedicineReminder() async {
    final now = DateTime.now();
    if (_medicineDialogOpen) return;
    if (_medicineLastPromptAt != null && now.difference(_medicineLastPromptAt!) < const Duration(seconds: 2)) return;
    _medicineLastPromptAt = now;
    _medicineDialogOpen = true;
    if (mounted) setState(() {});

    final m = _medicine;
    final title = (m == null || m.medicineName.trim().isEmpty) ? '该吃药啦' : '该吃药啦 · ${m.medicineName}';
    final dose = (m?.doseDesc == null || m!.doseDesc!.trim().isEmpty) ? '' : '（${m.doseDesc}）';
    final res = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text('按时吃药，身体更安心$dose'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('snooze'),
              child: const Text('稍后提醒'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('miss'),
              child: const Text('这次不吃'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('confirm'),
              child: const Text('已吃药'),
            ),
          ],
        );
      },
    );

    _medicineDialogOpen = false;
    if (!mounted) return;
    setState(() {});

    if (res == 'confirm') {
      await _confirmMedicine();
      _medicineSnoozeCount = 0;
      return;
    }
    if (res == 'miss') {
      await _missMedicineOnce();
      _toast('已记录：本次未吃药');
      _medicineSnoozeCount = 0;
      return;
    }

    _medicineSnoozeCount = (_medicineSnoozeCount + 1).clamp(0, 99);
    await _postponeMedicineOnce();
    _toast('好的，1 分钟后再提醒');
    await Future<void>.delayed(const Duration(minutes: 1));
    if (!mounted) return;
    if (_medicineSnoozeCount > 0) {
      await _simulateMedicineReminder();
    }
  }

  Future<void> _simulateWaterReminder() async {
    final now = DateTime.now();
    if (_waterDialogOpen) return;
    if (_waterLastPromptAt != null && now.difference(_waterLastPromptAt!) < const Duration(seconds: 2)) return;
    _waterLastPromptAt = now;
    _waterDialogOpen = true;
    if (mounted) setState(() {});

    final res = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('该喝水啦'),
          content: const Text('喝一小杯水，身体更舒服。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('snooze'),
              child: const Text('稍后提醒'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('miss'),
              child: const Text('这次不喝'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('confirm'),
              child: const Text('已喝水'),
            ),
          ],
        );
      },
    );

    _waterDialogOpen = false;
    if (!mounted) return;
    setState(() {});

    if (res == 'confirm') {
      await _confirmWater();
      _waterSnoozeCount = 0;
      return;
    }
    if (res == 'miss') {
      await _missWaterOnce();
      _toast('已记录：本次未喝水');
      _waterSnoozeCount = 0;
      return;
    }

    // 默认视为“稍后提醒”
    _waterSnoozeCount = (_waterSnoozeCount + 1).clamp(0, 99);
    await _postponeWaterOnce();
    _toast('好的，1 分钟后再提醒');
    await Future<void>.delayed(const Duration(minutes: 1));
    if (!mounted) return;
    if (_waterSnoozeCount > 0) {
      await _simulateWaterReminder();
    }
  }

  Future<void> _simulateExerciseReminder() async {
    final ex = _exercise;
    if (ex == null) return;
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('该运动啦'),
          content: const Text('现在开始运动，完成后点“已完成运动”。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('稍后')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('开始运动')),
          ],
        );
      },
    );
    if (res != true || !mounted) return;
    await ElderExerciseReminderService.startExercise(elderId: _elderId, reminderId: ex.activeReminderId);
    if (!mounted) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ElderExerciseInProgressPage(
          reminderId: ex.activeReminderId,
          onCompleted: _load,
        ),
      ),
    );
    if (!mounted) return;
    if (completed == true) {
      _toast('已完成运动');
    }
  }

  void _openOutingSummary() {
    final outing = _outing;
    if (outing == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ElderOutingSummaryPage(
          status: outing,
          onRefresh: () async {
            final latest = await ElderOutingReminderService.fetchStatus(elderId: _elderId);
            if (mounted) setState(() => _outing = latest);
            return latest;
          },
          onOpenLocationDetail: widget.onOpenLocationPage,
        ),
      ),
    );
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
          title: '吃药提醒',
          step: '1. 看提醒  2. 点已吃药  3. 看结果',
          child: _medicine == null
              ? const Text('暂无数据')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('当前：${_medicine!.medicineName}${_medicine!.doseDesc == null ? '' : '（${_medicine!.doseDesc}）'}'),
                  const SizedBox(height: 6),
                  Text('计划 ${_medicine!.plannedCount} 次 · 已确认 ${_medicine!.confirmedCount} 次 · 待执行 ${_medicine!.pendingCount} 次 · 未执行 ${_medicine!.missedCount} 次'),
                  const SizedBox(height: 6),
                  Text('进度 ${_medicine!.completionPercent.toStringAsFixed(1)}%'),
                  const SizedBox(height: 6),
                  Text('上次确认：${_fmtTime(_medicine!.lastConfirmedAt)}'),
                  const SizedBox(height: 4),
                  Text('下次提醒：${_fmtTime(_medicine!.nextReminderAt)}'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton(
                      onPressed: _medicineSubmitting ? null : _confirmMedicine,
                      child: Text(_medicineSubmitting ? '提交中...' : '已吃药'),
                    ),
                    OutlinedButton(
                      onPressed: _simulateMedicineReminder,
                      child: const Text('模拟触发提醒'),
                    ),
                  ]),
                ]),
        ),
        const SizedBox(height: 12),
        _box(
          title: '喝水提醒',
          step: '1. 看提醒  2. 点已喝水  3. 看结果',
          child: _water == null
              ? const Text('暂无数据')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('计划 ${_water!.plannedCount} 次 · 已确认 ${_water!.confirmedCount} 次 · 待执行 ${_water!.pendingCount} 次'),
                  const SizedBox(height: 6),
                  Text('进度 ${_water!.completionPercent.toStringAsFixed(1)}%'),
                  const SizedBox(height: 6),
                  Text('上次确认：${_fmtTime(_water!.lastConfirmedAt)}'),
                  const SizedBox(height: 4),
                  Text('下次提醒：${_fmtTime(_water!.nextReminderAt)}'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton(
                      onPressed: _waterSubmitting ? null : _confirmWater,
                      child: Text(_waterSubmitting ? '提交中...' : '已喝水'),
                    ),
                    OutlinedButton(
                      onPressed: _simulateWaterReminder,
                      child: const Text('模拟触发提醒'),
                    ),
                  ]),
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
                  const SizedBox(height: 4),
                  Text('最近完成：${_fmtTime(_exercise!.lastCompletedAt)}'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton(
                      onPressed: _exerciseSubmitting ? null : _completeExercise,
                      child: Text(_exerciseSubmitting ? '提交中...' : '已完成运动'),
                    ),
                    OutlinedButton(
                      onPressed: _simulateExerciseReminder,
                      child: const Text('模拟触发提醒'),
                    ),
                  ]),
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
                    FilledButton(onPressed: _openOutingSummary, child: const Text('查看摘要')),
                    OutlinedButton(onPressed: widget.onOpenLocationPage, child: const Text('定位详情')),
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

  String _fmtTime(DateTime? t) {
    if (t == null) return '-';
    final local = t.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}
