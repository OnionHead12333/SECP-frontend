import 'package:flutter/material.dart';

import '../../models/child_local_models.dart';

/// ① 首页总览：老人状态、服药、提醒、定位/活动、异常摘要（演示数据）。
class ChildOverviewTab extends StatelessWidget {
  const ChildOverviewTab({
    super.key,
    required this.elders,
    required this.location,
    required this.activity,
    required this.helpRecords,
  });

  final List<BoundElder> elders;
  final LocationSnapshot location;
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
    final elderName = elders.isEmpty ? '未绑定老人' : elders.first.displayName;
    final pending = helpRecords.where((r) => r.status == HelpRequestStatus.pending).toList();

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
                        elders.isEmpty ? '请先在「设置」中绑定老人账号' : '$elderName · 精神尚可，饮食正常（演示）',
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
                const SizedBox(height: 12),
                _MedRow(label: '上午药', done: true),
                const Divider(height: 20),
                _MedRow(label: '中午药', done: false),
                const Divider(height: 20),
                _MedRow(label: '晚间药', done: false),
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
                Text('今日提醒完成情况', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: 2 / 4, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                Text('已完成 2 / 4 项（演示）', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
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
                const SizedBox(height: 8),
                Text(location.address, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '坐标 ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)} · 更新 ${_fmtTime(location.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Text(
                  '活动：${activity.stateLabel} · 今日步数 ${activity.stepsToday} · 更新 ${_fmtTime(activity.updatedAt)}',
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
                    Text('最新异常提醒', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                if (pending.isEmpty)
                  Text('暂无待处理异常（演示）', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
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

class _MedRow extends StatelessWidget {
  const _MedRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : Colors.grey),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
        Text(done ? '已服' : '待服', style: TextStyle(color: done ? Colors.green : Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}
