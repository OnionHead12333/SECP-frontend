import 'package:flutter/material.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../data/elder_mock_auth_service.dart';
import 'elder_auth_shell.dart';
import 'elder_claim_page.dart';
import 'elder_home_page.dart';

class ElderRegisterPage extends StatefulWidget {
  const ElderRegisterPage({super.key});

  @override
  State<ElderRegisterPage> createState() => _ElderRegisterPageState();
}

class _ElderRegisterPageState extends State<ElderRegisterPage> {
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return '请输入手机号';
    if (phone.length != 11) return '请输入 11 位手机号';
    if (_pwdCtrl.text.isEmpty) return '请输入密码';
    if (_pwdCtrl.text.length < 6) return '密码至少 6 位';
    if (_pwdCtrl.text != _pwd2Ctrl.text) return '两次输入的密码不一致';
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
      await ElderMockAuthService.register(phone: phone, password: password);
      final token = 'elder-demo-$phone';
      final result = await ElderMockAuthService.recognizeByPhone(phone);
      AuthSession.token = token;
      AuthSession.role = AppRole.elder;
      if (!mounted) return;
      if (result.hasExistingProfile) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => ElderClaimPage(result: result)),
        );
        return;
      }
      final created = await ElderMockAuthService.createIndependentProfile(phone);
      AuthSession.saveElderState(
        name: created.elderName,
        phone: created.phone,
        claimed: true,
        familyCount: created.familyCount,
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
      title: '老人注册',
      subtitle: '先注册老人账号，系统会自动判断是否已有家人为您创建资料。',
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
            obscureText: _obscure1,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '至少 6 位',
              helperText: '当前演示环境建议密码：123456',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: '确认密码',
              hintText: '请再输入一次密码',
              prefixIcon: const Icon(Icons.verified_user_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
                : const Text('注册并继续'),
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
