import 'package:flutter/material.dart';

import '../../models/child_local_models.dart';
import '../widgets/child_location_map.dart';

/// ① 首页总览：与后端 `location-summary`、求助列表等一致。
class ChildOverviewTab extends StatelessWidget {
  const ChildOverviewTab({
    super.key,
    required this.elders,
    this.currentElder,
    this.location,
    required this.activity,
    required this.helpRecords,
  });

  final List<BoundElder> elders;
  final BoundElder? currentElder;
  final LocationSnapshot? location;
  final ActivitySnapshot activity;
  final List<HelpRequestRecord> helpRecords;

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final elderName = currentElder?.displayName ?? (elders.isEmpty ? null : elders.first.displayName) ?? '未选择';
    final pending = helpRecords.where((r) => r.status == HelpRequestStatus.pending).toList();
    final loc = location;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('老人今日状态', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        elders.isEmpty
                            ? '请先在「设置」中通过家庭绑定确认已关联的老人'
                            : '当前：$elderName · 状态以后端活动/定位为准',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('是否已服药', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '用药进度请见「医疗管理 → 远程添加医疗事项」及老人端数据',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('生活提醒', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '喝水/用药等见底部「提醒」',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前定位 / 活动状态', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                if (loc == null)
                  Text('暂无定位（老人端未上传轨迹或网络异常）', style: Theme.of(context).textTheme.bodyMedium)
                else ...[
                  ChildLocationMap(
                    key: ValueKey(
                      '${loc.latitude}_${loc.longitude}_${loc.updatedAt.millisecondsSinceEpoch}',
                    ),
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                    useOfflinePainter: true,
                  ),
                  const SizedBox(height: 10),
                  Text(loc.address, style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    '坐标 ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} · 更新 ${_fmtTime(loc.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '活动/在家推断：${activity.stateLabel} · 今日步数（若有设备接入）${activity.stepsToday} · 更新 ${_fmtTime(activity.updatedAt)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: pending.isNotEmpty ? scheme.errorContainer.withOpacity(0.35) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: pending.isNotEmpty ? scheme.error : scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('安全求助', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                if (pending.isEmpty)
                  Text('暂无待处理求助', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
                else
                  Text(
                    '${pending.first.elderName} · ${_fmtTime(pending.first.createdAt)}\n${pending.first.summary}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
