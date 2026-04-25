import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_emergency_contacts_service.dart';
import '../models/elder_emergency_contact.dart';

class ElderEmergencyContactsPage extends StatefulWidget {
  const ElderEmergencyContactsPage({super.key});

  @override
  State<ElderEmergencyContactsPage> createState() => _ElderEmergencyContactsPageState();
}

class _ElderEmergencyContactsPageState extends State<ElderEmergencyContactsPage> {
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  List<ElderEmergencyContact> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loadError = null;
      _loading = true;
    });
    try {
      final contacts = await ElderEmergencyContactsService.fetchContacts(
        elderPhone: AuthSession.elderPhone ?? '',
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contacts = const [];
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openAddContact() async {
    final draft = await showModalBottomSheet<_ContactDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ContactEditorSheet(),
    );
    if (draft == null) return;
    setState(() => _busy = true);
    final contacts = await ElderEmergencyContactsService.addContact(
      elderPhone: AuthSession.elderPhone ?? '',
      name: draft.name,
      relation: draft.relation,
      contactPhone: draft.phone,
      note: draft.note,
      makePrimary: draft.isPrimary,
    );
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _busy = false;
    });
    _show('已新增紧急联系人');
  }

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('紧急联系人')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading || _busy ? null : _openAddContact,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('新增联系人'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadContacts,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  if (_loadError != null) ...[
                    Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '加载失败：$_loadError',
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _loadContacts,
                      child: const Text('重试'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _Header(phone: AuthSession.elderPhone ?? '-', count: _contacts.length),
                  const SizedBox(height: 16),
                  const _TipCard(),
                  const SizedBox(height: 16),
                  if (_loadError == null && _contacts.isEmpty)
                    const _EmptyCard()
                  else if (_loadError == null)
                    ..._contacts.map(
                      (contact) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ContactCard(contact: contact),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.phone, required this.count});

  final String phone;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFEFF6FF)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('当前账号紧急联系人', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('老人手机号：$phone'),
        const SizedBox(height: 8),
        Text('已登记 $count 位联系人，求助时将按优先级通知。', style: const TextStyle(color: Color(0xFF475569), height: 1.5)),
      ]),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFFAFAF9), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7E5E4))),
      child: const Text(
        '列表由登录账号从服务端拉取。可在此新增联系人，数据保存在服务器。',
        style: TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF44403C)),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: const Column(children: [
        Icon(Icons.contact_phone_outlined, size: 46, color: Color(0xFF64748B)),
        SizedBox(height: 12),
        Text('还没有紧急联系人', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text('可点击右下角新增首位联系人。', textAlign: TextAlign.center, style: TextStyle(height: 1.6, color: Color(0xFF475569))),
      ]),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final ElderEmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(contact.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          if (contact.isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(999)),
              child: const Text('主要联系人', style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 10),
        Text('关系：${contact.relation}'),
        const SizedBox(height: 6),
        Text('电话：${contact.phone}'),
        const SizedBox(height: 6),
        Text('备注：${contact.note.isEmpty ? '暂无备注' : contact.note}', style: const TextStyle(color: Color(0xFF64748B), height: 1.5)),
        const SizedBox(height: 14),
        const Text('老人端仅支持新增联系人，不支持在此编辑或删除。', style: TextStyle(color: Color(0xFF64748B), height: 1.5)),
      ]),
    );
  }
}

class _ContactEditorSheet extends StatefulWidget {
  const _ContactEditorSheet();

  @override
  State<_ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<_ContactEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _relationCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _noteCtrl;
  bool _isPrimary = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _relationCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relationCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final relation = _relationCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) return setState(() => _error = '请输入联系人姓名');
    if (relation.isEmpty) return setState(() => _error = '请输入关系');
    if (phone.length != 11) return setState(() => _error = '请输入 11 位手机号');
    Navigator.of(context).pop(_ContactDraft(name: name, relation: relation, phone: phone, note: _noteCtrl.text.trim(), isPrimary: _isPrimary));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('新增紧急联系人', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: '姓名', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 14),
            TextField(controller: _relationCtrl, decoration: InputDecoration(labelText: '关系', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 14),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: '手机号', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 14),
            TextField(controller: _noteCtrl, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: '备注', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            SwitchListTile.adaptive(value: _isPrimary, contentPadding: EdgeInsets.zero, title: const Text('设为主要联系人'), onChanged: (value) => setState(() => _isPrimary = value)),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _submit, child: const Text('确认新增'))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ContactDraft {
  const _ContactDraft({required this.name, required this.relation, required this.phone, required this.note, required this.isPrimary});

  final String name;
  final String relation;
  final String phone;
  final String note;
  final bool isPrimary;
}
