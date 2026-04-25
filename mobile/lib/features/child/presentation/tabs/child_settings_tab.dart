import 'package:flutter/material.dart';

import '../../data/child_api_error_text.dart';
import '../../data/child_elder_directory_service.dart';
import '../../data/child_emergency_contacts_api.dart';
import '../../models/child_local_models.dart';

/// 设置：老人列表（手动档案 ID + 求助记录发现）+ 紧急联系人走 `/v1/children/elders/...`。
class ChildSettingsTab extends StatefulWidget {
  const ChildSettingsTab({
    super.key,
    required this.elders,
    required this.onEldersChanged,
  });

  final List<BoundElder> elders;
  final Future<void> Function() onEldersChanged;

  @override
  State<ChildSettingsTab> createState() => _ChildSettingsTabState();
}

class _ChildSettingsTabState extends State<ChildSettingsTab> {
  bool _pushDemo = true;

  Future<void> _showBindElderDialog() async {
    // 在独立 [StatefulWidget] 内创建/释放 [TextEditingController]。
    // 在 [showDialog] 返回时立刻 dispose 会早于路由卸载完成，易触发
    // Framework `'_dependents.isEmpty': is not true` 断言。
    final result = await showDialog<_AddBoundElderResult?>(
      context: context,
      builder: (ctx) => const _AddBoundElderDialog(),
    );

    if (result == null || !mounted) return;
    if (result.id.isEmpty || int.tryParse(result.id) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写有效数字档案 ID')));
      return;
    }
    if (result.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写显示名称')));
      return;
    }

    await ChildElderDirectoryService.saveManualElder(
      elderId: result.id,
      displayName: result.name,
      hint: result.hint,
    );
    if (!mounted) return;
    // 等当前帧/弹层卸载后再刷新整页，避免与父级 [setState] 抢同一帧
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await widget.onEldersChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存，列表已更新')));
    }
  }

  Future<void> _confirmUnbindOrHide(BoundElder e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从本机列表移除'),
        content: Text(
          e.accountHint == '来自求助记录'
              ? '此老人由求助记录发现，将仅从本机隐藏；不影响后端绑定关系。'
              : '将删除您手动添加的该老人项。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    if (e.accountHint == '来自求助记录') {
      await ChildElderDirectoryService.hideElder(e.id);
    } else {
      await ChildElderDirectoryService.removeManualElder(e.id);
    }
    if (!mounted) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await widget.onEldersChanged();
  }

  int _defaultPriorityForNewContact(List<EmergencyContact> list) {
    if (list.isEmpty) return 1;
    final p = list.map((c) => c.priority).reduce((a, b) => a > b ? a : b);
    return p + 1;
  }

  List<EmergencyContact> _sorted(List<EmergencyContact> list) {
    final copy = [...list]..sort((a, b) => a.priority.compareTo(b.priority));
    return copy;
  }

  Future<void> _showContactEditor({
    required int elderId,
    EmergencyContact? existing,
    required Future<void> Function() onChanged,
  }) async {
    var defaultPriority = 1;
    if (existing == null) {
      try {
        final l = await ChildEmergencyContactsApi.list(elderId);
        defaultPriority = _defaultPriorityForNewContact(l);
      } catch (_) {}
    }

    if (!mounted) return;

    final result = await showDialog<_EmergencyContactEditorResult?>(
      context: context,
      builder: (ctx) => _EmergencyContactEditorDialog(
        existing: existing,
        defaultPriorityForNew: defaultPriority,
      ),
    );

    if (result == null || !mounted) return;

    try {
      if (existing == null) {
        await ChildEmergencyContactsApi.add(
          elderId: elderId,
          name: result.name,
          phone: result.phone,
          priority: result.priority,
          relation: result.relation.isEmpty ? '联系人' : result.relation,
        );
      } else {
        await ChildEmergencyContactsApi.update(
          elderId: elderId,
          contactId: int.parse(existing.id),
          name: result.name,
          phone: result.phone,
          priority: result.priority,
          relation: result.relation.isEmpty ? '联系人' : result.relation,
        );
      }
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      await onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已同步到服务器')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败，请稍后再试')));
      }
    }
  }

  Future<void> _removeContact(
    int elderId,
    EmergencyContact c,
    void Function() setModal,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除「${c.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ChildEmergencyContactsApi.delete(elderId: elderId, contactId: int.parse(c.id));
      setModal();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    }
  }

  void _openEmergencyContactsSheet(BoundElder e) {
    final eid = int.tryParse(e.id);
    if (eid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('老人档案 ID 无效，请重新添加数字 ID')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxH = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SizedBox(
            height: maxH,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final refreshKey = <int>[0];
                return FutureBuilder<List<EmergencyContact>>(
                  key: ValueKey(refreshKey[0]),
                  future: ChildEmergencyContactsApi.list(eid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_tethering_error_rounded, size: 40, color: Theme.of(context).colorScheme.error),
                              const SizedBox(height: 12),
                              Text(
                                '无法加载紧急联系人',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                describeChildApiError(snap.error),
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.tonal(
                                onPressed: () {
                                  refreshKey[0]++;
                                  setModalState(() {});
                                },
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final list = _sorted(snap.data ?? const []);
                    void bump() {
                      refreshKey[0]++;
                      setModalState(() {});
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(sheetContext),
                                tooltip: '关闭',
                              ),
                              Expanded(
                                child: Text(
                                  '${e.displayName} · 紧急联系人',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: () async {
                                  await _showContactEditor(
                                    elderId: eid,
                                    onChanged: () async {
                                      bump();
                                    },
                                  );
                                },
                                child: const Text('添加'),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: list.isEmpty
                              ? Center(
                                  child: Text(
                                    '暂无紧急联系人\n可在此添加，数据保存在服务端',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                                  itemBuilder: (context, i) {
                                    final c = list[i];
                                    return Card(
                                      margin: EdgeInsets.zero,
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                          child: Text(
                                            '${c.priority}',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        title: Text(c.name),
                                        subtitle: Text('${c.phone}${c.relation != null ? ' · ${c.relation}' : ''}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined),
                                              tooltip: '编辑',
                                              onPressed: () async {
                                                await _showContactEditor(
                                                  elderId: eid,
                                                  existing: c,
                                                  onChanged: () async {
                                                    bump();
                                                  },
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              tooltip: '删除',
                                              onPressed: () async {
                                                await _removeContact(
                                                  eid,
                                                  c,
                                                  bump,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        Text('老人', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
          '老人列表 = 本机保存的档案 ID + 求助记录中自动出现的已绑定老人',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ...widget.elders.map(
          (e) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                    leading: const CircleAvatar(child: Icon(Icons.elderly)),
                    title: Text(e.displayName),
                    subtitle: Text(e.accountHint == null || e.accountHint!.isEmpty ? '档案 ID：${e.id}' : '${e.id} · ${e.accountHint}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.link_off_outlined),
                      tooltip: '移除',
                      onPressed: () => _confirmUnbindOrHide(e),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: OutlinedButton.icon(
                      onPressed: () => _openEmergencyContactsSheet(e),
                      icon: const Icon(Icons.contact_phone_outlined),
                      label: const Text('管理紧急联系人'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _showBindElderDialog,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('添加老人档案 ID'),
          ),
        ),
        const SizedBox(height: 24),
        Text('其他', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('预警推送'),
                subtitle: const Text('本版本仍为演示开关，未接推送服务'),
                value: _pushDemo,
                onChanged: (v) {
                  setState(() => _pushDemo = v);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(v ? '已开启（演示）' : '已关闭（演示）')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.hexagon_outlined),
                title: const Text('地理围栏（家）'),
                subtitle: const Text('安全页已尝试读取家围栏用于参考路线'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('围栏详情可在后端 home-geofence 接口中配置')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmergencyContactEditorResult {
  const _EmergencyContactEditorResult({
    required this.name,
    required this.phone,
    required this.priority,
    required this.relation,
  });

  final String name;
  final String phone;
  final int priority;
  final String relation;
}

class _EmergencyContactEditorDialog extends StatefulWidget {
  const _EmergencyContactEditorDialog({
    this.existing,
    required this.defaultPriorityForNew,
  });

  final EmergencyContact? existing;
  final int defaultPriorityForNew;

  @override
  State<_EmergencyContactEditorDialog> createState() => _EmergencyContactEditorDialogState();
}

class _EmergencyContactEditorDialogState extends State<_EmergencyContactEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _priorityCtrl;
  late final TextEditingController _relCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _relCtrl = TextEditingController(text: e?.relation ?? '');
    _priorityCtrl = TextEditingController(
      text: e != null ? e.priority.toString() : widget.defaultPriorityForNew.toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _priorityCtrl.dispose();
    _relCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final rel = _relCtrl.text.trim();
    final priorityRaw = _priorityCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写姓名与手机号')));
      return;
    }
    if (phone.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效手机号')));
      return;
    }
    final priority = int.tryParse(priorityRaw);
    if (priority == null || priority < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效优先级（≥1）')));
      return;
    }
    Navigator.pop(
      context,
      _EmergencyContactEditorResult(
        name: name,
        phone: phone,
        priority: priority,
        relation: rel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(isNew ? '添加紧急联系人' : '编辑紧急联系人'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '姓名', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priorityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '优先级',
                hintText: '正整数，越小越优先',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relCtrl,
              decoration: const InputDecoration(
                labelText: '关系',
                hintText: '如：儿子、邻居',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _AddBoundElderResult {
  const _AddBoundElderResult({required this.id, required this.name, this.hint});

  final String id;
  final String name;
  final String? hint;
}

class _AddBoundElderDialog extends StatefulWidget {
  const _AddBoundElderDialog();

  @override
  State<_AddBoundElderDialog> createState() => _AddBoundElderDialogState();
}

class _AddBoundElderDialogState extends State<_AddBoundElderDialog> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hintCtrl;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _hintCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加关注老人'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('填写老人档案 ID（与后台 elder_profile_id 一致，数字）', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _idCtrl,
              decoration: const InputDecoration(
                labelText: '老人档案 ID',
                hintText: '数字',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '显示名称',
                hintText: '如：张奶奶',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hintCtrl,
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final hint = _hintCtrl.text.trim();
            Navigator.pop(
              context,
              _AddBoundElderResult(
                id: _idCtrl.text.trim(),
                name: _nameCtrl.text.trim(),
                hint: hint.isEmpty ? null : hint,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
