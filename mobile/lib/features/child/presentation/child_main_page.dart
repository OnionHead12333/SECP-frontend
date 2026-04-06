import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../models/child_local_models.dart';
import 'tabs/child_medical_tab.dart';
import 'tabs/child_overview_tab.dart';
import 'tabs/child_safety_tab.dart';
import 'tabs/child_settings_tab.dart';

/// 子女端：底部四模块 — 首页总览 / 医疗管理 / 安全监护 / 设置
class ChildMainPage extends StatefulWidget {
  const ChildMainPage({super.key});

  @override
  State<ChildMainPage> createState() => _ChildMainPageState();
}

class _ChildMainPageState extends State<ChildMainPage> {
  int _navIndex = 0;

  late List<BoundElder> _elders;
  late List<EmergencyContact> _contacts;
  late List<HelpRequestRecord> _helpRecords;
  late LocationSnapshot _location;
  late ActivitySnapshot _activity;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _elders = [
      BoundElder(id: 'e1', displayName: '张奶奶', accountHint: '138****0001'),
    ];
    _contacts = [
      EmergencyContact(id: 'c1', name: '李强', phone: '13900001111', relation: '本人'),
    ];
    _helpRecords = [
      HelpRequestRecord(
        id: 'h1',
        elderName: '张奶奶',
        createdAt: now.subtract(const Duration(hours: 2)),
        summary: '在家中跌倒告警，请尽快查看摄像头或联系老人。',
        status: HelpRequestStatus.pending,
      ),
      HelpRequestRecord(
        id: 'h2',
        elderName: '张奶奶',
        createdAt: now.subtract(const Duration(days: 1)),
        summary: '长按 SOS 求助（已自动拨打紧急联系人）。',
        status: HelpRequestStatus.resolved,
      ),
    ];
    _location = LocationSnapshot(
      latitude: 31.2304,
      longitude: 121.4737,
      address: '上海市黄浦区 · 示例小区（演示数据）',
      updatedAt: now.subtract(const Duration(minutes: 3)),
    );
    _activity = ActivitySnapshot(
      stepsToday: 4280,
      stateLabel: '轻度活动 · 室内为主',
      updatedAt: now.subtract(const Duration(minutes: 8)),
    );
  }

  void _logout(BuildContext context) {
    AuthSession.clear();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _addElder(BoundElder e) => setState(() => _elders.add(e));

  void _removeElder(String id) => setState(() => _elders.removeWhere((x) => x.id == id));

  void _addContact(EmergencyContact c) => setState(() => _contacts.add(c));

  void _updateContact(EmergencyContact c) {
    setState(() {
      final i = _contacts.indexWhere((x) => x.id == c.id);
      if (i >= 0) _contacts[i] = c;
    });
  }

  void _removeContact(String id) => setState(() => _contacts.removeWhere((x) => x.id == id));

  void _refreshLocationMock() {
    setState(() {
      final jitter = (DateTime.now().millisecond % 100) / 1e5;
      _location = LocationSnapshot(
        latitude: 31.2304 + jitter,
        longitude: 121.4737 + jitter,
        address: _location.address,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _resolveHelp(String id) {
    setState(() {
      for (final r in _helpRecords) {
        if (r.id == id) r.status = HelpRequestStatus.resolved;
      }
    });
  }

  static const _titles = ['首页总览', '医疗管理', '安全监护', '设置'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_navIndex]),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
          ),
        ],
      ),
      body: IndexedStack(
        index: _navIndex,
        children: [
          ChildOverviewTab(
            elders: _elders,
            location: _location,
            activity: _activity,
            helpRecords: _helpRecords,
          ),
          const ChildMedicalTab(),
          ChildSafetyTab(
            location: _location,
            activity: _activity,
            helpRecords: _helpRecords,
            onRefreshLocation: _refreshLocationMock,
            onResolveHelp: _resolveHelp,
          ),
          ChildSettingsTab(
            elders: _elders,
            contacts: _contacts,
            onAddElder: _addElder,
            onRemoveElder: _removeElder,
            onAddContact: _addContact,
            onUpdateContact: _updateContact,
            onRemoveContact: _removeContact,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '首页'),
          NavigationDestination(icon: Icon(Icons.medical_services_outlined), selectedIcon: Icon(Icons.medical_services), label: '医疗'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: '安全'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
