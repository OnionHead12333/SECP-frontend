import 'package:flutter/material.dart';

import '../../models/child_local_models.dart';
import '../pages/child_water_reminder_page.dart';

/// ⑤ 提醒：生活提醒入口（喝水/锻炼等）。
class ChildReminderTab extends StatelessWidget {
  const ChildReminderTab({
    super.key,
    required this.elders,
  });

  final List<BoundElder> elders;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.water_drop_outlined, '喝水提醒', '设置喝水量与提醒间隔'),
      (Icons.directions_run_outlined, '锻炼提醒', '开发中'),
      (Icons.event_note_outlined, '其他提醒', '开发中'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final it = items[i];
        return Card(
          child: ListTile(
            leading: Icon(it.$1),
            title: Text(it.$2),
            subtitle: Text(it.$3),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (it.$2 == '喝水提醒') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChildWaterReminderPage(elders: elders),
                  ),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「${it.$2}」功能开发中')));
            },
          ),
        );
      },
    );
  }
}

