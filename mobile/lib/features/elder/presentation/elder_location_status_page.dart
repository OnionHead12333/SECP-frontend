import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_location_service.dart';
import '../models/elder_location_point.dart';

class ElderLocationStatusPage extends StatefulWidget {
  const ElderLocationStatusPage({super.key});
  @override
  State<ElderLocationStatusPage> createState() => _ElderLocationStatusPageState();
}

class _ElderLocationStatusPageState extends State<ElderLocationStatusPage> {
  static const String _autoGuideShownKey = 'elder_location_auto_permission_guide_shown_v1';

  bool _loading = true, _requesting = false, _capturing = false;
  String? _error;
  List<ElderLocationPoint> _track = const [];
  ElderLocationState _state = const ElderLocationState();
  StreamSubscription<ElderLocationState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ElderLocationService.stream.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      unawaited(_refreshTrack());
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final phone = AuthSession.elderPhone ?? '';
    try {
      final state = await ElderLocationService.initialize(phone);
      final track = await ElderLocationService.fetchTrack(phone);
      if (!mounted) return;
      setState(() {
        _state = state;
        _track = track;
        _loading = false;
      });
      unawaited(_showFirstOpenPermissionGuideIfNeeded());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _showFirstOpenPermissionGuideIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_autoGuideShownKey) ?? false;
    if (!mounted || alreadyShown || _state.autoUploadEnabled) return;
    await prefs.setBool(_autoGuideShownKey, true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('开启定位守护权限'),
          content: const Text(
            '为了让子女端及时看到您的安全位置，并支持语音求助/撤回，接下来会依次申请通知、麦克风、定位权限，并尝试开启定位守护。\n\n'
            '安卓系统不允许软件刚下载完成就自动弹权限，必须在首次打开 App 后由用户确认。后台定位、电池优化等权限在部分手机上还需要到系统设置里手动开启。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_requestPermission());
              },
              child: const Text('立即开启'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _requestPermission() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      // 与国产机场景一致：系统「定位总开关」关闭时，系统不会弹出应用定位授权，易误以为按钮无反应，须先打开定位服务
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          await _showLocationServiceOffDialog();
        }
        if (!await Geolocator.isLocationServiceEnabled()) {
          if (mounted) {
            setState(() {
              _error = '系统定位总开关未开启。已弹出说明：请从屏幕顶部下滑打开「位置信息」或到系统设置中打开定位。';
            });
            _showMessage('请先打开手机定位服务，再点「开启定位守护」重试。');
          }
          return;
        }
      }

