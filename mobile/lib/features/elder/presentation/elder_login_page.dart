import 'package:flutter/material.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../data/elder_mock_auth_service.dart';
import 'elder_auth_shell.dart';
import 'elder_home_page.dart';
import 'elder_register_page.dart';

class ElderLoginPage extends StatefulWidget {
  const ElderLoginPage({super.key});

  @override
  State<ElderLoginPage> createState() => _ElderLoginPageState();
}

class _ElderLoginPageState extends State<ElderLoginPage> {
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return '请输入手机号';
    if (phone.length != 11) return '请输入 11 位手机号';
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
      final phone = _phoneCtrl.text.trim();
      final password = _pwdCtrl.text;
      final token = await ElderMockAuthService.login(phone: phone, password: password);
      AuthSession.token = token;
      AuthSession.role = AppRole.elder;
      AuthSession.saveElderState(
        name: '老人用户',
        phone: phone,
        claimed: true,
        familyCount: ElderMockAuthService.mockFamilyCountForLogin(phone),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ElderHomePage()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElderAuthShell(
      title: '老人登录',
      subtitle: '请输入手机号和密码，登录后可继续查看自己的绑定状态。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: '手机号',
              hintText: '请输入 11 位手机号',
              prefixIcon: const Icon(Icons.phone_iphone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwdCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            enabled: !_submitting,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入密码',
              helperText: '当前演示环境统一密码：123456',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('登录'),
          ),
        ],
      ),
      footer: Column(
        children: [
          const Text('还没有账号？', style: TextStyle(color: Color(0xFF6B7280))),
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ElderRegisterPage()),
                    );
                  },
            child: const Text('去注册老人账号'),
          ),
        ],
      ),
    );
  }
}
