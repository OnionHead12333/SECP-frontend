import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../data/elder_help_service.dart';
import '../models/elder_help_request.dart';

enum _SosSheetResult { revoke, sendNow, timeout }

class ElderGlobalSosOverlay extends StatefulWidget {
  const ElderGlobalSosOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<ElderGlobalSosOverlay> createState() => _ElderGlobalSosOverlayState();
}

class _ElderGlobalSosOverlayState extends State<ElderGlobalSosOverlay> {
  static const int _fallbackRevokeSeconds = 10;

  Timer? _sessionWatcher;
  bool _busy = false;
  int? _currentAlertId;
  AppRole? _lastRole;

  bool get _shouldShowSos => AuthSession.isLoggedIn && AuthSession.role == AppRole.elder;

  @override
  void initState() {
    super.initState();
    _lastRole = AuthSession.role;
    AuthSession.sessionChanges.addListener(_handleSessionChanged);
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    final nextRole = AuthSession.role;
    if (_lastRole != nextRole) {
      setState(() => _lastRole = nextRole);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    AuthSession.sessionChanges.removeListener(_handleSessionChanged);
    _sessionWatcher?.cancel();
    super.dispose();
  }

  Future<void> _handleSosTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final request = await ElderHelpService.createHelpRequest();
      if (!mounted) return;
      _currentAlertId = request.alertId;
      final navigatorContext = widget.navigatorKey.currentContext;
      if (navigatorContext == null) {
        _showMessage('当前页面还未准备好，请稍后再试');
        return;
      }
      final result = await showModalBottomSheet<_SosSheetResult>(
        context: navigatorContext,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => _GlobalSosCountdownSheet(seconds: _resolveSeconds(request)),
      );
      if (!mounted || _currentAlertId == null) return;
      switch (result) {
        case _SosSheetResult.revoke:
          await ElderHelpService.revokeHelpRequest(alertId: _currentAlertId!, cancelMode: 'button');
          if (!mounted) return;
          _showMessage('老人已确认撤回，本次求助已取消');
          break;
        case _SosSheetResult.sendNow:
          await ElderHelpService.sendNow(alertId: _currentAlertId!);
          if (!mounted) return;
          _showMessage('求助已立即发送到子女端');
          break;
        case _SosSheetResult.timeout:
        case null:
          final current = await ElderHelpService.getHelpRequestStatus(alertId: _currentAlertId!);
          if (!mounted) return;
          if (current.status == 'sent' || current.status == 'handled' || current.status == 'false_alarm') {
            _showMessage('撤回时间结束，求助已发送到子女端');
          }
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _resolveSeconds(ElderHelpRequest request) {
    final deadline = request.revokeDeadline;
    final reference = request.serverTime ?? DateTime.now();
    if (deadline == null) return _fallbackRevokeSeconds;
    final seconds = deadline.difference(reference).inSeconds;
    return seconds <= 0 ? 1 : seconds;
  }

  void _showMessage(String message) {
    widget.scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Stack(
      children: [
        widget.child,
        if (_shouldShowSos)
          Positioned(
            top: media.padding.top + 64,
            right: 16,
            child: SafeArea(
              child: _GlobalSosButton(
                busy: _busy,
                onTap: _busy ? null : _handleSosTap,
              ),
            ),
          ),
      ],
    );
  }
}

class _GlobalSosButton extends StatelessWidget {
  const _GlobalSosButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEF2F2),
      shape: const CircleBorder(),
      elevation: 10,
      shadowColor: const Color(0xFF991B1B).withOpacity(0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEF4444), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFDC2626)),
                )
              else
                const Icon(Icons.sos_outlined, color: Color(0xFFDC2626), size: 26),
              const SizedBox(height: 5),
              const Text(
                '紧急\n求助',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF991B1B), height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalSosCountdownSheet extends StatefulWidget {
  const _GlobalSosCountdownSheet({required this.seconds});

  final int seconds;

  @override
  State<_GlobalSosCountdownSheet> createState() => _GlobalSosCountdownSheetState();
}

class _GlobalSosCountdownSheetState extends State<_GlobalSosCountdownSheet> {
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.seconds;
    _tick();
  }

  Future<void> _tick() async {
    while (mounted && _secondsLeft > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
    }
    if (mounted) Navigator.of(context).pop(_SosSheetResult.timeout);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('求助已发起，$_secondsLeft 秒内可撤回', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('倒计时结束后，系统将自动发送给子女端。', style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.6)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _secondsLeft / widget.seconds,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFDC2626)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_SosSheetResult.revoke),
                    child: const Text('确认撤回'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_SosSheetResult.sendNow),
                    child: const Text('立即发送'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
