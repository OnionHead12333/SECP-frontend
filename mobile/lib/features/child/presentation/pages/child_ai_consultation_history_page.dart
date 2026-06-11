import 'package:flutter/material.dart';

import '../../data/child_ai_medical_assistant_api.dart';
import '../../models/ai_consultation_model.dart';

class ChildAiConsultationHistoryPage extends StatefulWidget {
  const ChildAiConsultationHistoryPage({
    super.key,
    required this.elderlyId,
  });

  final int elderlyId;

  @override
  State<ChildAiConsultationHistoryPage> createState() =>
      _ChildAiConsultationHistoryPageState();
}

class _ChildAiConsultationHistoryPageState extends State<ChildAiConsultationHistoryPage> {
  late Future<List<AiConsultationHistoryItem>> _future = _load();

  Future<List<AiConsultationHistoryItem>> _load() {
    return ChildAiMedicalAssistantApi.getConsultationHistory(
      elderlyId: widget.elderlyId,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openDetail(AiConsultationHistoryItem item) async {
    final id = item.consultationId;
    if (id == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return FutureBuilder<AiConsultationDetail>(
              future: ChildAiMedicalAssistantApi.getConsultationDetail(id),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '详情加载失败，请稍后重试。',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }
                final detail = snapshot.data;
                if (detail == null) {
                  return const Center(child: Text('暂无详情内容'));
                }
                return _DetailSheet(
                  detail: detail,
                  scrollController: scrollController,
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(title: const Text('咨询历史')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AiConsultationHistoryItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 44,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      '历史记录加载失败，请下拉重试。',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            }

            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 46,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      '还没有咨询记录，先去发起一次咨询吧。',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _HistoryCard(
                  item: item,
                  onTap: () => _openDetail(item),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.onTap,
  });

  final AiConsultationHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _riskPalette(item.riskLevel);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.$1,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _riskLabel(item.riskLevel),
                      style: TextStyle(
                        color: palette.$2,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.inputText.isEmpty ? '本次咨询' : item.inputText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.needMedicalVisit
                    ? '系统建议尽快关注并考虑就医。'
                    : '系统给出了初步建议，可点开查看详情。',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              if (item.recommendedDepartments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.recommendedDepartments
                      .take(3)
                      .map(
                        (department) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            department.departmentName,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.detail,
    required this.scrollController,
  });

  final AiConsultationDetail detail;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Center(
          child: Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          detail.inputText.isEmpty ? '本次咨询详情' : detail.inputText,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MetaChip(label: _riskLabel(detail.riskLevel)),
            const SizedBox(width: 8),
            if ((detail.createdAt ?? '').isNotEmpty)
              _MetaChip(label: _formatDate(detail.createdAt ?? '')),
            const SizedBox(width: 8),
            _MetaChip(label: detail.status),
          ],
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'AI 结论',
          child: Text(
            detail.finalAnswer.isEmpty ? '暂无分析结果。' : detail.finalAnswer,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              height: 1.6,
              fontSize: 16,
            ),
          ),
        ),
        if ((detail.followUpQuestion ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: '追问内容',
            child: Text(
              detail.followUpQuestion!,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                height: 1.6,
                fontSize: 16,
              ),
            ),
          ),
        ],
        if (detail.safetyNotice.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: '安全提示',
            child: Text(
              detail.safetyNotice,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                height: 1.6,
                fontSize: 16,
              ),
            ),
          ),
        ],
        if (detail.recommendedDepartments.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: '推荐科室',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detail.recommendedDepartments
                  .map(
                    (department) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        department.departmentName,
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (detail.matchedQaList.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: '相似问答',
            child: Column(
              children: detail.matchedQaList
                  .map(
                    (qa) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            qa.question,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            qa.answer,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

(Color, Color) _riskPalette(String level) {
  switch (level) {
    case 'high':
    case 'emergency':
      return (const Color(0xFFFFE4E6), const Color(0xFFBE123C));
    case 'medium':
      return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
    default:
      return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
  }
}

String _riskLabel(String level) {
  switch (level) {
    case 'high':
      return '高风险';
    case 'emergency':
      return '紧急';
    case 'medium':
      return '中风险';
    default:
      return '低风险';
  }
}

String _formatDate(String raw) {
  if (raw.isEmpty) return '时间未知';
  return raw.replaceFirst('T', ' ').replaceFirst('.000+08:00', '');
}
