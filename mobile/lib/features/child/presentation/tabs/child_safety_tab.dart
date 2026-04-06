import 'package:flutter/material.dart';

import '../../models/child_local_models.dart';
import '../widgets/child_location_map.dart';

/// ③ 安全监护：实时定位、活动状态、求助记录处理（其余为占位）。
class ChildSafetyTab extends StatelessWidget {
  const ChildSafetyTab({
    super.key,
    required this.location,
    required this.activity,
    required this.helpRecords,
    required this.onRefreshLocation,
    required this.onResolveHelp,
  });

  final LocationSnapshot location;
  final ActivitySnapshot activity;
  final List<HelpRequestRecord> helpRecords;
  final VoidCallback onRefreshLocation;
  final void Function(String id) onResolveHelp;

  String _fmt(DateTime t) {
    return '${t.month}/${t.day} ${_two(t.hour)}:${_two(t.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('实时定位', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    IconButton.filledTonal(
                      onPressed: onRefreshLocation,
                      icon: const Icon(Icons.my_location),
                      tooltip: '刷新定位',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ChildLocationMap(
                  key: ValueKey(
                    '${location.latitude}_${location.longitude}_${location.updatedAt.millisecondsSinceEpoch}',
                  ),
                  latitude: location.latitude,
                  longitude: location.longitude,
                ),
                const SizedBox(height: 12),
                Text(location.address, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  '纬度 ${location.latitude.toStringAsFixed(5)}  经度 ${location.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text('上次更新：${_fmt(location.updatedAt)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  '国内网络若加载慢，可换高德瓦片或自建 Tile 服务。',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
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
                Text('活动状态', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(icon: Icons.directions_walk, label: '今日步数', value: '${activity.stepsToday}'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(icon: Icons.accessibility_new, label: '状态', value: activity.stateLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('数据更新时间：${_fmt(activity.updatedAt)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('其他', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _PlaceholderRow(title: '历史轨迹', subtitle: '按日查看轨迹回放（待开发）'),
        _PlaceholderRow(title: '地理围栏状态', subtitle: '围栏开关与越界记录（待开发）'),
        _PlaceholderRow(title: '预警消息列表', subtitle: '合并推送与设备告警（待开发）'),
        const SizedBox(height: 16),
        Text('求助记录处理', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (helpRecords.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('暂无求助记录', style: TextStyle(color: scheme.onSurfaceVariant))),
            ),
          )
        else
          ...helpRecords.map((r) {
            final pending = r.status == HelpRequestStatus.pending;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${r.elderName} · ${_fmt(r.createdAt)}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Chip(
                          label: Text(pending ? '待处理' : '已处理'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: pending ? scheme.errorContainer : scheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(r.summary, style: Theme.of(context).textTheme.bodyMedium),
                    if (pending) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () {
                            onResolveHelp(r.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已标记为已处理（本地演示）')),
                            );
                          },
                          child: const Text('标记已处理'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「$title」待开发'))),
      ),
    );
  }
}
