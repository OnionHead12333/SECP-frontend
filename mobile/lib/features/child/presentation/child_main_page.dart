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
  static const double _homeLatitude = 31.23040;
  static const double _homeLongitude = 121.47370;
  static const String _homeLabel = '张奶奶家';

  int _navIndex = 0;

  late List<BoundElder> _elders;
  late List<EmergencyContact> _contacts;
  late List<HelpRequestRecord> _helpRecords;
  late LocationSnapshot _location;
  late List<LocationTrackPoint> _track;
  late NavigationRouteSnapshot _route;
  late ActivitySnapshot _activity;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _elders = [
      BoundElder(id: 'e1', displayName: '张奶奶', accountHint: '138****0001'),
    ];
    _contacts = [
      EmergencyContact(
        id: 'c1',
        elderId: 'e1',
        name: '李强',
        phone: '13900001111',
        relation: '本人',
      ),
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
    _track = [
      LocationTrackPoint(latitude: 31.23218, longitude: 121.47502, recordedAt: now.subtract(const Duration(minutes: 18)), label: '社区东门'),
      LocationTrackPoint(latitude: 31.23128, longitude: 121.47440, recordedAt: now.subtract(const Duration(minutes: 12)), label: '家附近路口'),
      LocationTrackPoint(latitude: 31.23072, longitude: 121.47402, recordedAt: now.subtract(const Duration(minutes: 6)), label: '单元楼下'),
      LocationTrackPoint(latitude: 31.23040, longitude: 121.47370, recordedAt: now.subtract(const Duration(minutes: 2)), label: '家中'),
    ];
    _location = LocationSnapshot(
      latitude: _track.last.latitude,
      longitude: _track.last.longitude,
      address: '上海市黄浦区 · 示例小区（轨迹演示）',
      updatedAt: _track.last.recordedAt,
    );
    _route = _buildRoute(_location);
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

  void _removeElder(String id) => setState(() {
        _elders.removeWhere((x) => x.id == id);
        _contacts.removeWhere((c) => c.elderId == id);
      });

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
      final last = _track.isEmpty ? const (31.23218, 121.47502) : (_track.last.latitude, _track.last.longitude);
      final drift = (DateTime.now().millisecond % 40) / 100000;
      final next = LocationTrackPoint(
        latitude: last.$1 - 0.00018 + drift,
        longitude: last.$2 - 0.00016 + drift / 2,
        recordedAt: DateTime.now(),
        label: '导航刷新点',
      );
      _track = [..._track, next].takeLast(12).toList();
      _location = LocationSnapshot(
        latitude: next.latitude,
        longitude: next.longitude,
        address: '上海市黄浦区 · 老人当前位置（前端导航演示）',
        updatedAt: next.recordedAt,
      );
      _route = _buildRoute(_location);
    });
  }

  NavigationRouteSnapshot _buildRoute(LocationSnapshot location) {
    final distanceKm = _calculateDistanceKm(location.latitude, location.longitude, _homeLatitude, _homeLongitude);
    final minutes = (distanceKm * 12).clamp(3, 35).round();
    final routePoints = [
      RoutePoint(latitude: location.latitude, longitude: location.longitude, label: '老人当前位置'),
      RoutePoint(latitude: (location.latitude + _homeLatitude) / 2 + 0.00035, longitude: (location.longitude + _homeLongitude) / 2 - 0.00022, label: '推荐路口'),
      RoutePoint(latitude: _homeLatitude, longitude: _homeLongitude, label: _homeLabel),
    ];
    final statusText = distanceKm < 0.15 ? '老人已接近家中，可重点查看到家状态' : '当前展示从老人位置返回家中的模拟导航路线';
    return NavigationRouteSnapshot(
      startLabel: '老人当前位置',
      endLabel: _homeLabel,
      distanceKm: distanceKm,
      estimatedMinutes: minutes,
      statusText: statusText,
      points: routePoints,
    );
  }

  double _calculateDistanceKm(double startLat, double startLng, double endLat, double endLng) {
    const latFactor = 111.0;
    const lngFactor = 97.0;
    final lat = (startLat - endLat).abs() * latFactor;
    final lng = (startLng - endLng).abs() * lngFactor;
    return double.parse((lat + lng).toStringAsFixed(2));
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
            track: _track.reversed.toList(),
            route: _route,
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

extension on List<LocationTrackPoint> {
  List<LocationTrackPoint> takeLast(int count) {
    if (length <= count) return this;
    return sublist(length - count);
  }
}
