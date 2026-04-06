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
  final _userCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;
  String? _error;
  RegisterUserRole _role = RegisterUserRole.elder;

  @override
  void dispose() {
    _userCtrl.dispose();
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final u = _userCtrl.text.trim();
    if (u.isEmpty) return '请输入用户名';
    if (u.length < 3) return '用户名至少 3 个字符';
    if (_pwdCtrl.text.isEmpty) return '请输入密码';
    if (_pwdCtrl.text.length < 6) return '密码至少 6 位';
    if (_pwdCtrl.text != _pwd2Ctrl.text) return '两次密码不一致';
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && phone.length < 11) return '手机号格式不正确';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    setState(() => _error = err);
    if (err != null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthApi.register(
        username: _userCtrl.text.trim(),
        password: _pwdCtrl.text,
        role: _role.apiValue,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
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
          TextField(
            controller: _userCtrl,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '至少 3 个字符',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '手机号（选填）',
              hintText: '用于找回账号等',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
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
        ],
      ),
      footer: TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        child: const Text('已有账号？返回登录'),
      ),
    );
  }
}
