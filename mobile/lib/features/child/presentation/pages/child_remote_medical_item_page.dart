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

  final List<_MedicineScheduleRow> _rows = [];
  List<_MedicineReminderRecord> _records = const [];
  bool _loadingRecords = false;

  String? _selectedElderId;
  bool _enabled = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.elders.isNotEmpty) {
      _selectedElderId = widget.elders.first.id;
    }
    final base = DateTime.now().add(const Duration(hours: 1));
    _rows.add(
      _MedicineScheduleRow(
        medicineNameCtrl: TextEditingController(),
        dosageCtrl: TextEditingController(text: '1片'),
        frequencyCtrl: TextEditingController(text: 'daily'),
        repeatRuleCtrl: TextEditingController(text: 'none'),
        date: DateTime(base.year, base.month, base.day),
        hour: base.hour,
        minute: base.minute,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickRowDate(int index) async {
    final now = DateTime.now();
    final row = _rows[index];
    final initialDate = DateTime(row.date.year, row.date.month, row.date.day);
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate,
    );
    if (pickedDate == null) return;
    setState(() => _rows[index].date = DateTime(pickedDate.year, pickedDate.month, pickedDate.day));
  }

  String _fmtDateTime(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  void _addMedicineRow() {
    setState(() {
      final base = DateTime.now().add(const Duration(hours: 1));
      _rows.add(
        _MedicineScheduleRow(
          medicineNameCtrl: TextEditingController(),
          dosageCtrl: TextEditingController(text: '1片'),
          frequencyCtrl: TextEditingController(text: 'daily'),
          repeatRuleCtrl: TextEditingController(text: 'none'),
          date: DateTime(base.year, base.month, base.day),
          hour: base.hour,
          minute: base.minute,
        ),
      );
    });
  }

  void _removeMedicineRowAt(int index) {
    setState(() {
      if (_rows.length <= 1) return;
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  int? _elderProfileIdOrNull() {
    final id = _selectedElderId;
    if (id == null || id.isEmpty) return null;
    final n = int.tryParse(id);
    if (n == null || n <= 0) return null;
    return n;
  }

  Future<void> _loadRecords() async {
    final elderProfileId = _elderProfileIdOrNull();
    if (elderProfileId == null) return;
    setState(() => _loadingRecords = true);
    try {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/v1/child/medicine-reminders',
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
      final list = (api.data ?? const <Map<String, dynamic>>[]).map(_MedicineReminderRecord.fromJson).toList();
      if (!mounted) return;
      setState(() => _records = list);
    } catch (e) {
      // 不向用户暴露后端错误；保留当前列表状态即可
    } finally {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  Future<void> _deleteRecord(_MedicineReminderRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除提醒'),
        content: Text('确定删除「${r.medicineName}」这条提醒吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.dio.delete<Map<String, dynamic>>('/v1/child/medicine-reminders/${r.id}');
      if (!mounted) return;
      await _loadRecords();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  Future<void> _editRecord(_MedicineReminderRecord r) async {
    final medCtrl = TextEditingController(text: r.medicineName);
    final dosageCtrl = TextEditingController(text: r.dosage ?? '');
    final freq = ValueNotifier<String>(r.frequencyRule ?? 'none');
    final repeat = ValueNotifier<String>(r.repeatRule ?? 'none');
    DateTime remindAt = r.remindTime.toLocal();
    int hour = remindAt.hour;
    int minute = remindAt.minute;

    Future<void> pickDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
        initialDate: DateTime(remindAt.year, remindAt.month, remindAt.day),
      );
      if (picked == null) return;
      remindAt = DateTime(picked.year, picked.month, picked.day, hour, minute);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('修改提醒'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: medCtrl, decoration: const InputDecoration(labelText: '药品名称')),
                const SizedBox(height: 8),
                TextField(controller: dosageCtrl, decoration: const InputDecoration(labelText: '剂量（可选）')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('日期'),
                  subtitle: Text('${remindAt.year}-${remindAt.month.toString().padLeft(2, '0')}-${remindAt.day.toString().padLeft(2, '0')}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await pickDate();
                      setDialog(() {});
                    },
                    child: const Text('选择'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: hour,
                        items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0')))],
                        decoration: const InputDecoration(labelText: '小时'),
                        onChanged: (v) => setDialog(() {
                          if (v == null) return;
                          hour = v;
                          remindAt = DateTime(remindAt.year, remindAt.month, remindAt.day, hour, minute);
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: minute,
                        items: [for (var m = 0; m < 60; m++) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))],
                        decoration: const InputDecoration(labelText: '分钟'),
                        onChanged: (v) => setDialog(() {
                          if (v == null) return;
                          minute = v;
                          remindAt = DateTime(remindAt.year, remindAt.month, remindAt.day, hour, minute);
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: freq,
                  builder: (context, v, _) => DropdownButtonFormField<String>(
                    value: v,
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('每天')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周')),
                      DropdownMenuItem(value: 'none', child: Text('不重复')),
                    ],
                    decoration: const InputDecoration(labelText: '服用频率'),
                    onChanged: (nv) => freq.value = nv ?? 'none',
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: repeat,
                  builder: (context, v, _) => DropdownButtonFormField<String>(
                    value: v,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('不重复')),
                      DropdownMenuItem(value: 'daily', child: Text('每天')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周')),
                    ],
                    decoration: const InputDecoration(labelText: '提醒重复规则'),
                    onChanged: (nv) => repeat.value = nv ?? 'none',
                  ),
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
        '/v1/child/medicine-reminders/${r.id}',
        data: {
          'title': medCtrl.text.trim(),
          'medicineName': medCtrl.text.trim(),
          'dosage': dosageCtrl.text.trim().isEmpty ? null : dosageCtrl.text.trim(),
          'frequencyRule': freq.value,
          'repeatRule': repeat.value,
          'remindTime': remindAt.toUtc().toIso8601String(),
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
      medCtrl.dispose();
      dosageCtrl.dispose();
      freq.dispose();
      repeat.dispose();
    }
  }

  Future<void> _editExampleRecord(_MedicineReminderRecord r) async {
    final medCtrl = TextEditingController(text: r.medicineName);
    final dosageCtrl = TextEditingController(text: r.dosage ?? '');
    final freq = ValueNotifier<String>(r.frequencyRule ?? 'none');
    final repeat = ValueNotifier<String>(r.repeatRule ?? 'none');
    DateTime remindAt = r.remindTime.toLocal();
    int hour = remindAt.hour;
    int minute = remindAt.minute;

    Future<void> pickDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
        initialDate: DateTime(remindAt.year, remindAt.month, remindAt.day),
      );
      if (picked == null) return;
      remindAt = DateTime(picked.year, picked.month, picked.day, hour, minute);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('修改提醒（示例）'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: medCtrl, decoration: const InputDecoration(labelText: '药品名称')),
                const SizedBox(height: 8),
                TextField(controller: dosageCtrl, decoration: const InputDecoration(labelText: '剂量（可选）')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('日期'),
                  subtitle: Text('${remindAt.year}-${remindAt.month.toString().padLeft(2, '0')}-${remindAt.day.toString().padLeft(2, '0')}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await pickDate();
                      setDialog(() {});
                    },
                    child: const Text('选择'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: hour,
                        items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0')))],
                        decoration: const InputDecoration(labelText: '小时'),
                        onChanged: (v) => setDialog(() {
                          if (v == null) return;
                          hour = v;
                          remindAt = DateTime(remindAt.year, remindAt.month, remindAt.day, hour, minute);
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: minute,
                        items: [for (var m = 0; m < 60; m++) DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))],
                        decoration: const InputDecoration(labelText: '分钟'),
                        onChanged: (v) => setDialog(() {
                          if (v == null) return;
                          minute = v;
                          remindAt = DateTime(remindAt.year, remindAt.month, remindAt.day, hour, minute);
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: freq,
                  builder: (context, v, _) => DropdownButtonFormField<String>(
                    value: v,
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('每天')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周')),
                      DropdownMenuItem(value: 'none', child: Text('不重复')),
                    ],
                    decoration: const InputDecoration(labelText: '服用频率'),
                    onChanged: (nv) => freq.value = nv ?? 'none',
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: repeat,
                  builder: (context, v, _) => DropdownButtonFormField<String>(
                    value: v,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('不重复')),
                      DropdownMenuItem(value: 'daily', child: Text('每天')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周')),
                    ],
                    decoration: const InputDecoration(labelText: '提醒重复规则'),
                    onChanged: (nv) => repeat.value = nv ?? 'none',
                  ),
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

    medCtrl.dispose();
    dosageCtrl.dispose();
    freq.dispose();
    repeat.dispose();

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先开启吃药提醒')));
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
      var ok = 0;
      Object? firstErr;

      for (final row in _rows) {
        final med = row.medicineNameCtrl.text.trim();
        final dosage = row.dosageCtrl.text.trim().isEmpty ? null : row.dosageCtrl.text.trim();
        final frequencyRule = row.frequencyCtrl.text.trim().isEmpty ? 'none' : row.frequencyCtrl.text.trim();
        final repeatRule = row.repeatRuleCtrl.text.trim().isEmpty ? 'none' : row.repeatRuleCtrl.text.trim();
        final remindAt = DateTime(row.date.year, row.date.month, row.date.day, row.hour, row.minute);
        try {
          final res = await ApiClient.dio.post<Map<String, dynamic>>(
            '/v1/child/medicine-reminders',
            data: {
              'elderProfileId': elderProfileId,
              'title': med,
              'sourceType': 'child_remote',
              'relatedEventId': null,
              'remindTime': remindAt.toUtc().toIso8601String(),
              'medicineName': med,
              'dosage': dosage,
              'frequencyRule': frequencyRule,
              'repeatRule': repeatRule,
              'status': 'pending',
              'createdBy': 'child',
            },
          );
          final body = res.data;
          if (body == null) throw Exception('空响应');
          final api = ApiResponse.fromJson(body, (raw) => raw);
          if (!api.isSuccess) throw Exception(api.message);
          ok++;
        } catch (e) {
          firstErr ??= e;
        }
      }

      if (!mounted) return;
      if (ok == 0) {
        throw firstErr ?? Exception('创建失败');
      }
      final suffix = firstErr == null ? '' : '（部分失败，请检查网络或后端接口）';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已创建 $ok 条吃药提醒$suffix')));
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
                  Text('吃药提醒', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '为老人设置按时吃药提醒（医疗界面）。',
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
                    onChanged: _submitting || !_enabled || elders.isEmpty ? null : (v) => setState(() => _selectedElderId = v),
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
                    subtitle: Text(_enabled ? '每种药可设置不同提醒时间（批量创建）' : '关闭后不创建提醒'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
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
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('药品与提醒时间（每种药一行）', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _submitting || !_enabled || elders.isEmpty ? null : _addMedicineRow,
                          icon: const Icon(Icons.add),
                          label: const Text('添加药品'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _rows.length; i++) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: i == _rows.length - 1 ? 0 : 16),
                        child: Card(
                          elevation: 0,
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '药品 ${i + 1}',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '删除该药品',
                                      onPressed: _submitting || !_enabled || elders.isEmpty || _rows.length <= 1 ? null : () => _removeMedicineRowAt(i),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _rows[i].medicineNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '药品名称',
                                    hintText: '请手动输入药品名称',
                                    prefixIcon: Icon(Icons.medication_outlined),
                                  ),
                                  maxLength: 100,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
                                  enabled: !_submitting && _enabled && elders.isNotEmpty,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _rows[i].dosageCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '剂量（可选）',
                                    hintText: '如：1片 / 5ml',
                                    prefixIcon: Icon(Icons.science_outlined),
                                  ),
                                  maxLength: 50,
                                  enabled: !_submitting && _enabled && elders.isNotEmpty,
                                ),
                                const SizedBox(height: 8),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.calendar_today_outlined),
                                  title: const Text('提醒日期'),
                                  subtitle: Text(
                                    '${_rows[i].date.year.toString().padLeft(4, '0')}-${_rows[i].date.month.toString().padLeft(2, '0')}-${_rows[i].date.day.toString().padLeft(2, '0')}',
                                  ),
                                  trailing: TextButton(
                                    onPressed: _submitting || !_enabled || elders.isEmpty ? null : () => _pickRowDate(i),
                                    child: const Text('选择'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        value: _rows[i].hour,
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
                                        onChanged: _submitting || !_enabled || elders.isEmpty
                                            ? null
                                            : (v) {
                                                if (v == null) return;
                                                setState(() => _rows[i].hour = v);
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        value: _rows[i].minute,
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
                                        onChanged: _submitting || !_enabled || elders.isEmpty
                                            ? null
                                            : (v) {
                                                if (v == null) return;
                                                setState(() => _rows[i].minute = v);
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '预览：${_fmtDateTime(DateTime(_rows[i].date.year, _rows[i].date.month, _rows[i].date.day, _rows[i].hour, _rows[i].minute))}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _rows[i].frequencyCtrl.text.trim().isEmpty ? 'daily' : _rows[i].frequencyCtrl.text.trim(),
                                  items: const [
                                    DropdownMenuItem(value: 'daily', child: Text('每天')),
                                    DropdownMenuItem(value: 'weekly', child: Text('每周')),
                                    DropdownMenuItem(value: 'none', child: Text('不重复')),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: '服用频率',
                                    prefixIcon: Icon(Icons.event_repeat_outlined),
                                  ),
                                  onChanged: _submitting || !_enabled || elders.isEmpty
                                      ? null
                                      : (v) {
                                          if (v == null) return;
                                          setState(() => _rows[i].frequencyCtrl.text = v);
                                        },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _rows[i].repeatRuleCtrl.text.trim().isEmpty ? 'none' : _rows[i].repeatRuleCtrl.text.trim(),
                                  items: const [
                                    DropdownMenuItem(value: 'none', child: Text('不重复')),
                                    DropdownMenuItem(value: 'daily', child: Text('每天')),
                                    DropdownMenuItem(value: 'weekly', child: Text('每周')),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: '提醒重复规则',
                                    prefixIcon: Icon(Icons.repeat),
                                  ),
                                  onChanged: _submitting || !_enabled || elders.isEmpty
                                      ? null
                                      : (v) {
                                          if (v == null) return;
                                          setState(() => _rows[i].repeatRuleCtrl.text = v);
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        label: Text(_submitting ? '提交中…' : '批量创建吃药提醒'),
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
                      leading: const Icon(Icons.medication_outlined),
                      title: const Text('阿司匹林'),
                      subtitle: const Text('饭后服用\n2026-04-18 08:00'),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: '修改',
                            onPressed: () => _editExampleRecord(
                              _MedicineReminderRecord(
                                id: -1,
                                elderProfileId: _elderProfileIdOrNull() ?? 0,
                                title: '阿司匹林',
                                medicineName: '阿司匹林',
                                remindTime: DateTime(2026, 4, 18, 8, 0),
                                dosage: '1片',
                                frequencyRule: 'daily',
                                repeatRule: 'daily',
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
                      leading: const Icon(Icons.medication_outlined),
                      title: const Text('降压药'),
                      subtitle: const Text('早晚各一次\n2026-04-18 20:00'),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: '修改',
                            onPressed: () => _editExampleRecord(
                              _MedicineReminderRecord(
                                id: -2,
                                elderProfileId: _elderProfileIdOrNull() ?? 0,
                                title: '降压药',
                                medicineName: '降压药',
                                remindTime: DateTime(2026, 4, 18, 20, 0),
                                dosage: '1片',
                                frequencyRule: 'daily',
                                repeatRule: 'daily',
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
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(r.medicineName),
                        subtitle: Text(_fmtDateTime(r.remindTime.toLocal())),
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

final class _MedicineReminderRecord {
  _MedicineReminderRecord({
    required this.id,
    required this.elderProfileId,
    required this.title,
    required this.medicineName,
    required this.remindTime,
    this.dosage,
    this.frequencyRule,
    this.repeatRule,
  });

  final int id;
  final int elderProfileId;
  final String title;
  final String medicineName;
  final DateTime remindTime;
  final String? dosage;
  final String? frequencyRule;
  final String? repeatRule;

  static _MedicineReminderRecord fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);
    final id = asInt(json['id']);
    final elderProfileId = asInt(json['elderProfileId'] ?? json['elder_profile_id']);
    final title = (json['title'] ?? '').toString();
    final medicineName = (json['medicineName'] ?? json['medicine_name'] ?? '').toString();
    final remindRaw = (json['remindTime'] ?? json['remind_time'])?.toString();
    final remindTime = remindRaw == null ? DateTime.now() : DateTime.tryParse(remindRaw)?.toLocal() ?? DateTime.now();
    return _MedicineReminderRecord(
      id: id,
      elderProfileId: elderProfileId,
      title: title,
      medicineName: medicineName,
      remindTime: remindTime,
      dosage: json['dosage']?.toString(),
      frequencyRule: (json['frequencyRule'] ?? json['frequency_rule'])?.toString(),
      repeatRule: (json['repeatRule'] ?? json['repeat_rule'])?.toString(),
    );
  }
}

final class _MedicineScheduleRow {
  _MedicineScheduleRow({
    required this.medicineNameCtrl,
    required this.dosageCtrl,
    required this.frequencyCtrl,
    required this.repeatRuleCtrl,
    required this.date,
    required this.hour,
    required this.minute,
  });

  final TextEditingController medicineNameCtrl;
  final TextEditingController dosageCtrl;
  final TextEditingController frequencyCtrl;
  final TextEditingController repeatRuleCtrl;
  DateTime date;
  int hour;
  int minute;

  void dispose() {
    medicineNameCtrl.dispose();
    dosageCtrl.dispose();
    frequencyCtrl.dispose();
    repeatRuleCtrl.dispose();
  }
}

