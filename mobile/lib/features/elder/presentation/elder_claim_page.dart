import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_mock_auth_service.dart';
import '../elder_module_routes.dart';
import '../models/elder_mock_recognition_result.dart';
import 'elder_auth_shell.dart';

class ElderClaimPage extends StatefulWidget {
  const ElderClaimPage({super.key, required this.result});

  final ElderMockRecognitionResult result;

  @override
  State<ElderClaimPage> createState() => _ElderClaimPageState();
}

class _ElderClaimPageState extends State<ElderClaimPage> {
  bool _submitting = false;
  String? _error;

  Future<void> _claim() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final claimed = await ElderMockAuthService.claimProfile(widget.result);
      AuthSession.saveElderState(
        name: claimed.elderName,
        phone: claimed.phone,
        claimed: true,
        familyCount: claimed.familyCount,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(ElderModuleRoutes.elderHome, (route) => false);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElderAuthShell(
      title: '确认认领资料',
      subtitle: '系统检测到该手机号已有关联老人资料，请确认身份后继续进入。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '检测到已有老人资料',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 12),
                Text('姓名：${widget.result.elderName}', style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 8),
                Text('手机号：${widget.result.phone}', style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 8),
                Text('已绑定家属：${widget.result.familyCount} 位', style: const TextStyle(fontSize: 17)),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _submitting ? null : _claim,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.verified_user_outlined),
            label: _submitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('确认认领并进入'),
          ),
        ],
      ),
    );
  }
}
