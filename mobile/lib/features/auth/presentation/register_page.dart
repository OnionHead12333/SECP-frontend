import 'package:flutter/material.dart';

import '../data/auth_api.dart';
import '../models/register_user_role.dart';
import 'auth_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 子女注册信息（按文档：姓名、手机号、密码、协议）
  final _childNameCtrl = TextEditingController();
  final _childNicknameCtrl = TextEditingController();
  final _childPhoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();

  // 老人主体（可动态添加多位）
  final List<_ElderForm> _elders = [_ElderForm()];

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;
  String? _error;
  RegisterUserRole _role = RegisterUserRole.elder;
  bool _agree = false;

  Future<void> _showPolicySheet({required String title, required String content}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      content,
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('我知道了'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  String? _validate() {
    // 账号类型：老人/子女
    if (_role == RegisterUserRole.child) {
      // 子女信息（老人主体信息在弹窗里单独校验）
      final childName = _childNameCtrl.text.trim();
      final childPhone = _childPhoneCtrl.text.trim();
      if (childName.isEmpty) return '请输入子女姓名';
      if (_childNicknameCtrl.text.trim().isEmpty) return '请输入子女昵称';
      if (childPhone.isEmpty) return '请输入子女手机号';
      if (childPhone.length < 11) return '子女手机号格式不正确';
      if (!_agree) return '请先勾选并同意协议';
    } else {
      // 老人注册（首版简化）：手机号 + 密码 + 协议
      final elderPhone = _childPhoneCtrl.text.trim();
      final elderName = _childNameCtrl.text.trim();
      final elderNick = _childNicknameCtrl.text.trim();
      if (elderNick.isEmpty) return '请输入昵称';
      if (elderName.isEmpty) return '请输入姓名';
      if (elderPhone.isEmpty) return '请输入手机号';
      if (elderPhone.length < 11) return '手机号格式不正确';
      if (!_agree) return '请先勾选并同意协议';
    }

    if (_pwdCtrl.text.isEmpty) return '请输入密码';
    if (_pwdCtrl.text.length < 6) return '密码至少 6 位';
    if (_pwdCtrl.text != _pwd2Ctrl.text) return '两次密码不一致';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    setState(() => _error = err);
    if (err != null) return;

    if (_role == RegisterUserRole.child) {
      await _openEldersSheet();
      return;
    }

    await _submitElder();
  }

  Future<void> _submitElder() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // 老人注册：暂用通用 /register（后端就绪后可替换为 elder 专用注册/认领流程）
      await AuthApi.register(
        username: _childPhoneCtrl.text.trim(),
        password: _pwdCtrl.text,
        role: _role.apiValue,
        phone: _childPhoneCtrl.text.trim(),
        name: _childNameCtrl.text.trim(),
        nickname: _childNicknameCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注册成功，请登录')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateElders() {
    if (_elders.isEmpty) return '请至少添加 1 位老人信息';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注册成功，请登录')),
      );
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
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '老人主体信息',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '可添加多位老人，后续可由老人本人注册认领。',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      ..._elders.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final form = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ElderBlock(
                            index: idx,
                            form: form,
                            canRemove: _elders.length > 1,
                            enabled: !_submitting,
                            onRemove: () => setState(() => _elders.removeAt(idx)),
                          ),
                        );
                      }),
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
                  onPressed: _submitting
                      ? null
                      : () async {
                          final err = _validateElders();
                          setState(() => _error = err);
                          if (err != null) return;
                          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
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

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: '注册',
      subtitle: '创建新账号',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '账号类型',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<RegisterUserRole>(
            segments: [
              ButtonSegment<RegisterUserRole>(
                value: RegisterUserRole.elder,
                label: Text(RegisterUserRole.elder.label),
                icon: const Icon(Icons.elderly_outlined, size: 20),
              ),
              ButtonSegment<RegisterUserRole>(
                value: RegisterUserRole.child,
                label: Text(RegisterUserRole.child.label),
                icon: const Icon(Icons.family_restroom_outlined, size: 20),
              ),
            ],
            selected: {_role},
            onSelectionChanged: (Set<RegisterUserRole> next) {
              if (_submitting) return;
              setState(() => _role = next.first);
            },
            multiSelectionEnabled: false,
            emptySelectionAllowed: false,
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 20),
          if (_role == RegisterUserRole.child) ...[
            Text(
              '子女信息',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _childNameCtrl,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '子女姓名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _childNicknameCtrl,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '子女昵称',
                hintText: '用于展示',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _childPhoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '子女手机号',
                hintText: '用于登录与接收通知',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            TextField(
              controller: _childNicknameCtrl,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _childNameCtrl,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '姓名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _childPhoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '手机号',
                hintText: '用于登录',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _pwdCtrl,
            obscureText: _obscure1,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '至少 6 位',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure1 = !_obscure1),
                icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwd2Ctrl,
            obscureText: _obscure2,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: '确认密码',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure2 = !_obscure2),
                icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('注册'),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _submitting ? null : () => setState(() => _agree = !_agree),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Checkbox(
                      value: _agree,
                      onChanged: _submitting ? null : (v) => setState(() => _agree = v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 2,
                      runSpacing: -6,
                      children: [
                        Text('我已阅读并同意', style: Theme.of(context).textTheme.bodySmall),
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => _showPolicySheet(
                                    title: '用户协议（示例）',
                                    content: _userAgreementText,
                                  ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('《用户协议》'),
                        ),
                        Text('与', style: Theme.of(context).textTheme.bodySmall),
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => _showPolicySheet(
                                    title: '隐私政策（示例）',
                                    content: _privacyPolicyText,
                                  ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('《隐私政策》'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      footer: TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        child: const Text('已有账号？返回登录'),
      ),
    );
  }
}

const String _userAgreementText = '''
欢迎使用「智慧养老平台」。

1. 服务说明
- 本应用用于家庭成员对老人日常健康、定位与告警信息的查看与管理（具体功能以实际提供为准）。

2. 账号与安全
- 你应妥善保管账号与密码，不得将账号出借、转让或用于违法用途。
- 如发现账号异常，请及时修改密码并联系管理员。

3. 合法合规使用
- 你承诺在取得被照护人（老人）授权/同意的前提下，绑定并查看其信息。
- 禁止利用本服务从事侵犯他人隐私、违法监控或其他违法活动。

4. 免责声明（简化）
- 因网络、设备或第三方服务导致的延迟、误报、漏报，平台会尽力改进但不承担全部后果。

（本协议为演示文本，正式版本以产品发布的协议为准。）''';

const String _privacyPolicyText = '''
我们重视你的隐私。本政策用于说明我们如何收集、使用与保护信息（演示文本）。

1. 我们可能收集的信息
- 账号信息：手机号、姓名、角色（老人/子女）等用于注册登录。
- 绑定信息：你与老人之间的关系、绑定状态。
- 定位与活动信息：用于安全监护与异常提醒（需获得老人授权/同意）。
- 设备与日志信息：用于问题排查与安全审计。

2. 信息使用目的
- 提供登录、绑定、定位展示、告警通知等核心功能。
- 保障系统安全，防止欺诈、滥用与攻击。
- 改进产品体验与稳定性。

3. 信息共享与披露
- 未经授权我们不会对外出售你的个人信息。
- 在法律法规要求或为保护用户安全的必要情形下，可能依法披露。

4. 你的权利
- 你可以查询、更正绑定信息与紧急联系人等资料。
- 你可以申请解绑/删除相关信息（具体以产品能力为准）。

5. 安全措施
- 我们采用访问控制、加密传输、权限校验等方式保护数据安全。

（本政策为演示文本，正式版本以产品发布的隐私政策为准。）''';

final class _ElderForm {
  _ElderForm()
      : nameCtrl = TextEditingController(),
        phoneCtrl = TextEditingController(),
        relationCtrl = TextEditingController();

  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController relationCtrl;

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    relationCtrl.dispose();
  }
}

class _ElderBlock extends StatelessWidget {
  const _ElderBlock({
    required this.index,
    required this.form,
    required this.canRemove,
    required this.enabled,
    required this.onRemove,
  });

  final int index;
  final _ElderForm form;
  final bool canRemove;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '老人主体 ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    onPressed: enabled ? onRemove : null,
                    tooltip: '移除',
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: form.nameCtrl,
              textInputAction: TextInputAction.next,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: '老人姓名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: form.phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: '老人手机号',
                hintText: '用于识别老人主体',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: form.relationCtrl,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: '与老人关系',
                hintText: '如：儿子/女儿/孙子…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
