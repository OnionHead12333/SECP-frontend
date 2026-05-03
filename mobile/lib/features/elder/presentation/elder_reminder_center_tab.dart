import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

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
import 'dart:async';

class ElderReminderCenterTab extends StatefulWidget {
  const ElderReminderCenterTab({super.key, required this.onOpenLocationPage});
  final VoidCallback onOpenLocationPage;

  @override
  State<ElderReminderCenterTab> createState() => _ElderReminderCenterTabState();
}

class _ElderReminderCenterTabState extends State<ElderReminderCenterTab> 
 with WidgetsBindingObserver {
  final FlutterTts _tts = FlutterTts();
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
  Timer? _progressRefreshTimer;

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
  WidgetsBinding.instance.addObserver(this);
  _initTts();
  _load();
  _startProgressRefreshTimer();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  @override
  void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _progressRefreshTimer?.cancel();
  _tts.stop();
  super.dispose();
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

  Future<void> _refreshReminderProgressSilently() async {
  if (!mounted || _loading || _waterSubmitting || _medicineSubmitting || _exerciseSubmitting) {
    return;
  }
  try {
    final water = await ElderWaterReminderService.fetchTodayProgress(elderId: _elderId);
    final medicine = await ElderMedicineReminderService.fetchTodayProgress(elderId: _elderId);
    if (!mounted) return;
    setState(() {
      _water = water;
      _medicine = medicine;
    });
  } catch (_) {}
}

void _startProgressRefreshTimer() {
  _progressRefreshTimer?.cancel();
  _progressRefreshTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => _refreshReminderProgressSilently(),
  );
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _refreshReminderProgressSilently();
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

    String? res;
    try {
      final m = _medicine;
      final title = '该吃药啦';
      final medicineTitle = (m == null || m.medicineName.trim().isEmpty)
          ? ''
          : ((m.doseDesc == null || m.doseDesc!.trim().isEmpty)
              ? '\n${m.medicineName}'
              : '\n${m.medicineName}（${m.doseDesc}）');
      final speechMedicineName = (m == null || m.medicineName.trim().isEmpty) ? '今天这次药' : m.medicineName;
      final speechDose = (m?.doseDesc == null || m!.doseDesc!.trim().isEmpty) ? '' : '，剂量${m.doseDesc}';
      _playReminderCue('到吃药时间了，请按时服用$speechMedicineName$speechDose');      
      res = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
             '$title$medicineTitle',
             style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.35,
            ),
          ),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '请按时吃药',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop('snooze'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: const BorderSide(color: Color(0xFF9CA3AF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '稍后提醒',
                          // maxLines: 1,
                          // overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop('confirm'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '已吃药',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _toast('提醒弹窗异常：${e.toString().replaceFirst('Exception: ', '')}');
      return;
    } finally {
      _medicineDialogOpen = false;
      if (mounted) setState(() {});
    }

    if (res == 'confirm') {
      await _confirmMedicine();
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

    String? res;
    try {
      _playReminderCue('该喝水了，请及时补充水分。');
      res = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              '该喝水啦',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '请及时补充水分，身体更舒服。',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop('snooze'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: const BorderSide(color: Color(0xFF9CA3AF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '稍后',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop('confirm'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '已喝水',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _toast('提醒弹窗异常：${e.toString().replaceFirst('Exception: ', '')}');
      return;
    } finally {
      _waterDialogOpen = false;
      if (mounted) setState(() {});
    }

    if (res == 'confirm') {
      await _confirmWater();
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
    bool? res;
    try {
      _playReminderCue();
      res = await showDialog<bool>(
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
    } catch (e) {
      _toast('提醒弹窗异常：${e.toString().replaceFirst('Exception: ', '')}');
      return;
    }
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

  void _playReminderCue([String? speechText]) {
    // 移动端更稳定：直接触发震动 + 通知提示音（即使 HapticFeedback 不生效也能响/震）。
    //
    // 注意：音效仍受系统音量/勿扰策略影响，但相比 SystemSound 通常更稳定。
    () async {
      try {
        final hasVibrator = await Vibration.hasVibrator() == true;
        if (hasVibrator) {
          await Vibration.vibrate(duration: 180);
        } else {
          HapticFeedback.mediumImpact();
        }
      } catch (_) {
        try {
          HapticFeedback.mediumImpact();
        } catch (_) {}
      }

      try {
        FlutterRingtonePlayer().playNotification();
        if (true) {
          final text = (speechText == null || speechText.trim().isEmpty) ? '请查看提醒。' : speechText;
          try {
            await _tts.stop();
            await _tts.speak(text);
          } catch (_) {}
        }
      } catch (_) {
        try {
          SystemSound.play(SystemSoundType.alert);
        } catch (_) {}
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const Text('提醒', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        ],
        const SizedBox(height: 12),
        _box(
          title: '吃药提醒',
          step: '到时间会弹窗提醒并语音播报',
          child: _medicine == null
              ? const Text('暂无数据')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '剩余 ${_medicine!.pendingCount} 次',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton(
                      onPressed: _medicineSubmitting ? null : _confirmMedicine,
                      child: Text(_medicineSubmitting ? '提交中...' : '已吃药', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    OutlinedButton(
                      onPressed: _simulateMedicineReminder,
                      child: const Text('模拟触发提醒', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ]),
        ),
        const SizedBox(height: 12),
        _box(
          title: '喝水提醒',
          step: '到时间会弹窗提醒并语音播报',
          child: _water == null
              ? const Text('暂无数据')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '剩余 ${_water!.pendingCount} 次',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    FilledButton(
                      onPressed: _waterSubmitting ? null : _confirmWater,
                      child: Text(_waterSubmitting ? '提交中...' : '已喝水', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    OutlinedButton(
                      onPressed: _simulateWaterReminder,
                      child: const Text('模拟触发提醒', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ]),
        ),
        const SizedBox(height: 12),
        _box(
          title: '运动提醒',
          step: '到时间会弹窗提醒，确认后进入运动过程页',
          child: _exercise == null
              ? const Text('暂无数据')
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        '剩余 ${_exercise!.pendingCount} 次',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilledButton(
                              onPressed: _exerciseSubmitting ? null : _completeExercise,
                              child: Text(
                                _exerciseSubmitting ? '提交中...' : '已完成运动',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: _simulateExerciseReminder,
                              child: const Text('模拟触发提醒', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(step, style: const TextStyle(color: Color(0xFF475569), fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  // 这里不再展示复杂字段，老人端只保留“剩余次数”和“操作步骤”。
}
