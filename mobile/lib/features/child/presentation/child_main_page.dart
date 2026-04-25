import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/child_elder_directory_service.dart';
import '../data/child_emergency_alerts_api.dart';
import '../data/child_geofence_api.dart';
import '../data/child_location_summary_api.dart';
import '../models/child_local_models.dart';
import 'tabs/child_medical_tab.dart';
import 'tabs/child_overview_tab.dart';
import 'tabs/child_reminder_tab.dart';
import 'tabs/child_safety_tab.dart';
import 'tabs/child_settings_tab.dart';

/// 子女端：底部五模块 — 数据来自已有后端（定位摘要、求助、紧急联系人、家围栏等）。
class ChildMainPage extends StatefulWidget {
  const ChildMainPage({super.key});

  @override
  State<ChildMainPage> createState() => _ChildMainPageState();
}

class _ChildMainPageState extends State<ChildMainPage> {
  int _navIndex = 0;
  String? _selectedElderId;
  bool _loading = true;

  List<BoundElder> _elders = const [];
  List<HelpRequestRecord> _helpRecords = const [];
  LocationSnapshot? _location;
  List<LocationTrackPoint> _track = const [];
  NavigationRouteSnapshot? _route;
  late ActivitySnapshot _activity;

  @override
  void initState() {
    super.initState();
    _activity = ActivitySnapshot(
      stepsToday: 0,
      stateLabel: '加载中',
      updatedAt: DateTime.now(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _elderIdOrNull {
    final id = _selectedElderId;
    if (id == null) return null;
    return int.tryParse(id) != null ? id : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final now = DateTime.now();
    try {
      final elders = await ChildElderDirectoryService.resolveElders();
      if (elders.isNotEmpty) {
        if (_selectedElderId == null || !elders.any((e) => e.id == _selectedElderId)) {
          _selectedElderId = elders.first.id;
        }
      } else {
        _selectedElderId = null;
      }

      final help = <HelpRequestRecord>[];
      try {
        final page = await ChildEmergencyAlertsApi.list(page: 1, pageSize: 200);
        final list = page['list'];
        if (list is List) {
          for (final item in list) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item);
            final aid = '${m['alertId'] ?? m['id'] ?? ''}'.trim();
            if (aid.isEmpty) continue;
            final st = m['status'] as String? ?? '';
            final pending = st == 'sent';
            help.add(
              HelpRequestRecord(
                id: aid,
                elderName: m['elderName'] as String? ?? '老人',
                createdAt: _parseAnyTime(m['triggerTime'] ?? m['sentTime']) ?? now,
                summary: st == 'sent' ? '安全求助，待处理' : '已处理/已核对',
                status: pending ? HelpRequestStatus.pending : HelpRequestStatus.resolved,
              ),
            );
          }
        }
      } catch (_) {
        // 忽略
      }
      _helpRecords = help;

      if (_elderIdOrNull == null) {
        setState(() {
          _elders = elders;
          _location = null;
          _track = const [];
          _route = null;
          _activity = ActivitySnapshot(
            stepsToday: 0,
            stateLabel: '无绑定老人',
            updatedAt: now,
          );
        });
        return;
      }

      final eid = int.parse(_elderIdOrNull!);
      ChildLocationSummary? loc;
      try {
        loc = await ChildLocationSummaryApi.fetch(eid);
      } catch (_) {
        loc = null;
      }

      if (loc != null) {
        final t = _parseAnyTime(loc.updatedAt) ?? now;
        _location = LocationSnapshot(
          latitude: loc.latitude,
          longitude: loc.longitude,
          address: (loc.address != null && loc.address!.trim().isNotEmpty)
              ? loc.address!
              : (loc.isHome == true ? '在家（基于家围栏/定位）' : '外出（最新定位点）'),
          updatedAt: t,
        );
        _track = [
          LocationTrackPoint(
            latitude: loc.latitude,
            longitude: loc.longitude,
            recordedAt: t,
            label: '最新定位',
          ),
        ];
        _activity = ActivitySnapshot(
          stepsToday: 0,
          stateLabel: loc.isHome == true
              ? '当前推断：在家'
              : (loc.presenceSource == 'gaode_fallback' ? '当前推断：外出' : '活动状态已更新'),
          updatedAt: t,
        );
      } else {
        _location = null;
        _track = const [];
        _activity = ActivitySnapshot(
          stepsToday: 0,
          stateLabel: '暂无定位数据（老人端未上报或尚未同步）',
          updatedAt: now,
        );
      }

      _route = await _buildRouteForElder(
        eid: eid,
        loc: _location,
        homeLabel: _elderNameForSelected(),
      );

      if (!mounted) return;
      setState(() {
        _elders = elders;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _elderNameForSelected() {
    final id = _selectedElderId;
    if (id == null) return '家';
    return _elders.firstWhere((e) => e.id == id, orElse: () => BoundElder(id: id, displayName: '家')).displayName;
  }

  static DateTime? _parseAnyTime(Object? o) {
    if (o == null) return null;
    if (o is DateTime) return o;
    if (o is int) {
      return DateTime.fromMillisecondsSinceEpoch(o);
    }
    final s = o.toString();
    final a = DateTime.tryParse(s);
    if (a != null) return a;
    return null;
  }

  Future<NavigationRouteSnapshot?> _buildRouteForElder({
    required int eid,
    required LocationSnapshot? loc,
    required String homeLabel,
  }) async {
    if (loc == null) return null;
    double homeLat;
    double homeLng;
    String endLabel;
    final geo = await ChildGeofenceApi.firstHomePoint(eid);
    if (geo != null) {
      homeLat = geo.latitude;
      homeLng = geo.longitude;
      endLabel = geo.name == null || geo.name!.isEmpty ? homeLabel : geo.name!;
    } else {
      homeLat = loc.latitude;
      homeLng = loc.longitude;
      endLabel = '家（无围栏，参考当前点）';
    }
    final distanceKm = _calculateDistanceKm(loc.latitude, loc.longitude, homeLat, homeLng);
    final minutes = (distanceKm * 12).clamp(2, 90).round();
    final routePoints = <RoutePoint>[
      RoutePoint(latitude: loc.latitude, longitude: loc.longitude, label: '老人当前位置'),
      RoutePoint(
        latitude: (loc.latitude + homeLat) / 2,
        longitude: (loc.longitude + homeLng) / 2,
        label: '参考路径',
      ),
      RoutePoint(latitude: homeLat, longitude: homeLng, label: endLabel),
    ];
    final statusText = distanceKm < 0.1 ? '已接近家围栏中心/参考点' : '直线参考距离（非导航引擎规划）';
    return NavigationRouteSnapshot(
      startLabel: '老人当前位置',
      endLabel: endLabel,
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

  void _logout(BuildContext context) {
    AuthSession.clear();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  Future<void> _onResolveHelp(String alertId) async {
    final id = int.tryParse(alertId);
    if (id == null) return;
    try {
      await ChildEmergencyAlertsApi.handle(alertId: id, action: 'handled', remark: '');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已标记为已处理')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请稍后重试')),
        );
      }
    }
  }

  static const _titles = ['首页总览', '医疗管理', '提醒', '安全监护', '设置'];

  /// 与「选老人」下拉一致：无列表则 null，否则为当前选中或列表首位。
  BoundElder? get _currentElder {
    final id = _selectedElderId;
    if (_elders.isEmpty) return null;
    if (id != null) {
      for (final e in _elders) {
        if (e.id == id) return e;
      }
    }
    return _elders.first;
  }

  Widget _buildTabBody() {
    switch (_navIndex) {
      case 0:
        return ChildOverviewTab(
          elders: _elders,
          currentElder: _currentElder,
          location: _location,
          activity: _activity,
          helpRecords: _helpRecords,
        );
      case 1:
        return ChildMedicalTab(elders: _elders);
      case 2:
        return ChildReminderTab(elders: _elders);
      case 3:
        return ChildSafetyTab(
          location: _location,
          track: _track.reversed.toList(),
          route: _route,
          activity: _activity,
          helpRecords: _helpRecords,
          onRefreshLocation: () {
            _load();
          },
          onResolveHelp: _onResolveHelp,
        );
      case 4:
        return ChildSettingsTab(
          elders: _elders,
          onEldersChanged: _load,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_navIndex]),
        actions: [
          if (_elders.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedElderId != null && _elders.any((e) => e.id == _selectedElderId) ? _selectedElderId : null,
                  hint: const Text('选老人', style: TextStyle(fontSize: 14, color: Colors.white70)),
                  dropdownColor: Theme.of(context).colorScheme.primaryContainer,
                  items: _elders
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.displayName, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedElderId = v);
                    _load();
                  },
                ),
              ),
            ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
          ),
        ],
      ),
      // 不用 IndexedStack：否则五个子页会同时 build，含地图的「首页+安全」会各创建一个高德
      // 原生子视图，易双实例闪退。这里只构建当前 Tab，切页时再重建。
      body: KeyedSubtree(
        key: ValueKey<int>(_navIndex),
        child: _buildTabBody(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '首页'),
          NavigationDestination(icon: Icon(Icons.medical_services_outlined), selectedIcon: Icon(Icons.medical_services), label: '医疗'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: '提醒'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: '安全'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
