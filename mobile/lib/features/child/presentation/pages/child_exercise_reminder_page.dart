import 'package:flutter/material.dart';

import '../../../../core/models/api_response.dart';
import '../../../../core/network/api_client.dart';
import '../../models/child_local_models.dart';

/// 子女端：锻炼提醒 CRUD，字段对齐库表 `exercise_reminders`。
final class ChildExerciseReminderPage extends StatefulWidget {
  const ChildExerciseReminderPage({
    super.key,
    required this.elders,
  });

  final List<BoundElder> elders;

  @override
  State<ChildExerciseReminderPage> createState() => _ChildExerciseReminderPageState();
}

class _ChildExerciseReminderPageState extends State<ChildExerciseReminderPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _exerciseTypeCtrl;

  String? _selectedElderId;
  int _startHour = 8;
  int _startMinute = 0;
  int _endHour = 18;
  int _endMinute = 0;
  String _repeatRule = 'daily';

  List<_ExerciseReminderRecord> _records = const [];
  bool _loadingRecords = false;

  bool _enabled = true;
  bool _submitting = false;

  static const _repeatChoices = <String, String>{
    'none': '不重复',
    'daily': '每天',
    'weekly': '每周',
  };

  @override
  void initState() {
    super.initState();
    _exerciseTypeCtrl = TextEditingController();
    _titleCtrl = TextEditingController();
    if (widget.elders.isNotEmpty) _selectedElderId = widget.elders.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _exerciseTypeCtrl.dispose();
    super.dispose();
  }

  int? _elderProfileIdOrNull() {
    final id = _selectedElderId;
    if (id == null || id.isEmpty) return null;
    final n = int.tryParse(id);
    if (n == null || n <= 0) return null;
    return n;
  }

  String _defaultTitleFromExerciseType(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '锻炼提醒';
    return '$s锻炼';
  }

  Future<void> _loadRecords() async {
    final elderProfileId = _elderProfileIdOrNull();
    if (elderProfileId == null) return;
    setState(() => _loadingRecords = true);
    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/v1/child/exercise-reminders',
        queryParameters: {'elderProfileId': elderProfileId},
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(
        body,
        (raw) {
          if (raw is List) return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          return const <Map<String, dynamic>>[];
        },
      );
      if (!api.isSuccess) throw Exception(api.displayMessage);
      final list = (api.data ?? const <Map<String, dynamic>>[]).map(_ExerciseReminderRecord.fromJson).toList();
      if (!mounted) return;
      setState(() => _records = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  Future<void> _deleteRecord(_ExerciseReminderRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除提醒'),
        content: const Text('确定删除这条锻炼提醒吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.dio.delete<Map<String, dynamic>>('/v1/child/exercise-reminders/${r.id}');
      if (!mounted) return;
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  Future<void> _editRecord(_ExerciseReminderRecord r) async {
    var title = r.title;
    var type = r.exerciseType;
    var repeat = r.repeatRule;
    var sh = r.startHour ?? 8, sm = r.startMinute ?? 0, eh = r.endHour ?? 18, em = r.endMinute ?? 0;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('修改锻炼提醒'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: title,
                  decoration: const InputDecoration(labelText: '标题'),
                  onChanged: (v) => title = v,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: '锻炼类型',
                    hintText: '如：散步、太极',
                  ),
                  onChanged: (v) => type = v,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: repeat,
                  items: [
                    for (final e in _repeatChoices.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  decoration: const InputDecoration(labelText: '重复规则'),
                  onChanged: (v) => setDialog(() => repeat = v ?? repeat),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: sh,
                        items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0')))],
                        decoration: const InputDecoration(labelText: '开始·小时'),
                        onChanged: (v) => setDialog(() => sh = v ?? sh),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: sm,
                        items: [for (var m = 0; m < 60; m++) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))],
                        decoration: const InputDecoration(labelText: '开始·分钟'),
                        onChanged: (v) => setDialog(() => sm = v ?? sm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: eh,
                        items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0')))],
                        decoration: const InputDecoration(labelText: '结束·小时'),
                        onChanged: (v) => setDialog(() => eh = v ?? eh),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: em,
                        items: [for (var m = 0; m < 60; m++) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))],
                        decoration: const InputDecoration(labelText: '结束·分钟'),
                        onChanged: (v) => setDialog(() => em = v ?? em),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final typeTrim = type.trim();
    if (typeTrim.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('锻炼类型不能为空')));
      return;
    }

    try {
      final payload = <String, dynamic>{
        'title': title.trim().isEmpty ? _defaultTitleFromExerciseType(typeTrim) : title.trim(),
        'exerciseType': typeTrim,
        'repeatRule': repeat,
        'startTime': '${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}:00',
        'endTime': '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}:00',
      };

      final res = await ApiClient.dio.put<Map<String, dynamic>>(
        '/v1/child/exercise-reminders/${r.id}',
        data: payload,
      );
      final body = res.data;
      if (body != null) {
        final api = ApiResponse.fromJson(body, (raw) => raw);
        if (!api.isSuccess) throw Exception(api.displayMessage);
      }
      if (!mounted) return;
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  Future<void> _submit() async {
    if (!_enabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先开启锻炼提醒')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('所选老人无效，请重新选择')));
      return;
    }

    final typeTrim = _exerciseTypeCtrl.text.trim();
    if (typeTrim.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入锻炼类型')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'elderProfileId': elderProfileId,
        'title': _titleCtrl.text.trim().isEmpty ? _defaultTitleFromExerciseType(typeTrim) : _titleCtrl.text.trim(),
        'exerciseType': typeTrim,
        'startTime': '${_startHour.toString().padLeft(2, '0')}:${_startMinute.toString().padLeft(2, '0')}:00',
        'endTime': '${_endHour.toString().padLeft(2, '0')}:${_endMinute.toString().padLeft(2, '0')}:00',
        'remindTime': DateTime.now().toUtc().toIso8601String(),
        'repeatRule': _repeatRule,
        'enabled': true,
        'sourceType': 'child_remote',
        'status': 'pending',
        'createdBy': 'child',
      };

      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/v1/child/exercise-reminders',
        data: data,
      );
      final body = res.data;
      if (body == null) throw Exception('空响应');
      final api = ApiResponse.fromJson(body, (raw) => raw);
      if (!api.isSuccess) throw Exception(api.displayMessage);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已创建锻炼提醒')));
      await _loadRecords();
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

    return Scaffold(
      appBar: AppBar(title: const Text('锻炼提醒')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('为老人设定锻炼计划', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedElderId,
                    items: [
                      for (final e in elders) DropdownMenuItem(value: e.id, child: Text(e.displayName)),
                    ],
                    decoration: const InputDecoration(
                      labelText: '选择老人',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: _submitting || elders.isEmpty
                        ? null
                        : (v) {
                            setState(() => _selectedElderId = v);
                            _loadRecords();
                          },
                    validator: (_) {
                      if (elders.isEmpty) return '请先到「设置」绑定老人';
                      if (_selectedElderId == null || _selectedElderId!.isEmpty) return '必选';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开启锻炼提醒'),
                    subtitle: Text(_enabled ? '提交后将创建远程锻炼提醒' : '关闭后不创建'),
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
                        prefixIcon: Icon(Icons.title),
                      ),
                      enabled: !_submitting && _enabled && elders.isNotEmpty,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _exerciseTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: '锻炼类型',
                        hintText: '如：散步、太极',
                        prefixIcon: Icon(Icons.directions_run_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                      enabled: !_submitting && _enabled && elders.isNotEmpty,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '请输入锻炼内容';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _repeatRule,
                      items: [
                        for (final e in _repeatChoices.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      decoration: const InputDecoration(
                        labelText: '重复规则',
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _repeatRule = v ?? _repeatRule),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('建议锻炼时段', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _startHour,
                            items: [for (final h in hours) DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0')))],
                            decoration: const InputDecoration(labelText: '开始·小时', prefixIcon: Icon(Icons.wb_sunny_outlined)),
                            onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _startHour = v ?? 8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _startMinute,
                            items: [for (final m in minutes) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))],
                            decoration: const InputDecoration(labelText: '开始·分钟', prefixIcon: Icon(Icons.more_time)),
                            onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _startMinute = v ?? 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _endHour,
                            items: [for (final h in hours) DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0')))],
                            decoration: const InputDecoration(labelText: '结束·小时', prefixIcon: Icon(Icons.nightlight_outlined)),
                            onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _endHour = v ?? 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _endMinute,
                            items: [for (final m in minutes) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))],
                            decoration: const InputDecoration(labelText: '结束·分钟', prefixIcon: Icon(Icons.more_time)),
                            onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _endMinute = v ?? 0),
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
                            : const Icon(Icons.add_alarm_outlined),
                        label: Text(_submitting ? '提交中…' : '创建锻炼提醒'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('提醒记录', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        tooltip: '刷新',
                        onPressed: _loadingRecords ? null : _loadRecords,
                        icon: _loadingRecords
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_records.isEmpty) ...[
                    Text('暂无记录', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    _exampleTile(
                      context,
                      title: '散步锻炼',
                      subtitle: '散步 · 每天 · 08:00 - 18:00',
                      statusLabel: '老人已确认',
                    ),
                    _exampleTile(
                      context,
                      title: '太极锻炼',
                      subtitle: '太极 · 每周 · 08:00 - 18:00',
                      statusLabel: '待完成',
                    ),
                  ] else ...[
                    for (final r in _records)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.directions_run_outlined),
                        title: Text(r.displayTitle),
                        subtitle: Text(
                          '${r.exerciseType} · ${_repeatChoices[r.repeatRule] ?? r.repeatRule}\n'
                          '时段 ${r.startTimeText ?? '--'} - ${r.endTimeText ?? '--'} · ${_ExerciseReminderRecord.statusLabel(r.status)}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(tooltip: '修改', onPressed: () => _editRecord(r), icon: const Icon(Icons.edit_outlined)),
                            IconButton(tooltip: '删除', onPressed: () => _deleteRecord(r), icon: const Icon(Icons.delete_outline)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exampleTile(BuildContext context, {required String title, required String subtitle, required String statusLabel}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.directions_run_outlined),
      title: Text('$title（示例）'),
      subtitle: Text('$subtitle\n状态：$statusLabel'),
      isThreeLine: true,
    );
  }
}

final class _ExerciseReminderRecord {
  _ExerciseReminderRecord({
    required this.id,
    required this.elderProfileId,
    required this.title,
    required this.exerciseType,
    required this.goalValue,
    required this.goalUnit,
    this.intervalMinutes,
    this.startTimeText,
    this.endTimeText,
    required this.repeatRule,
    required this.status,
  });

  final int id;
  final int elderProfileId;
  final String title;
  final String exerciseType;
  final int? goalValue;
  final String goalUnit;
  final int? intervalMinutes;
  final String? startTimeText;
  final String? endTimeText;
  final String repeatRule;
  final String status;

  String get displayTitle => title.trim().isEmpty ? '$exerciseType锻炼' : title;

  int? get startHour => _parseHm(startTimeText)?.$1;
  int? get startMinute => _parseHm(startTimeText)?.$2;
  int? get endHour => _parseHm(endTimeText)?.$1;
  int? get endMinute => _parseHm(endTimeText)?.$2;

  static (int, int)? _parseHm(String? t) {
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }

  static String statusLabel(String s) {
    return const {
          'pending': '待完成',
          'completed': '已完成',
          'timeout': '超时',
          'cancelled': '已取消',
          'self_confirmed': '老人已确认',
          'sensor_verified': '传感器验证',
          'missed': '漏做',
        }[s] ??
        s;
  }

  static _ExerciseReminderRecord fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);
    int? asIntNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return _ExerciseReminderRecord(
      id: asInt(json['id']),
      elderProfileId: asInt(json['elderProfileId'] ?? json['elder_profile_id']),
      title: (json['title'] ?? '').toString(),
      exerciseType: (json['exerciseType'] ?? json['exercise_type'] ?? '').toString(),
      goalValue: asIntNull(json['goalValue'] ?? json['goal_value']),
      goalUnit: (json['goalUnit'] ?? json['goal_unit'] ?? 'minutes').toString(),
      intervalMinutes: asIntNull(json['intervalMinutes'] ?? json['interval_minutes']),
      startTimeText: (json['startTime'] ?? json['start_time'])?.toString(),
      endTimeText: (json['endTime'] ?? json['end_time'])?.toString(),
      repeatRule: (json['repeatRule'] ?? json['repeat_rule'] ?? 'none').toString(),
      status: (json['status'] ?? 'pending').toString(),
    );
  }
}
