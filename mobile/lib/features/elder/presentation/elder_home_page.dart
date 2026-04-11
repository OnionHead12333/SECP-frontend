import 'package:flutter/material.dart';
import '../../../core/auth/auth_session.dart';
import '../data/elder_help_service.dart';
import '../elder_module_routes.dart';
import '../models/elder_help_request.dart';

enum _HelpRequestState { idle, pending, sent, revoked }
enum _HelpSheetResult { revoke, sendNow, timeout }

class ElderHomePage extends StatefulWidget {
  const ElderHomePage({super.key});

  @override
  State<ElderHomePage> createState() => _ElderHomePageState();
}

class _ElderHomePageState extends State<ElderHomePage> {
  static const int _fallbackRevokeSeconds = 5;

  int _index = 0;
  int? _currentAlertId;
  _HelpRequestState _helpState = _HelpRequestState.idle;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final name = AuthSession.elderName ?? '老人用户';
    final phone = AuthSession.elderPhone ?? '-';
    final claimed = AuthSession.elderClaimed;
    final familyCount = AuthSession.elderFamilyCount;
    final pages = <Widget>[
      _HomeTab(
        name: name,
        phone: phone,
        claimed: claimed,
        familyCount: familyCount,
        helpState: _helpState,
        onBindingTap: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderBinding),
        onOpenReminders: () => setState(() => _index = 1),
        onSosTap: _busy ? null : _handleHelpTap,
      ),
      const _ReminderMedicalTab(),
      _MyTab(
        name: name,
        phone: phone,
        claimed: claimed,
        familyCount: familyCount,
        onBindingTap: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderBinding),
        onLogout: () {
          AuthSession.clear();
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        },
      ),
    ];
    const titles = ['', '提醒', '我的'];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: Text(titles[_index]), backgroundColor: const Color(0xFFF7F8FC)),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: '提醒'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }

  Future<void> _handleHelpTap() async {
    setState(() => _busy = true);
    try {
      final request = await ElderHelpService.createHelpRequest();
      if (!mounted) return;
      _applyRequestState(request);
      final result = await showModalBottomSheet<_HelpSheetResult>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (_) => _HelpCountdownSheet(seconds: _resolveSeconds(request)),
      );
      if (!mounted || _currentAlertId == null) return;
      switch (result) {
        case _HelpSheetResult.revoke:
          final revoked = await ElderHelpService.revokeHelpRequest(alertId: _currentAlertId!, cancelMode: 'button');
          if (!mounted) return;
          _applyRequestState(revoked);
          _showMessage('老人已确认撤回，本次求助已取消');
          break;
        case _HelpSheetResult.sendNow:
          final sent = await ElderHelpService.sendNow(alertId: _currentAlertId!);
          if (!mounted) return;
          _applyRequestState(sent);
          _showMessage('求助已立即发送到子女端');
          break;
        case _HelpSheetResult.timeout:
        case null:
          final current = await ElderHelpService.getHelpRequestStatus(alertId: _currentAlertId!);
          if (!mounted) return;
          _applyRequestState(current);
          if (_helpState == _HelpRequestState.sent) {
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

  void _applyRequestState(ElderHelpRequest request) {
    _currentAlertId = request.alertId;
    setState(() => _helpState = _mapHelpState(request.status));
  }

  _HelpRequestState _mapHelpState(String status) {
    switch (status) {
      case 'pending_revoke':
        return _HelpRequestState.pending;
      case 'cancelled':
        return _HelpRequestState.revoked;
      case 'sent':
      case 'handled':
      case 'false_alarm':
        return _HelpRequestState.sent;
      default:
        return _HelpRequestState.idle;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.name, required this.phone, required this.claimed, required this.familyCount, required this.helpState, required this.onBindingTap, required this.onOpenReminders, required this.onSosTap});

  final String name;
  final String phone;
  final bool claimed;
  final int familyCount;
  final _HelpRequestState helpState;
  final VoidCallback onBindingTap;
  final VoidCallback onOpenReminders;
  final VoidCallback? onSosTap;

  @override
  Widget build(BuildContext context) {
    final statusText = claimed ? '已认领老人资料' : '未认领老人资料';
    final statusColor = claimed ? const Color(0xFF166534) : const Color(0xFFB45309);
    final familyText = familyCount > 0 ? '已绑定 $familyCount 位家属' : '暂未绑定家属';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _ResponsiveHeroCard(name: name, phone: phone, statusText: statusText, statusColor: statusColor, onSosTap: onSosTap),
        if (helpState != _HelpRequestState.idle) ...[
          const SizedBox(height: 12),
          _HelpStatusBanner(state: helpState),
        ],
        const SizedBox(height: 12),
        _Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('今日最重要', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _SimpleRow(icon: Icons.notifications_active_outlined, title: '今日提醒', value: '上午吃药已完成，晚间提醒待处理', onTap: onOpenReminders),
            const Divider(height: 24),
            _SimpleRow(icon: Icons.family_restroom_outlined, title: '家属状态', value: familyText, onTap: onBindingTap),
          ]),
        ),
      ],
    );
  }
}

class _ResponsiveHeroCard extends StatelessWidget {
  const _ResponsiveHeroCard({required this.name, required this.phone, required this.statusText, required this.statusColor, required this.onSosTap});