      final granted = await ElderLocationService.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _error = '未获得应用定位权限。请在系统设置 → 本应用 → 位置，选择「使用期间」或「始终」允许；若已拒绝，请点「去设置」打开。';
          });
          _showMessage('需要定位权限才能开启守护。可在本页下方红色说明中按提示到设置里修改。');
        }
        if (await Permission.location.status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return;
      }
      await ElderLocationService.startAutoUpload(AuthSession.elderPhone ?? '');
      await _refreshTrack();
      if (mounted) {
        _showMessage('已启动。若需退出后仍定位，请在本应用系统设置中把位置改为「始终允许」，并视机型允许后台运行/关闭电池优化。');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
        _showMessage(_error!);
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 4)));
  }

  /// 当系统级定位总开关为关时，引导用户到系统设置打开（与小米/OPPO 等分步授权一致，仅靠应用内弹窗无法代开总开关）
  Future<void> _showLocationServiceOffDialog() async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('请先打开系统定位'),
        content: const Text(
            '手机「位置信息/定位服务」总开关为关闭。此时应用无法向系统申请定位，按钮会像没有反应。请先打开定位总开关；再在本应用里允许定位；若需锁屏/退出后仍上传，请在应用权限中改为「始终允许」，并在系统设置中允许后台运行。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('稍后再说')),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Geolocator.openLocationSettings();
            },
            child: const Text('去打开定位服务'),
          ),
        ],
      ),
    );
  }

  Future<void> _captureNow() async {
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      await ElderLocationService.captureTestPoint(AuthSession.elderPhone ?? '');
      await _refreshTrack();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _refreshTrack() async {
    final track = await ElderLocationService.fetchTrack(AuthSession.elderPhone ?? '');
    if (mounted) setState(() => _track = track);
  }

  String _guardModeText(String? mode) {
    switch (mode) {
      case 'background':
        return '后台守护';
      case 'foreground':
        return '前台定位';
      case 'off':
        return '关闭';
      default:
        return '-';
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    return '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final latest = _state.latestPoint ?? (_track.isEmpty ? null : _track.first);
    final ready = _state.permissionGranted && _state.serviceEnabled;
    return Scaffold(
      appBar: AppBar(title: const Text('定位服务状态')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_requesting || _state.isUploading) ...[
                  const LinearProgressIndicator(minHeight: 3),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '正在与高德或服务器通信，可能需要数秒，请勿反复点按钮',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('定位服务状态', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('老人手机号：${AuthSession.elderPhone ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(!ready ? '最近状态：待开启守护轨迹' : latest == null ? '最近状态：等待首次定位' : latest.isHome ? '最近状态：家附近' : '最近状态：外出', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('当前先按“树莓派蓝牙断开、老人处于户外”这个场景来跑高德定位，并把定位权限状态与轨迹上传到后端老人端接口。', style: TextStyle(color: Color(0xFF475569), height: 1.6)),
                  const SizedBox(height: 8),
                  Text(_state.uploadStatusText, style: const TextStyle(color: Color(0xFF0F766E), height: 1.6)),
                  if (_state.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(_state.lastError!, style: const TextStyle(color: Color(0xFFB91C1C), height: 1.5)),
                  ],
                ])),
                const SizedBox(height: 16),
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('权限与状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const _InfoRow(title: '运行场景', value: '树莓派蓝牙断开 / 户外高德定位', ok: true),
                  const SizedBox(height: 10),
                  _InfoRow(title: '定位权限', value: _state.permissionGranted ? '已就绪' : '未授权', ok: _state.permissionGranted),
                  const SizedBox(height: 10),
                  _InfoRow(title: '后台定位权限', value: _state.backgroundPermissionGranted ? '已授权' : '未授权', ok: _state.backgroundPermissionGranted),
                  const SizedBox(height: 10),
                  _InfoRow(title: '定位服务', value: _state.serviceEnabled ? '已开启' : '未开启', ok: _state.serviceEnabled),
                  const SizedBox(height: 10),
                  _InfoRow(title: '守护开关', value: _state.guardSetting?.enabled == true || _state.autoUploadEnabled ? '已开启' : '未开启', ok: _state.guardSetting?.enabled == true || _state.autoUploadEnabled),
                  const SizedBox(height: 10),
                  _InfoRow(title: '守护模式', value: _guardModeText(_state.guardSetting?.mode), ok: _state.guardSetting?.enabled == true || _state.autoUploadEnabled),
                  const SizedBox(height: 10),
                  _InfoRow(title: '最近上传', value: _formatDateTime(_state.guardSetting?.lastUploadAt), ok: _state.guardSetting?.lastUploadAt != null),
                  const SizedBox(height: 10),
                  const _InfoRow(title: '上传内容', value: '户外经纬度 + 时间 + 来源', ok: true),
                  const SizedBox(height: 10),
                  const _InfoRow(title: '后端接口', value: '/v1/elder/location-guard 与 /location-tracks', ok: true),
                  if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C)))],
                  const SizedBox(height: 14),
                  if (_state.autoUploadEnabled)
                    FilledButton.icon(onPressed: _requesting ? null : () async {
                      setState(() => _requesting = true);
                      await ElderLocationService.stopAutoUpload();
                      if (mounted) setState(() => _requesting = false);
                    }, icon: const Icon(Icons.pause_circle), label: Text(_requesting ? '处理中...' : '关闭定位守护'))
                  else
                    FilledButton.icon(onPressed: _requesting ? null : _requestPermission, icon: Icon(ready ? Icons.play_circle : Icons.route), label: Text(_requesting ? '切换中...' : (ready ? '开启定位守护' : '启动守护轨迹测试'))),
                ])),
                const SizedBox(height: 16),
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('点击测试经纬度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  const Text('点击下面按钮，直接测试当前设备能否获取到高德经纬度，并按蓝牙断开后的户外场景立即上传到后端。', style: TextStyle(color: Color(0xFF475569), height: 1.6)),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _capturing ? null : _captureNow, icon: const Icon(Icons.my_location), label: Text(_capturing ? '测试中...' : '点击测试是否能测出经纬度')),
                ])),
                const SizedBox(height: 16),
                Row(children: [const Expanded(child: Text('本机轨迹记录', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))), TextButton.icon(onPressed: _refreshTrack, icon: const Icon(Icons.refresh), label: const Text('刷新列表'))]),
                const SizedBox(height: 12),
                if (_track.isEmpty)
                  const _Card(child: Text('暂无本机轨迹记录。请先启动守护轨迹测试。', style: TextStyle(height: 1.6, color: Color(0xFF475569))))
                else
                  ..._track.take(5).map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TrackCard(point: p))),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))), child: child);
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.point});
  final ElderLocationPoint point;
  @override
  Widget build(BuildContext context) => _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(point.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text('时间：${point.recordedAt.month}/${point.recordedAt.day} ${point.recordedAt.hour.toString().padLeft(2, '0')}:${point.recordedAt.minute.toString().padLeft(2, '0')}'), const SizedBox(height: 6), Text('纬度 ${point.latitude.toStringAsFixed(5)}  经度 ${point.longitude.toStringAsFixed(5)}', style: const TextStyle(color: Color(0xFF475569))), const SizedBox(height: 6), Text('来源：${point.source} · ${point.uploaded ? '已上传后端' : '上传失败/本机缓存'}', style: const TextStyle(color: Color(0xFF64748B)))]));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value, required this.ok});
  final String title, value;
  final bool ok;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 4,
            softWrap: true,
            style: TextStyle(
              color: ok ? const Color(0xFF166534) : const Color(0xFFB45309),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
