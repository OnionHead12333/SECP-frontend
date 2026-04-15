import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/models/api_response.dart';
import '../../models/child_local_models.dart';

final class ChildRemoteMedicalItemPage extends StatefulWidget {
  const ChildRemoteMedicalItemPage({
    super.key,
    required this.elders,
  });

  final List<BoundElder> elders;

  @override
  State<ChildRemoteMedicalItemPage> createState() => _ChildRemoteMedicalItemPageState();
}

class _ChildRemoteMedicalItemPageState extends State<ChildRemoteMedicalItemPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController(text: '吃药提醒');
  final _repeatRuleCtrl = TextEditingController(text: 'none');

  DateTime _remindAt = DateTime.now().add(const Duration(hours: 1));
  late int _hour;
  late int _minute;
  String? _selectedElderId;
  bool _enableMedicineReminder = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _hour = _remindAt.hour;
    _minute = _remindAt.minute;
    if (widget.elders.isNotEmpty) {
      _selectedElderId = widget.elders.first.id;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _repeatRuleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRemindDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(_remindAt.year, _remindAt.month, _remindAt.day);
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate,
    );
    if (pickedDate == null) return;
    setState(() {
      _remindAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _hour,
        _minute,
      );
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
    if (!_enableMedicineReminder) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先开启“辅助吃药提醒”')));
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
        '/v1/child/reminders',
        data: {
          'elderProfileId': elderProfileId,
          'title': _titleCtrl.text.trim(),
          'reminderType': 'medicine',
          'sourceType': 'child_remote',
          'relatedEventId': null,
          'remindTime': _remindAt.toUtc().toIso8601String(),
          'repeatRule': _repeatRuleCtrl.text.trim().isEmpty ? 'none' : _repeatRuleCtrl.text.trim(),
          'status': 'pending',
          'createdBy': 'child',
        },
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(body, (raw) => raw);
      if (!api.isSuccess) throw Exception(api.message);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已创建吃药提醒')));
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
    final hours = List<int>.generate(24, (i) => i);
    final minutes = List<int>.generate(60, (i) => i);
    final elders = widget.elders;

    return Scaffold(
      appBar: AppBar(title: const Text('远程添加医疗事项')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('辅助吃药提醒', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '为老人设置按时吃药的提醒（子女端远程添加）。',
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
                    onChanged: _submitting || !_enableMedicineReminder || elders.isEmpty
                        ? null
                        : (v) => setState(() => _selectedElderId = v),
                    validator: (_) {
                      if (elders.isEmpty) return '请先到「设置」绑定老人';
                      if (_selectedElderId == null || _selectedElderId!.isEmpty) return '必选';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开启吃药提醒'),
                    subtitle: Text(_enableMedicineReminder ? '将创建一条待执行提醒' : '关闭后不创建提醒'),
                    value: _enableMedicineReminder,
                    onChanged: (v) => setState(() => _enableMedicineReminder = v),
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
                        hintText: '如：饭后服用降压药',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                      maxLength: 100,
                      validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
                      enabled: !_submitting && _enableMedicineReminder && elders.isNotEmpty,
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('提醒时间'),
                      subtitle: Text(_fmtDateTime(_remindAt)),
                      trailing: TextButton(
                        onPressed: _submitting || !_enableMedicineReminder || elders.isEmpty ? null : _pickRemindDate,
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
                              for (final h in hours)
                                DropdownMenuItem(
                                  value: h,
                                  child: Text(h.toString().padLeft(2, '0')),
                                ),
                            ],
                            decoration: const InputDecoration(
                              labelText: '小时',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            onChanged: _submitting || !_enableMedicineReminder || elders.isEmpty
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _hour = v;
                                      _remindAt = DateTime(
                                        _remindAt.year,
                                        _remindAt.month,
                                        _remindAt.day,
                                        _hour,
                                        _minute,
                                      );
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _minute,
                            items: [
                              for (final m in minutes)
                                DropdownMenuItem(
                                  value: m,
                                  child: Text(m.toString().padLeft(2, '0')),
                                ),
                            ],
                            decoration: const InputDecoration(
                              labelText: '分钟',
                              prefixIcon: Icon(Icons.more_time),
                            ),
                            onChanged: _submitting || !_enableMedicineReminder || elders.isEmpty
                                ? null
                                : (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _minute = v;
                                      _remindAt = DateTime(
                                        _remindAt.year,
                                        _remindAt.month,
                                        _remindAt.day,
                                        _hour,
                                        _minute,
                                      );
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    DropdownButtonFormField<String>(
                      value: _repeatRuleCtrl.text.trim().isEmpty ? 'none' : _repeatRuleCtrl.text.trim(),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('不重复')),
                        DropdownMenuItem(value: 'daily', child: Text('每天')),
                        DropdownMenuItem(value: 'weekly', child: Text('每周')),
                      ],
                      decoration: const InputDecoration(
                        labelText: '重复规则',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      onChanged: _submitting || !_enableMedicineReminder || elders.isEmpty
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _repeatRuleCtrl.text = v);
                            },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting || elders.isEmpty ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.notifications_active_outlined),
                        label: Text(_submitting ? '提交中…' : '创建吃药提醒'),
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