  final String name;
  final String phone;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onSosTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return _Panel(
      background: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF7ED), Color(0xFFEFF6FF)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('首页', style: TextStyle(fontSize: compact ? 28 : 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Text(_greet(), style: const TextStyle(fontSize: 16, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('您好，$name', style: TextStyle(fontSize: compact ? 24 : 28, fontWeight: FontWeight.w800, height: 1.15)),
              const SizedBox(height: 10),
              Text('手机号：$phone', style: const TextStyle(fontSize: 16, color: Color(0xFF334155))),
            ]),
          ),
          const SizedBox(width: 12),
          _SosCircleButton(onTap: onSosTap, compact: compact),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.88), borderRadius: BorderRadius.circular(999)),
          child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  static String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return '早上好';
    if (h < 18) return '下午好';
    return '晚上好';
  }
}
class _HelpCountdownSheet extends StatefulWidget {
  const _HelpCountdownSheet({required this.seconds});
  final int seconds;

  @override
  State<_HelpCountdownSheet> createState() => _HelpCountdownSheetState();
}

class _HelpCountdownSheetState extends State<_HelpCountdownSheet> {
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
    if (mounted) Navigator.of(context).pop(_HelpSheetResult.timeout);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('求助已发起，$_secondsLeft 秒内可撤回', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text('倒计时结束后，系统将自动发送给子女端。\n也可以语音提示：\n“如果你要撤回，请大声说出撤回、撤回，我们将撤回。”', style: TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.65)),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _secondsLeft / widget.seconds,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFDC2626)),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18)),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('语音播报提示', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('如果你要撤回，请大声说出撤回、撤回，我们将撤回。', style: TextStyle(color: Color(0xFF475569), height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(_HelpSheetResult.revoke), child: const Text('确认撤回'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () => Navigator.of(context).pop(_HelpSheetResult.sendNow), child: const Text('立即发送'))),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpStatusBanner extends StatelessWidget {
  const _HelpStatusBanner({required this.state});
  final _HelpRequestState state;
  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String title;
    late final String subtitle;
    switch (state) {
      case _HelpRequestState.pending:
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFB45309);
        icon = Icons.schedule;
        title = '求助发起中';
        subtitle = '当前处于撤回倒计时，倒计时结束后将自动发送。';
      case _HelpRequestState.sent:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.sos;
        title = '求助已发送到子女端';
        subtitle = '老人未执行撤回，系统已把本次求助发给子女端。';
      case _HelpRequestState.revoked:
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF166534);
        icon = Icons.undo;
        title = '求助已撤回';
        subtitle = '老人已确认撤回，本次求助不会发送到子女端。';
      case _HelpRequestState.idle:
        bg = const Color(0xFFF8FAFC);
        fg = const Color(0xFF475569);
        icon = Icons.info_outline;
        title = '待命';
        subtitle = '当前无求助状态';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: fg.withOpacity(0.18))),
      child: Row(children: [
        Icon(icon, color: fg),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: fg.withOpacity(0.9), height: 1.45)),
        ])),
      ]),
    );
  }
}

class _ReminderMedicalTab extends StatelessWidget {
  const _ReminderMedicalTab();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: const [
          _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('提醒与医疗', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text('把吃药、复诊、医疗事项放在同一栏，老人不用来回找。', style: TextStyle(color: Color(0xFF475569), height: 1.5)),
          ])),
          SizedBox(height: 14),
          _ItemCard(title: '今日提醒', subtitle: '上午吃药：已完成\n晚间吃药：待提醒'),
          SizedBox(height: 10),
          _ItemCard(title: '复诊安排', subtitle: '本周五上午 9:30 复诊'),
          SizedBox(height: 10),
          _ItemCard(title: '医疗档案', subtitle: '后续接入病历、报告、单据归档'),
        ],
      );
}

class _MyTab extends StatelessWidget {
  const _MyTab({required this.name, required this.phone, required this.claimed, required this.familyCount, required this.onBindingTap, required this.onLogout});
  final String name;
  final String phone;
  final bool claimed;
  final int familyCount;
  final VoidCallback onBindingTap;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('手机号：$phone', style: const TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 8),
            Text(claimed ? '当前状态：已认领老人资料' : '当前状态：未认领老人资料', style: const TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 8),
            Text('已绑定家属：$familyCount 位', style: const TextStyle(color: Color(0xFF475569))),
          ])),
          const SizedBox(height: 12),
          _ItemCard(title: '家属绑定状态', subtitle: '查看绑定详情与当前说明', onTap: onBindingTap),
          const SizedBox(height: 10),
          const _ItemCard(title: '紧急联系人', subtitle: '后续可在这里展示联系人信息'),
          const SizedBox(height: 10),
          _ItemCard(title: '退出登录', subtitle: '退出当前老人账号，返回统一登录页', onTap: onLogout),
        ],
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.background});
  final Widget child;
  final Gradient? background;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: background == null ? Colors.white : null, gradient: background, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: child,
      );
}

class _SosCircleButton extends StatelessWidget {
  const _SosCircleButton({required this.onTap, this.compact = false});
  final VoidCallback? onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final size = compact ? 84.0 : 96.0;
    final iconSize = compact ? 22.0 : 26.0;
    final labelSize = compact ? 13.0 : 15.0;
    return Material(
      color: const Color(0xFFFEF2F2),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFCA5A5))),
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.sos_outlined, color: const Color(0xFFDC2626), size: iconSize),
            const SizedBox(height: 6),
            Text('紧急\n求助', textAlign: TextAlign.center, style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w800, color: const Color(0xFF991B1B), height: 1.15)),
          ]),
        ),
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.icon, required this.title, required this.value, this.onTap});
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Icon(icon, color: const Color(0xFF475569))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ]),
      );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.title, required this.subtitle, this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: Color(0xFF475569), height: 1.5)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ]),
          ),
        ),
      );
}
