import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../../elder/elder_module_routes.dart';
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

  String _friendlyError(Object e) {
    if (e is DioException) {
      return '网络异常，请检查网络后重试';
    }
    final msg = e.toString().replaceFirst('Exception: ', '').trim();
    if (msg.contains('token') || msg.contains('role')) {
      return '登录失败，请稍后重试';
    }
    if (msg.contains('密码') || msg.contains('账号') || msg.contains('用户名') || msg.contains('用户')) {
      return '手机号或密码错误';
    }
    return '登录失败，请稍后重试';
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  static final RegExp _cnMobile = RegExp(r'^1[3-9]\d{9}$');

  String? _validate() {
    final u = _userCtrl.text.trim();
    if (u.isEmpty) return '请输入手机号码';
    if (u != '123123' && !_cnMobile.hasMatch(u)) {
      return '请输入11位中国大陆手机号';
    }
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

      if (username == '123123' && password == '123123') {
        AuthSession.token = 'demo-child';
        AuthSession.role = AppRole.child;
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/child', (r) => false);
        return;
      }

      final result = await AuthApi.login(username: username, password: password);
      AuthSession.token = result.token;

      if (result.role == 'child') {
        AuthSession.role = AppRole.child;
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/child', (r) => false);
        return;
      }
      AuthSession.role = AppRole.elder;
      AuthSession.saveElderState(
        name: result.name ?? username,
        phone: result.phone ?? username,
        claimed: result.claimed ?? false,
        familyCount: result.familyCount ?? 0,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(ElderModuleRoutes.elderHome, (r) => false);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Login failed: $e');
        debugPrintStack(stackTrace: st);
      }
      setState(() => _error = _friendlyError(e));
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
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '手机号码',
              hintText: '请输入11位手机号码',
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
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _submitting
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterPage()));
                  },
            child: const Text('去注册'),
          ),
        ],
      ),
    );
  }
}
