import 'package:flutter/material.dart';

import '../models/elder_outing_status.dart';

class ElderOutingSummaryPage extends StatelessWidget {
  const ElderOutingSummaryPage({
    super.key,
    required this.status,
    required this.onRefresh,
    required this.onOpenLocationDetail,
  });

  final ElderOutingStatus status;
  final Future<ElderOutingStatus> Function() onRefresh;
  final VoidCallback onOpenLocationDetail;

  String _fmt(DateTime? t) {
    if (t == null) return '-';
    final local = t.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  String _stateLabel(String raw) => raw == 'outside' ? '外出中' : '在家';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('外出提醒')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('外出状态', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('这里展示定位与外出监测的摘要信息。', style: TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 16),
            _card(
              title: '当前状态',
              lines: [
                '定位：${status.locationEnabled ? '已开启' : '未开启'}',
                '监测：${status.monitorStatus}',
                '状态：${_stateLabel(status.currentState)}',
              ],
            ),
            const SizedBox(height: 12),
            _card(
              title: '最近记录',
              lines: [
                '外出开始：${_fmt(status.outsideStartAt)}',
                '最近上报：${_fmt(status.lastUploadAt)}',
                '最近位置：${status.lastLocationDesc ?? '-'}',
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpenLocationDetail,
                child: const Text('查看定位详情'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final latest = await onRefresh();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ElderOutingSummaryPage(
                        status: latest,
                        onRefresh: onRefresh,
                        onOpenLocationDetail: onOpenLocationDetail,
                      ),
                    ),
                  );
                },
                child: const Text('刷新状态'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required List<String> lines}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final l in lines) ...[
            Text(l),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

