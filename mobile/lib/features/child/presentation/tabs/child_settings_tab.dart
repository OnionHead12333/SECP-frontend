import 'package:flutter/material.dart';

import '../../models/child_local_models.dart';

/// ④ 设置：绑定/解绑老人；每位老人独立「紧急联系人」入口，在底部弹层中查看与管理（其余开关类可后续补）。
class ChildSettingsTab extends StatefulWidget {
  const ChildSettingsTab({
    super.key,
    required this.elders,
    required this.contacts,
    required this.onAddElder,
    required this.onRemoveElder,
    required this.onAddContact,
    required this.onUpdateContact,
    required this.onRemoveContact,
  });

  final List<BoundElder> elders;
  final List<EmergencyContact> contacts;
  final void Function(BoundElder e) onAddElder;
  final void Function(String id) onRemoveElder;
  final void Function(EmergencyContact c) onAddContact;
  final void Function(EmergencyContact c) onUpdateContact;
  final void Function(String id) onRemoveContact;

  @override
  State<ChildSettingsTab> createState() => _ChildSettingsTabState();
}

class _ChildSettingsTabState extends State<ChildSettingsTab> {
  bool _pushDemo = true;

  Future<void> _showBindElderDialog() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final hintCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('绑定老人账号'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: '老人账号 / ID',
                  hintText: '手机号或平台用户 ID',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '显示名称',
                  hintText: '如：张奶奶',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hintCtrl,
                decoration: const InputDecoration(
                  labelText: '备注（选填）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('绑定')),
        ],
      ),
    );

    final id = idCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final hint = hintCtrl.text.trim();
    idCtrl.dispose();
    nameCtrl.dispose();
    hintCtrl.dispose();

    if (ok != true || !mounted) return;
    if (id.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写老人账号与显示名称')));
      return;
    }

    widget.onAddElder(
      BoundElder(
        id: id,
        displayName: name,
        accountHint: hint.isEmpty ? null : hint,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已绑定 $name（本地演示）')));
  }

  Future<void> _confirmUnbind(BoundElder e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解绑老人'),
        content: Text('确定解绑「${e.displayName}」？解绑后将无法查看该老人相关数据。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('解绑')),
        ],
      ),
    );
    if (yes == true && mounted) {
      widget.onRemoveElder(e.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已解绑 ${e.displayName}')));
    }
  }

  int _contactCountFor(String elderId) =>
      widget.contacts.where((c) => c.elderId == elderId).length;

  Future<void> _showContactEditor({
    required String elderId,
    EmergencyContact? existing,
    VoidCallback? onChanged,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final relCtrl = TextEditingController(text: existing?.relation ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '添加紧急联系人' : '编辑紧急联系人'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '姓名', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relCtrl,
                decoration: const InputDecoration(
                  labelText: '关系（选填）',
                  hintText: '如：儿子、邻居',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final rel = relCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    relCtrl.dispose();

    if (ok != true || !mounted) return;
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写姓名与手机号')));
      return;
    }
    if (phone.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效手机号')));
      return;
    }

    if (existing == null) {
      widget.onAddContact(
        EmergencyContact(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}',
          elderId: elderId,
          name: name,
          phone: phone,
          relation: rel.isEmpty ? null : rel,
        ),
      );
    } else {
      widget.onUpdateContact(
        EmergencyContact(
          id: existing.id,
          elderId: existing.elderId,
          name: name,
          phone: phone,
          relation: rel.isEmpty ? null : rel,
        ),
      );
    }
    onChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存联系人')));
    }
  }

  Future<void> _confirmRemoveContact(EmergencyContact c, {VoidCallback? onChanged}) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除紧急联系人「${c.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (yes == true && mounted) {
      widget.onRemoveContact(c.id);
      onChanged?.call();
    }
  }

  void _openEmergencyContactsSheet(BoundElder e) {
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
                final list = widget.contacts.where((c) => c.elderId == e.id).toList();

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
                                elderId: e.id,
                                onChanged: () => setModalState(() {}),
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
                                '暂无紧急联系人\n点击「添加」由子女维护',
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
                                    leading: const Icon(Icons.contact_phone_outlined),
                                    title: Text(c.name),
                                    subtitle: Text(
                                      '${c.phone}${c.relation != null ? ' · ${c.relation}' : ''}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: '编辑',
                                          onPressed: () async {
                                            await _showContactEditor(
                                              elderId: e.id,
                                              existing: c,
                                              onChanged: () => setModalState(() {}),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          tooltip: '删除',
                                          onPressed: () async {
                                            await _confirmRemoveContact(
                                              c,
                                              onChanged: () => setModalState(() {}),
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
        Text('老人账号', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...widget.elders.map(
          (e) {
            final n = _contactCountFor(e.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                    leading: const CircleAvatar(child: Icon(Icons.elderly)),
                    title: Text(e.displayName),
                    subtitle: Text(e.accountHint ?? '账号：${e.id}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.link_off_outlined),
                      tooltip: '解绑',
                      onPressed: () => _confirmUnbind(e),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: OutlinedButton.icon(
                      onPressed: () => _openEmergencyContactsSheet(e),
                      icon: const Icon(Icons.contact_phone_outlined),
                      label: Text(n > 0 ? '紧急联系人（$n）' : '紧急联系人'),
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
            label: const Text('绑定老人账号'),
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
                subtitle: const Text('异常与求助消息推送（演示开关，未持久化）'),
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
                title: const Text('地理围栏设置'),
                subtitle: const Text('围栏半径与生效时段'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('地理围栏页面待开发')),
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
