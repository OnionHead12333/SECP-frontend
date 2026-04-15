import 'package:flutter/material.dart';

import '../../../../core/models/api_response.dart';
import '../../../../core/network/api_client.dart';
import '../../models/child_local_models.dart';

final class ChildWaterReminderPage extends StatefulWidget {
  const ChildWaterReminderPage({
    super.key,
    required this.elders,
  });

  final List<BoundElder> elders;

  @override
  State<ChildWaterReminderPage> createState() => _ChildWaterReminderPageState();
}

class _ChildWaterReminderPageState extends State<ChildWaterReminderPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController(text: '喝水提醒');

  String? _selectedElderId;
  int _dailyTargetMl = 1500;
  int _intervalMinutes = 60;

  DateTime _nextRemindAt = DateTime.now().add(const Duration(hours: 1));
  late int _hour;
  late int _minute;

  bool _enabled = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.elders.isNotEmpty) _selectedElderId = widget.elders.first.id;
    _hour = _nextRemindAt.hour;
    _minute = _nextRemindAt.minute;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(_nextRemindAt.year, _nextRemindAt.month, _nextRemindAt.day);
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate,
    );
    if (pickedDate == null) return;
    setState(() {
      _nextRemindAt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _hour, _minute);
    });
  }

  String _fmtDateTime(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _submit() async {
    if (!_enabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先开启喝水提醒')));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final selectedId = _selectedElderId;
    if (selectedId == null || selectedId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择老人')));
      return;
    }
    final elderProfileId = int.tryParse(selectedId);
    if (elderProfileId == null || elderProfileId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('所选老人档案ID 无效')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/v1/child/water-reminders',
        data: {
          'elderProfileId': elderProfileId,
          'title': _titleCtrl.text.trim(),
          'dailyTargetMl': _dailyTargetMl,
          'intervalMinutes': _intervalMinutes,
          'remindTime': _nextRemindAt.toUtc().toIso8601String(),
          'sourceType': 'child_remote',
          'status': 'pending',
          'createdBy': 'child',
        },
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(body, (raw) => raw);
      if (!api.isSuccess) throw Exception(api.message);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已创建喝水提醒')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败：$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final elders = widget.elders;

    final hours = List<int>.generate(24, (i) => i);
    final minutes = List<int>.generate(60, (i) => i);

    final targetOptions = const [800, 1000, 1200, 1500, 1800, 2000, 2500];
    final intervalOptions = const [30, 45, 60, 90, 120, 180];

    return Scaffold(
      appBar: AppBar(title: const Text('喝水提醒')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('设置喝水目标与间隔', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '按建议书：支持每日目标饮水量与提醒间隔，生成全天喝水日程（MVP）。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedElderId,
                    items: [
                      for (final e in elders)
                        DropdownMenuItem(
                          value: e.id,
                          child: Text(e.accountHint == null || e.accountHint!.isEmpty ? e.displayName : '${e.displayName}（${e.accountHint}）'),
                        ),
                    ],
                    decoration: const InputDecoration(
                      labelText: '选择老人',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: _submitting || elders.isEmpty ? null : (v) => setState(() => _selectedElderId = v),
                    validator: (_) {
                      if (elders.isEmpty) return '请先到「设置」绑定老人';
                      if (_selectedElderId == null || _selectedElderId!.isEmpty) return '必选';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开启喝水提醒'),
                    subtitle: Text(_enabled ? '将创建/更新喝水提醒配置' : '关闭后不创建提醒'),
                    value: _enabled,
                    onChanged: _submitting || elders.isEmpty ? null : (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        hintText: '如：每小时喝水一次',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                      maxLength: 100,
                      validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
                      enabled: !_submitting && _enabled && elders.isNotEmpty,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _dailyTargetMl,
                      items: [
                        for (final ml in targetOptions) DropdownMenuItem(value: ml, child: Text('$ml ml')),
                      ],
                      decoration: const InputDecoration(
                        labelText: '每日目标饮水量',
                        prefixIcon: Icon(Icons.local_drink_outlined),
                      ),
                      onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _dailyTargetMl = v ?? 1500),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _intervalMinutes,
                      items: [
                        for (final m in intervalOptions) DropdownMenuItem(value: m, child: Text('$m 分钟/次')),
                      ],
                      decoration: const InputDecoration(
                        labelText: '提醒间隔',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _intervalMinutes = v ?? 60),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('下一次提醒时间'),
                      subtitle: Text(_fmtDateTime(_nextRemindAt)),
                      trailing: TextButton(
                        onPressed: _submitting || !_enabled || elders.isEmpty ? null : _pickDate,
                        child: const Text('选日期'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _hour,
                            items: [
                              for (final h in hours) DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0'))),
                            ],
                            decoration: const InputDecoration(labelText: '小时', prefixIcon: Icon(Icons.access_time)),
                            onChanged: _submitting || !_enabled || elders.isEmpty
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _hour = v;
                                      _nextRemindAt = DateTime(_nextRemindAt.year, _nextRemindAt.month, _nextRemindAt.day, _hour, _minute);
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _minute,
                            items: [
                              for (final m in minutes) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))),
                            ],
                            decoration: const InputDecoration(labelText: '分钟', prefixIcon: Icon(Icons.more_time)),
                            onChanged: _submitting || !_enabled || elders.isEmpty
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _minute = v;
                                      _nextRemindAt = DateTime(_nextRemindAt.year, _nextRemindAt.month, _nextRemindAt.day, _hour, _minute);
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting || elders.isEmpty ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.water_drop_outlined),
                        label: Text(_submitting ? '提交中…' : '创建喝水提醒'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

