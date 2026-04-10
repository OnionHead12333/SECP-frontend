import 'package:flutter/material.dart';

import '../../elder/presentation/elder_register_page.dart';
import '../data/auth_api.dart';
import 'auth_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

enum _RegisterFlow { chooseRole, childForm }

class _RegisterPageState extends State<RegisterPage> {
  final _childNameCtrl = TextEditingController();
  final _childNicknameCtrl = TextEditingController();
  final _childPhoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  final List<_ElderForm> _elders = [_ElderForm()];

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;
  bool _agree = false;
  String? _error;
  _RegisterFlow _flow = _RegisterFlow.chooseRole;

  @override
  void dispose() {
    _childNameCtrl.dispose();
    _childNicknameCtrl.dispose();
    _childPhoneCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    for (final e in _elders) {
      e.dispose();
    }
    super.dispose();
  }

  String? _validateChild() {
    final childName = _childNameCtrl.text.trim();
    final childNickname = _childNicknameCtrl.text.trim();
    final childPhone = _childPhoneCtrl.text.trim();
    if (childName.isEmpty) return '请输入子女姓名';
    if (childNickname.isEmpty) return '请输入子女昵称';
    if (childPhone.isEmpty) return '请输入子女手机号';
    if (childPhone.length < 11) return '子女手机号格式不正确';
    if (_pwdCtrl.text.isEmpty) return '请输入密码';
    if (_pwdCtrl.text.length < 6) return '密码至少 6 位';
    if (_pwdCtrl.text != _pwd2Ctrl.text) return '两次密码不一致';
    if (!_agree) return '请先勾选并同意协议';
    return null;
  }

  String? _validateElders() {
    final phones = <String>{};
    for (var i = 0; i < _elders.length; i++) {
      final form = _elders[i];
      final name = form.nameCtrl.text.trim();
      final phone = form.phoneCtrl.text.trim();
      final relation = form.relationCtrl.text.trim();
      if (name.isEmpty) return '请填写老人主体 ${i + 1} 的姓名';
      if (phone.isEmpty) return '请填写老人主体 ${i + 1} 的手机号';
      if (phone.length < 11) return '老人主体 ${i + 1} 的手机号格式不正确';
      if (!phones.add(phone)) return '老人手机号不能重复';
      if (relation.isEmpty) return '请填写老人主体 ${i + 1} 的关系';
    }
    return null;
  }

  Future<void> _submitChild() async {
    final err = _validateChild();
    setState(() => _error = err);
    if (err != null) return;
    await _openEldersSheet();
  }

  Future<void> _submitChildWithElders() async {
    final err = _validateElders();
    setState(() => _error = err);
    if (err != null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final elders = _elders
          .map(
            (e) => <String, String>{
              'name': e.nameCtrl.text.trim(),
              'phone': e.phoneCtrl.text.trim(),
              'relation': e.relationCtrl.text.trim(),
            },
          )
          .toList(growable: false);
      await AuthApi.registerChildWithElders(
        childName: _childNameCtrl.text.trim(),
        childNickname: _childNicknameCtrl.text.trim(),
        childPhone: _childPhoneCtrl.text.trim(),
        password: _pwdCtrl.text,
        elders: elders,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('注册成功，请登录')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openEldersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('老人主体信息', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('可添加多位老人，后续可由老人本人注册认领。'),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      ..._elders.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ElderBlock(
                              index: entry.key,
                              form: entry.value,
                              canRemove: _elders.length > 1,
                              enabled: !_submitting,
                              onRemove: () => setState(() => _elders.removeAt(entry.key)),
                            ),
                          )),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: _submitting ? null : () => setState(() => _elders.add(_ElderForm())),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('新增老人主体'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting ? null : () async {
                    final err = _validateElders();
                    setState(() => _error = err);
                    if (err != null) return;
                    Navigator.of(ctx).pop();
                    await _submitChildWithElders();
                  },
                  child: const Text('提交注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _goToElderRegister() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ElderRegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_flow == _RegisterFlow.chooseRole) {
      return AuthShell(
        title: '注册',
        subtitle: '请选择您要注册的账号类型',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoleEntryCard(
              icon: Icons.elderly_outlined,
              title: '注册老人端',
              description: '进入老人注册页，填写手机号、姓名并设置密码。',
              onTap: _goToElderRegister,
            ),
            const SizedBox(height: 14),
            _RoleEntryCard(
              icon: Icons.family_restroom_outlined,
              title: '注册子女端',
              description: '继续填写子女信息，并补充需要绑定的老人主体。',
              onTap: () => setState(() => _flow = _RegisterFlow.childForm),
            ),
          ],
        ),
        footer: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('已有账号？返回登录')),
      );
    }

    return AuthShell(
      title: '子女注册',
      subtitle: '填写子女信息，下一步继续补充老人主体。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _submitting ? null : () => setState(() => _flow = _RegisterFlow.chooseRole),
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              label: const Text('返回选择账号类型'),
            ),
          ),
          TextField(controller: _childNameCtrl, enabled: !_submitting, decoration: const InputDecoration(labelText: '子女姓名', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _childNicknameCtrl, enabled: !_submitting, decoration: const InputDecoration(labelText: '子女昵称', hintText: '用于展示', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _childPhoneCtrl, enabled: !_submitting, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '子女手机号', hintText: '用于登录与接收通知', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _pwdCtrl, enabled: !_submitting, obscureText: _obscure1, decoration: InputDecoration(labelText: '密码', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => _obscure1 = !_obscure1), icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
          const SizedBox(height: 16),
          TextField(controller: _pwd2Ctrl, enabled: !_submitting, obscureText: _obscure2, onSubmitted: (_) => _submitChild(), decoration: InputDecoration(labelText: '确认密码', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => _obscure2 = !_obscure2), icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          const SizedBox(height: 20),
          FilledButton(onPressed: _submitting ? null : _submitChild, child: const Text('下一步')),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agree,
            onChanged: _submitting ? null : (v) => setState(() => _agree = v ?? false),
            title: const Text('我已阅读并同意《用户协议》《隐私政策》', style: TextStyle(fontSize: 12)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      footer: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('已有账号？返回登录')),
    );
  }
}

class _RoleEntryCard extends StatelessWidget {
  const _RoleEntryCard({required this.icon, required this.title, required this.description, required this.onTap});
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD7E3F4))),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1D4ED8)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))])),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

final class _ElderForm {
  _ElderForm() : nameCtrl = TextEditingController(), phoneCtrl = TextEditingController(), relationCtrl = TextEditingController();
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController relationCtrl;
  void dispose() { nameCtrl.dispose(); phoneCtrl.dispose(); relationCtrl.dispose(); }
}

class _ElderBlock extends StatelessWidget {
  const _ElderBlock({required this.index, required this.form, required this.canRemove, required this.enabled, required this.onRemove});
  final int index;
  final _ElderForm form;
  final bool canRemove;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text('老人主体 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700))), if (canRemove) IconButton(onPressed: enabled ? onRemove : null, icon: const Icon(Icons.close))]),
          TextField(controller: form.nameCtrl, enabled: enabled, decoration: const InputDecoration(labelText: '老人姓名', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: form.phoneCtrl, enabled: enabled, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '老人手机号', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: form.relationCtrl, enabled: enabled, decoration: const InputDecoration(labelText: '与老人关系', hintText: '例如：父亲 / 母亲 / 外婆', border: OutlineInputBorder())),
        ]),
      ),
    );
  }
}
