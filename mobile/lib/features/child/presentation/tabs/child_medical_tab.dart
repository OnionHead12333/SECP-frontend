import 'package:flutter/material.dart';

import '../../../medical_hub/presentation/medical_archive_page.dart';
import '../../../medical_hub/presentation/medical_calendar_page.dart';
import '../../../medical_hub/presentation/medical_smart_hub_page.dart';
import '../../models/child_local_models.dart';
import '../pages/child_ai_medical_assistant_page.dart';
import '../pages/child_remote_medical_item_page.dart';

/// ② 医疗管理：MVP 结构占位，与产品定义一致，后续接页面与接口。
class ChildMedicalTab extends StatelessWidget {
  const ChildMedicalTab({
    super.key,
    required this.elders,
    this.currentElder,
  });

  final List<BoundElder> elders;
  final BoundElder? currentElder;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.document_scanner_outlined, '拍照识别单据', '拍摄或上传处方、检查单等'),
      (Icons.add_task_outlined, '远程添加医疗事项', '创建用药、复诊等提醒'),
      (Icons.calendar_month_outlined, '医疗日历', '按日历查看医疗安排'),
      (Icons.folder_open_outlined, '医疗档案', '病历与报告摘要'),
      (Icons.smart_toy_outlined, 'AI 医疗助手', '问答与健康建议，支持风险提示'),
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
              if (it.$2 == '拍照识别单据') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MedicalSmartHubPage(elders: elders),
                  ),
                );
                return;
              }
              if (it.$2 == '医疗日历') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MedicalCalendarPage(elders: elders),
                  ),
                );
                return;
              }
              if (it.$2 == '医疗档案') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MedicalArchivePage(elders: elders),
                  ),
                );
                return;
              }
              if (it.$2 == '远程添加医疗事项') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChildRemoteMedicalItemPage(elders: elders),
                  ),
                );
                return;
              }
              if (it.$2 == 'AI 医疗助手') {
                final elder = currentElder ?? (elders.isNotEmpty ? elders.first : null);
                final elderId = int.tryParse(elder?.id ?? '');
                if (elder == null || elderId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请先绑定并选择老人后再使用 AI 医疗助手')),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChildAiMedicalAssistantPage(
                      elderProfileId: elderId,
                      elderName: elder.displayName,
                    ),
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
