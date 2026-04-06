import 'package:flutter/material.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../data/auth_api.dart';
import 'auth_shell.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final u = _userCtrl.text.trim();
    if (u.isEmpty) return '请输入用户名';
    if (u.length < 3) return '用户名至少 3 个字符';
    if (_pwdCtrl.text.isEmpty) return '请输入密码';
    if (_pwdCtrl.text.length < 6) return '密码至少 6 位';
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
      final username = _userCtrl.text.trim();
      final password = _pwdCtrl.text;

      // 演示：子女端入口（无需后端）；正式环境接入接口后删除或改为服务端返回角色再跳转。
      if (username == '123123' && password == '123123') {
        AuthSession.token = 'demo-child';
        AuthSession.role = AppRole.child;
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/child', (r) => false);
        return;
      }

      final token = await AuthApi.login(
        username: username,
        password: password,
      );
      AuthSession.token = token;
      AuthSession.role = AppRole.elder;
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: '登录',
      subtitle: '登录您的账号',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _userCtrl,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '请输入用户名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwdCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入密码',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? '显示密码' : '隐藏密码',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
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
                : const Text('登录'),
          ),
        ],
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('还没有账号？'),
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                    );
                  },
            child: const Text('去注册'),
          ),
        ],
      ),
    );
  }
}
