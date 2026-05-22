import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_session.dart';
import '../../interest_community/presentation/widgets/elder_avatar_picker_tile.dart';
import '../data/elder_location_service.dart';
import '../elder_module_routes.dart';
import 'elder_community_tab.dart';
import 'elder_reminder_center_tab.dart';

class ElderHomePage extends StatefulWidget {
  const ElderHomePage({super.key});

  @override
  State<ElderHomePage> createState() => _ElderHomePageState();
}

class _ElderHomePageState extends State<ElderHomePage> {
  static const String _loginPermissionGuideShownKey = 'elder_login_permission_guide_shown_v1';

  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showLoginPermissionGuideIfNeeded());
    });
  }

  Future<void> _showLoginPermissionGuideIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_loginPermissionGuideShownKey) ?? false;
    if (!mounted || alreadyShown) return;
    await prefs.setBool(_loginPermissionGuideShownKey, true);
    if (!mounted) return;
    final shouldStart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('开启必要权限'),
        content: const Text(
          '为了让子女端及时看到您的安全位置，并支持语音求助/撤回，接下来会依次申请通知、麦克风、定位权限，并尝试开启定位守护。\n\n'
          '安卓系统不允许软件刚下载完成就自动弹权限，必须在首次登录进入 App 后由用户确认。后台定位、电池优化等权限在部分手机上还需要到系统设置里手动开启。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('稍后再说')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('立即开启')),
        ],
      ),
    );
    if (shouldStart != true || !mounted) return;
    await _requestLoginPermissionsAndStartGuard();
  }

  Future<void> _requestLoginPermissionsAndStartGuard() async {
    try {
      final granted = await ElderLocationService.requestPermission();
      if (!granted) {
        _showMessage('未获得定位权限，请在系统设置中开启后再进入「我的-定位服务状态」重试。');
        return;
      }
      await ElderLocationService.startAutoUpload(AuthSession.elderPhone ?? '');
      _showMessage('已开启定位守护。若需退出后仍定位，请到系统设置中允许「始终定位」和后台运行。');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openElderProfile() async {
    final r = await Navigator.of(context).pushNamed(ElderModuleRoutes.elderProfile);
    if (mounted && r == true) setState(() {});
  }

  String _elderGenderLabel() {
    switch (AuthSession.elderGender) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return '不愿透露';
    }
  }

  String _elderBirthdayLabel() {
    final s = AuthSession.elderBirthday;
    if (s == null || s.isEmpty) return '未设置';
    final d = DateTime.tryParse(s)?.toLocal();
    if (d == null) return s;
    return '${d.year}年${d.month}月${d.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthSession.elderName ?? '老人用户';
    final phone = AuthSession.elderPhone ?? '-';
    final claimed = AuthSession.elderClaimed;
    final familyCount = AuthSession.elderFamilyCount;
    final genderText = _elderGenderLabel();
    final birthText = _elderBirthdayLabel();
    final pages = <Widget>[
      _HomeTab(
        name: name,
        phone: phone,
        genderText: genderText,
        birthText: birthText,
        claimed: claimed,
        familyCount: familyCount,
        onBindingTap: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderBinding),
        onOpenReminders: () => setState(() => _index = 2),
        onOpenAiAssistant: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderAiAssistant),
      ),
      const ElderCommunityTab(),
      ElderReminderCenterTab(
        onOpenLocationPage: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderLocationStatus),
      ),
      _MyTab(
        name: name,
        phone: phone,
        genderText: genderText,
        birthText: birthText,
        claimed: claimed,
        onProfileEditTap: _openElderProfile,
        onBindingTap: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderBinding),
        onEmergencyContactsTap: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderEmergencyContacts),
        onLocationTap: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderLocationStatus),
        onLogout: () {
          AuthSession.clear();
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        },
      ),
    ];
    const titles = ['', '社群', '提醒', '我的'];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: Text(titles[_index]), backgroundColor: const Color(0xFFF7F8FC)),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: '社群'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: '提醒'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.name,
    required this.phone,
    required this.genderText,
    required this.birthText,
    required this.claimed,
    required this.familyCount,
    required this.onBindingTap,
    required this.onOpenReminders,
    required this.onOpenAiAssistant,
  });

  final String name;
  final String phone;
  final String genderText;
  final String birthText;
  final bool claimed;
  final int familyCount;
  final VoidCallback onBindingTap;
  final VoidCallback onOpenReminders;
  final VoidCallback onOpenAiAssistant;

  @override
  Widget build(BuildContext context) {
    final statusText = claimed ? '已认领老人资料' : '未认领老人资料';
    final statusColor = claimed ? const Color(0xFF166534) : const Color(0xFFB45309);
    final familyText = familyCount > 0 ? '已绑定 $familyCount 位家属' : '暂未绑定家属';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const Text('首页', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _ResponsiveHeroCard(
          name: name,
          phone: phone,
          genderText: genderText,
          birthText: birthText,
          statusText: statusText,
          statusColor: statusColor,
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('今日最重要', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _SimpleRow(
                icon: Icons.notifications_active_outlined,
                title: '今日提醒',
                value: '上午吃药已完成，晚间提醒待处理',
                onTap: onOpenReminders,
              ),
              const Divider(height: 24),
              _SimpleRow(
                icon: Icons.health_and_safety_outlined,
                title: 'AI 医疗助手',
                value: '身体不舒服时先问一问，支持风险提示和家属同步',
                onTap: onOpenAiAssistant,
              ),
              const Divider(height: 24),
              _SimpleRow(
                icon: Icons.family_restroom_outlined,
                title: '家属状态',
                value: familyText,
                onTap: onBindingTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResponsiveHeroCard extends StatelessWidget {
  const _ResponsiveHeroCard({
    required this.name,
    required this.phone,
    required this.genderText,
    required this.birthText,
    required this.statusText,
    required this.statusColor,
  });

  final String name;
  final String phone;
  final String genderText;
  final String birthText;
  final String statusText;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return _Panel(
      background: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF7ED), Color(0xFFEFF6FF)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greet(),
            style: const TextStyle(fontSize: 16, color: Color(0xFF475569), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '您好，$name',
            style: TextStyle(fontSize: compact ? 24 : 28, fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 10),
          Text('手机号：$phone', style: const TextStyle(fontSize: 16, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          Text(
            '性别：$genderText  ·  生日：$birthText',
            style: const TextStyle(fontSize: 15, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  static String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return '早上好';
    if (h < 18) return '下午好';
    return '晚上好';
  }
}


class _MyTab extends StatelessWidget {
  const _MyTab({
    required this.name,
    required this.phone,
    required this.genderText,
    required this.birthText,
    required this.claimed,
    required this.onProfileEditTap,
    required this.onBindingTap,
    required this.onEmergencyContactsTap,
    required this.onLocationTap,
    required this.onLogout,
  });

  final String name;
  final String phone;
  final String genderText;
  final String birthText;
  final bool claimed;
  final VoidCallback onProfileEditTap;
  final VoidCallback onBindingTap;
  final VoidCallback onEmergencyContactsTap;
  final VoidCallback onLocationTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ElderAvatarPickerTile(
                  size: 88,
                  showCaption: false,
                ),
              ),
              const SizedBox(height: 16),
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('手机号：$phone', style: const TextStyle(color: Color(0xFF475569))),
              const SizedBox(height: 4),
              Text(
                '性别：$genderText  ·  生日：$birthText',
                style: const TextStyle(color: Color(0xFF475569), fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                claimed ? '当前状态：已认领老人资料' : '当前状态：未认领老人资料',
                style: const TextStyle(color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ItemCard(title: '个人信息', subtitle: '修改称呼、性别与出生日期', onTap: onProfileEditTap),
        const SizedBox(height: 10),
        _ItemCard(title: '家属绑定状态', subtitle: '查看绑定详情与当前说明', onTap: onBindingTap),
        const SizedBox(height: 10),
        _ItemCard(title: '紧急联系人', subtitle: '只支持新增联系人，已有信息统一维护', onTap: onEmergencyContactsTap),
        const SizedBox(height: 10),
        _ItemCard(title: '定位与轨迹上传', subtitle: '查看当前位置状态与上传演示轨迹', onTap: onLocationTap),
        const SizedBox(height: 10),
        _ItemCard(title: '退出登录', subtitle: '退出当前老人账号，返回统一登录页', onTap: onLogout),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.background});

  final Widget child;
  final Gradient? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background == null ? Colors.white : null,
        gradient: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFF475569)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF475569), height: 1.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
