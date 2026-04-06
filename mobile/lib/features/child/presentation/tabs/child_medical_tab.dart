import 'package:flutter/material.dart';

/// ② 医疗管理：MVP 结构占位，与产品定义一致，后续接页面与接口。
class ChildMedicalTab extends StatelessWidget {
  const ChildMedicalTab({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.add_task_outlined, '远程添加医疗事项', '创建用药、复诊等提醒'),
      (Icons.calendar_month_outlined, '医疗日历', '按日历查看医疗安排'),
      (Icons.folder_open_outlined, '医疗档案', '病历与报告摘要'),
      (Icons.monitor_heart_outlined, '健康数据', '体征趋势与记录'),
      (Icons.smart_toy_outlined, 'AI 医疗助手', '问答与健康建议（待接入）'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('「${it.$2}」功能开发中')),
              );
            },
          ),
        );
      },
    );
  }
}
