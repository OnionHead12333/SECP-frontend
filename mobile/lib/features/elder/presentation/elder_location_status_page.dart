import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_location_service.dart';
import '../models/elder_location_point.dart';

class ElderLocationStatusPage extends StatefulWidget {
  const ElderLocationStatusPage({super.key});
  @override
  State<ElderLocationStatusPage> createState() => _ElderLocationStatusPageState();
}

class _ElderLocationStatusPageState extends State<ElderLocationStatusPage> {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final granted = await ElderLocationService.requestPermission();
      if (!granted) {
        setState(() => _error = '未获得定位权限，请在系统设置中开启');
        return;
      }
      await ElderLocationService.startAutoUpload(AuthSession.elderPhone ?? '');
      await _refreshTrack();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final latest = _state.latestPoint ?? (_track.isEmpty ? null : _track.first);
    final ready = _state.permissionGranted && _state.serviceEnabled;
    return Scaffold(
      appBar: AppBar(title: const Text('定位服务状态')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('定位服务状态', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('老人手机号：${AuthSession.elderPhone ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(!ready ? '最近状态：待开启守护轨迹' : latest == null ? '最近状态：等待首次定位' : latest.isHome ? '最近状态：家附近' : '最近状态：外出', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('当前先保留后端上传接口，同时按“树莓派蓝牙断开、老人处于户外”这个场景来做页面扩展。', style: const TextStyle(color: Color(0xFF475569), height: 1.6)),
                  const SizedBox(height: 8),
                  Text(_state.uploadStatusText, style: const TextStyle(color: Color(0xFF0F766E), height: 1.6)),
                ])),
                const SizedBox(height: 16),
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('权限与状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _InfoRow(title: '运行场景', value: '树莓派蓝牙断开 / 户外扩展预留', ok: true),
                  const SizedBox(height: 10),
                  _InfoRow(title: '定位权限', value: _state.permissionGranted ? '已就绪' : '未授权', ok: _state.permissionGranted),
                  const SizedBox(height: 10),
                  _InfoRow(title: '定位服务', value: _state.serviceEnabled ? '已开启' : '未开启', ok: _state.serviceEnabled),
                  const SizedBox(height: 10),
                  _InfoRow(title: '上传内容', value: '经纬度 + 时间 + 来源（后端保留）', ok: true),
                  const SizedBox(height: 10),
                  _InfoRow(title: '后端接口', value: '已预留 /v1/elder/location-tracks', ok: true),
                  if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C)))],
                  const SizedBox(height: 14),
                  FilledButton.icon(onPressed: ready || _requesting ? null : _requestPermission, icon: Icon(ready ? Icons.check_circle : Icons.route), label: Text(_requesting ? '切换中...' : (ready ? '轨迹采集已可用' : '启动守护轨迹测试'))),
                ])),
                const SizedBox(height: 16),
                _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('点击测试经纬度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  const Text('点击下面按钮，直接测试当前设备能否获取到真实经纬度，同时保留后端上传链路。', style: TextStyle(color: Color(0xFF475569), height: 1.6)),
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
  Widget build(BuildContext context) => _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(point.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text('时间：${point.recordedAt.month}/${point.recordedAt.day} ${point.recordedAt.hour.toString().padLeft(2, '0')}:${point.recordedAt.minute.toString().padLeft(2, '0')}'), const SizedBox(height: 6), Text('纬度 ${point.latitude.toStringAsFixed(5)}  经度 ${point.longitude.toStringAsFixed(5)}', style: const TextStyle(color: Color(0xFF475569))), const SizedBox(height: 6), Text('来源：${point.source} · ${point.uploaded ? '已上传后端' : '当前前端测试/本机缓存'}', style: const TextStyle(color: Color(0xFF64748B)))]));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value, required this.ok});
  final String title, value;
  final bool ok;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))), Text(value, style: TextStyle(color: ok ? const Color(0xFF166534) : const Color(0xFFB45309), fontWeight: FontWeight.w700))]);
}
