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

  String? _selectedElderId;
  int _dailyTargetMl = 1500;
  int _intervalMinutes = 60;
  int _startHour = 8;
  int _startMinute = 0;
  int _endHour = 22;
  int _endMinute = 0;
  List<_WaterReminderRecord> _records = const [];
  bool _loadingRecords = false;

  bool _enabled = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.elders.isNotEmpty) _selectedElderId = widget.elders.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  @override
  void dispose() {
    super.dispose();
  }

  int? _elderProfileIdOrNull() {
    final id = _selectedElderId;
    if (id == null || id.isEmpty) return null;
    final n = int.tryParse(id);
    if (n == null || n <= 0) return null;
    return n;
  }

  String _fmtHm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _loadRecords() async {
    final elderProfileId = _elderProfileIdOrNull();
    if (elderProfileId == null) return;
    setState(() => _loadingRecords = true);
    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/v1/child/water-reminders',
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
      if (!api.isSuccess) throw Exception(api.message);
      final list = (api.data ?? const <Map<String, dynamic>>[]).map(_WaterReminderRecord.fromJson).toList();
      if (!mounted) return;
      setState(() => _records = list);
    } catch (e) {
      // 不向用户暴露后端错误；保留当前列表状态即可
    } finally {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  Future<void> _deleteRecord(_WaterReminderRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除提醒'),
        content: const Text('确定删除这条喝水提醒吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.dio.delete<Map<String, dynamic>>('/v1/child/water-reminders/${r.id}');
      if (!mounted) return;
      await _loadRecords();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  Future<void> _editRecord(_WaterReminderRecord r) async {
    int target = r.dailyTargetMl;
    int interval = r.intervalMinutes;
    int sh = r.startHour ?? 8, sm = r.startMinute ?? 0, eh = r.endHour ?? 22, em = r.endMinute ?? 0;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('修改喝水提醒'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: target,
                  items: const [800, 1000, 1200, 1500, 1800, 2000, 2500].map((ml) => DropdownMenuItem(value: ml, child: Text('$ml ml'))).toList(),
                  decoration: const InputDecoration(labelText: '每日目标饮水量'),
                  onChanged: (v) => setDialog(() => target = v ?? target),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: interval,
                  items: const [30, 45, 60, 90, 120, 180].map((m) => DropdownMenuItem(value: m, child: Text('$m 分钟/次'))).toList(),
                  decoration: const InputDecoration(labelText: '提醒间隔'),
                  onChanged: (v) => setDialog(() => interval = v ?? interval),
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

    try {
      final res = await ApiClient.dio.put<Map<String, dynamic>>(
        '/v1/child/water-reminders/${r.id}',
        data: {
          'title': '喝水提醒',
          'dailyTargetMl': target,
          'intervalMinutes': interval,
          'startTime': '${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}:00',
          'endTime': '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}:00',
        },
      );
      final body = res.data;
      if (body != null) {
        final api = ApiResponse.fromJson(body, (raw) => raw);
        if (!api.isSuccess) throw Exception(api.message);
      }
      if (!mounted) return;
      await _loadRecords();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
    }
  }

  Future<void> _editExampleRecord(_WaterReminderRecord r) async {
    int target = r.dailyTargetMl;
    int interval = r.intervalMinutes;
    int sh = r.startHour ?? 8, sm = r.startMinute ?? 0, eh = r.endHour ?? 22, em = r.endMinute ?? 0;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('修改喝水提醒（示例）'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: target,
                  items: const [800, 1000, 1200, 1500, 1800, 2000, 2500].map((ml) => DropdownMenuItem(value: ml, child: Text('$ml ml'))).toList(),
                  decoration: const InputDecoration(labelText: '每日目标饮水量'),
                  onChanged: (v) => setDialog(() => target = v ?? target),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: interval,
                  items: const [30, 45, 60, 90, 120, 180].map((m) => DropdownMenuItem(value: m, child: Text('$m 分钟/次'))).toList(),
                  decoration: const InputDecoration(labelText: '提醒间隔'),
                  onChanged: (v) => setDialog(() => interval = v ?? interval),
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('示例已模拟保存（未请求后端）')));
  }

  Future<void> _deleteExampleRecord() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除提醒（示例）'),
        content: const Text('这是示例数据，仅用于测试交互。确定要模拟删除吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('示例已模拟删除（未请求后端）')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('所选老人无效，请重新选择')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiClient.dio.post<Map<String, dynamic>>(
        '/v1/child/water-reminders',
        data: {
          'elderProfileId': elderProfileId,
          'title': '喝水提醒',
          'dailyTargetMl': _dailyTargetMl,
          'intervalMinutes': _intervalMinutes,
          'startTime': '${_startHour.toString().padLeft(2, '0')}:${_startMinute.toString().padLeft(2, '0')}:00',
          'endTime': '${_endHour.toString().padLeft(2, '0')}:${_endMinute.toString().padLeft(2, '0')}:00',
          'remindTime': DateTime.now().toUtc().toIso8601String(),
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('喝水时段', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _startHour,
                            items: [
                              for (final h in hours) DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0'))),
                            ],
                            decoration: const InputDecoration(labelText: '开始·小时', prefixIcon: Icon(Icons.bedtime_outlined)),
                            onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _startHour = v ?? 8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _startMinute,
                            items: [
                              for (final m in minutes) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))),
                            ],
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
                            onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _endHour = v ?? 22),
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
                            : const Icon(Icons.water_drop_outlined),
                        label: Text(_submitting ? '提交中…' : '创建喝水提醒'),
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
                    Text('暂无记录（示例）', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.water_drop_outlined),
                      title: const Text('喝水提醒'),
                      subtitle: const Text('目标 1500ml · 间隔 60 分钟\n时段 08:00 - 22:00'),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: '修改',
                            onPressed: () => _editExampleRecord(
                              _WaterReminderRecord(
                                id: -1,
                                elderProfileId: _elderProfileIdOrNull() ?? 0,
                                title: '喝水提醒',
                                dailyTargetMl: 1500,
                                intervalMinutes: 60,
                                startTimeText: '08:00:00',
                                endTimeText: '22:00:00',
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(tooltip: '删除', onPressed: _deleteExampleRecord, icon: const Icon(Icons.delete_outline)),
                        ],
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.water_drop_outlined),
                      title: const Text('喝水提醒'),
                      subtitle: const Text('目标 1800ml · 间隔 90 分钟\n时段 09:00 - 21:00'),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: '修改',
                            onPressed: () => _editExampleRecord(
                              _WaterReminderRecord(
                                id: -2,
                                elderProfileId: _elderProfileIdOrNull() ?? 0,
                                title: '喝水提醒',
                                dailyTargetMl: 1800,
                                intervalMinutes: 90,
                                startTimeText: '09:00:00',
                                endTimeText: '21:00:00',
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(tooltip: '删除', onPressed: _deleteExampleRecord, icon: const Icon(Icons.delete_outline)),
                        ],
                      ),
                    ),
                  ] else ...[
                    for (final r in _records)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.water_drop_outlined),
                        title: const Text('喝水提醒'),
                        subtitle: Text('目标 ${r.dailyTargetMl}ml · 间隔 ${r.intervalMinutes} 分钟\n时段 ${r.startTimeText ?? '--'} - ${r.endTimeText ?? '--'}'),
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
}

final class _WaterReminderRecord {
  _WaterReminderRecord({
    required this.id,
    required this.elderProfileId,
    required this.title,
    required this.dailyTargetMl,
    required this.intervalMinutes,
    this.startTimeText,
    this.endTimeText,
  });

  final int id;
  final int elderProfileId;
  final String title;
  final int dailyTargetMl;
  final int intervalMinutes;
  final String? startTimeText;
  final String? endTimeText;

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

  static _WaterReminderRecord fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);
    return _WaterReminderRecord(
      id: asInt(json['id']),
      elderProfileId: asInt(json['elderProfileId'] ?? json['elder_profile_id']),
      title: (json['title'] ?? '').toString(),
      dailyTargetMl: asInt(json['dailyTargetMl'] ?? json['daily_target_ml'] ?? json['dailyTargetMl']),
      intervalMinutes: asInt(json['intervalMinutes'] ?? json['interval_minutes']),
      startTimeText: (json['startTime'] ?? json['start_time'])?.toString(),
      endTimeText: (json['endTime'] ?? json['end_time'])?.toString(),
    );
  }
}

