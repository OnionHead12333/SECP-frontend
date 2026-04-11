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
  bool _loading = true;
  bool _requestingPermission = false;
  String? _error;
  List<ElderLocationPoint> _track = const [];
  ElderLocationState _state = const ElderLocationState();
  StreamSubscription<ElderLocationState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ElderLocationService.stream.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
      if (_state.permissionGranted && _state.serviceEnabled) {
        await ElderLocationService.startAutoUpload(phone);
        await _refreshTrack();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _requestPermissionAndStart() async {
    setState(() {
      _requestingPermission = true;
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
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  Future<void> _refreshTrack() async {
    final track = await ElderLocationService.fetchTrack(AuthSession.elderPhone ?? '');
    if (!mounted) return;
    setState(() => _track = track);
  }

  @override
  Widget build(BuildContext context) {
    final latest = _state.latestPoint ?? (_track.isEmpty ? null : _track.first);
    return Scaffold(
      appBar: AppBar(title: const Text('定位服务状态')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _SummaryCard(phone: AuthSession.elderPhone ?? '-', state: _state, latest: latest),
                const SizedBox(height: 16),
                _PermissionCard(
                  state: _state,
                  requesting: _requestingPermission,
                  error: _error,
                  onRequest: _requestPermissionAndStart,
                ),
                const SizedBox(height: 16),
                _ServiceStatusCard(state: _state, latest: latest),
                const SizedBox(height: 16),
                if (latest != null) _PolicyCard(point: latest),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('最近上传记录', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    TextButton.icon(onPressed: _refreshTrack, icon: const Icon(Icons.refresh), label: const Text('刷新')),
                  ],
                ),
                const SizedBox(height: 12),
                if (_track.isEmpty)
                  const _EmptyTrackCard()
                else
                  ..._track.take(3).map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TrackCard(point: point),
                      )),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.phone, required this.state, required this.latest});

  final String phone;
  final ElderLocationState state;
  final ElderLocationPoint? latest;

  @override
  Widget build(BuildContext context) {
    final stateText = !state.permissionGranted
        ? '最近状态：待开启定位授权'
        : latest == null
            ? '最近状态：等待首次定位'
            : latest!.isHome
                ? '最近状态：家附近'
                : '最近状态：外出';
    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('定位服务状态', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('老人手机号：$phone'),
        const SizedBox(height: 8),
        Text(stateText, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          state.usingMock ? '当前为演示模式：定位结果使用本地模拟数据。切换到真实模式后，会申请定位权限并自动上传到后端。' : '老人不用手动上传。系统会在获得定位权限后自动采集当前位置并自动上传到后端。',
          style: const TextStyle(color: Color(0xFF475569), height: 1.6),
        ),
      ]),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.state, required this.requesting, required this.error, required this.onRequest});

  final ElderLocationState state;
  final bool requesting;
  final String? error;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final ready = state.permissionGranted && state.serviceEnabled;
    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('权限与系统设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _RowItem(title: '定位权限', value: state.permissionGranted ? '已授权' : '未授权', ok: state.permissionGranted),
        const SizedBox(height: 10),
        _RowItem(title: '定位服务', value: state.serviceEnabled ? '已开启' : '未开启', ok: state.serviceEnabled),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: ready || requesting ? null : onRequest,
          icon: Icon(ready ? Icons.check_circle : Icons.location_on),
          label: Text(requesting ? '授权中...' : (ready ? '定位已可用' : '开启定位权限')),
        ),
      ]),
    );
  }
}

class _ServiceStatusCard extends StatelessWidget {
  const _ServiceStatusCard({required this.state, required this.latest});

  final ElderLocationState state;
  final ElderLocationPoint? latest;

  String _fmt(DateTime t) => '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('当前服务摘要', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _ChipRow(label: '定位来源', value: state.usingMock ? '本地演示' : '高德定位'),
        const SizedBox(height: 10),
        const _ChipRow(label: '上传方式', value: '系统自动上传'),
        const SizedBox(height: 10),
        _ChipRow(label: '自动上传状态', value: state.isUploading ? '上传中' : (state.autoUploadEnabled ? '运行中' : '待开启')),
        const SizedBox(height: 10),
        _ChipRow(label: '最近上传', value: latest == null ? '暂无记录' : _fmt(latest!.recordedAt)),
      ]),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.point});
  final ElderLocationPoint point;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('自动上传策略说明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(ElderLocationService.uploadIntervalText(isOutside: !point.isHome), style: const TextStyle(height: 1.6)),
        const SizedBox(height: 6),
        const Text('当前阶段先使用高德定位自动上传位置；未来树莓派蓝牙接入后，蓝牙断开会先缓冲再结合定位确认。', style: TextStyle(color: Color(0xFF64748B), height: 1.5)),
      ]),
    );
  }
}

class _EmptyTrackCard extends StatelessWidget {
  const _EmptyTrackCard();
  @override
  Widget build(BuildContext context) => const _SectionCard(child: Text('暂无上传记录。完成授权后，系统会自动采集定位并上传。', style: TextStyle(height: 1.6, color: Color(0xFF475569))));
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.point});
  final ElderLocationPoint point;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(point.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('时间：${point.recordedAt.month}/${point.recordedAt.day} ${point.recordedAt.hour.toString().padLeft(2, '0')}:${point.recordedAt.minute.toString().padLeft(2, '0')}'),
        const SizedBox(height: 6),
        Text('纬度 ${point.latitude.toStringAsFixed(5)}  经度 ${point.longitude.toStringAsFixed(5)}', style: const TextStyle(color: Color(0xFF475569))),
        const SizedBox(height: 6),
        Text('来源：${point.source} · ${point.uploaded ? '已上传' : '待上传'}', style: const TextStyle(color: Color(0xFF64748B))),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: child,
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({required this.title, required this.value, required this.ok});
  final String title;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))), Text(value, style: TextStyle(color: ok ? const Color(0xFF166534) : const Color(0xFFB45309), fontWeight: FontWeight.w700))]);
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]);
  }
}
