import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/ai_medical_assistant_api.dart';
import '../models/ai_consultation_model.dart';
import 'ai_consultation_history_page.dart';

class AiMedicalAssistantPage extends StatefulWidget {
  const AiMedicalAssistantPage({super.key});

  @override
  State<AiMedicalAssistantPage> createState() => _AiMedicalAssistantPageState();
}

class _AiMedicalAssistantPageState extends State<AiMedicalAssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _followUpController = TextEditingController();

  bool _loading = false;
  AiConsultationResponse? _result;

  @override
  void dispose() {
    _controller.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _submit([String? quick]) async {
    final text = (quick ?? _controller.text).trim();
    final elderlyId = AuthSession.elderId;
    if (elderlyId == null) {
      _toast('当前没有获取到老人账号信息，请先重新登录。');
      return;
    }
    if (text.isEmpty) {
      _toast('请先输入不舒服的症状。');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await AiMedicalAssistantApi.createConsultation(
        elderlyId: elderlyId,
        inputText: text,
        inputType: 'text',
      );
      if (!mounted) return;
      setState(() {
        _result = res;
        _followUpController.clear();
      });
      if ((res.followUpQuestion ?? '').isNotEmpty) {
        _toast('请继续补充症状，帮助系统更准确判断。');
      }
    } catch (e) {
      _toast(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _followUp() async {
    final id = _result?.consultationId;
    final text = _followUpController.text.trim();
    if (id == null) return;
    if (text.isEmpty) {
      _toast('请先补充症状。');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await AiMedicalAssistantApi.sendMessage(
        id: id,
        messageContent: text,
        messageType: 'follow_up',
      );
      if (!mounted) return;
      setState(() => _result = res);
      _toast('咨询结果已更新。');
    } catch (e) {
      _toast(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _notifyFamily() async {
    final id = _result?.consultationId;
    if (id == null) return;

    setState(() => _loading = true);
    try {
      final res = await AiMedicalAssistantApi.notifyFamily(id);
      _toast(res.message.isNotEmpty ? res.message : '已同步给家属。');
    } catch (e) {
      _toast(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitFeedback(
    String type, {
    required bool helpful,
    required bool visited,
  }) async {
    final id = _result?.consultationId;
    if (id == null) return;

    try {
      await AiMedicalAssistantApi.submitFeedback(
        id,
        AiFeedbackRequestModel(
          feedbackType: type,
          feedbackText: '',
          isHelpful: helpful,
          hasVisitedDoctor: visited,
        ),
      );
      _toast('反馈已提交。');
    } catch (e) {
      _toast(_friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(title: const Text('AI 医疗助手')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFDCE7F7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '先说哪里不舒服',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  '尽量描述症状、持续时间和伴随情况，系统会先给你一个更容易看懂的结论。',
                  style: TextStyle(color: Color(0xFF475569), height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFFD6DFEB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFFD6DFEB)),
                    ),
                    hintText: '例如：咳嗽两天，晚上更明显，没有发热，但喉咙有点痒',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: Icon(_loading
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded),
                    label: Text(_loading ? '正在分析...' : '开始分析'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quick('头晕怎么办'),
              _quick('胸口闷怎么办'),
              _quick('睡不着怎么办'),
              _quick('腿疼挂什么科'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AiConsultationHistoryPage(
                      elderlyId: AuthSession.elderId ?? 0),
                ),
              ),
              icon: const Icon(Icons.history_rounded),
              label: const Text('查看历史记录'),
            ),
          ),
          if ((result?.followUpQuestion ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _FollowUpCard(
              question: result!.followUpQuestion!,
              controller: _followUpController,
              onSubmit: _loading ? null : _followUp,
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(
              result: result,
              onNotifyFamily: _notifyFamily,
              onFeedback: _submitFeedback,
            ),
          ],
        ],
      ),
    );
  }

  Widget _quick(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: _loading ? null : () => _submit(text),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFD8E1EE)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('SocketException') || msg.contains('HandshakeException')) {
      return '网络连接失败，请确认后端服务已启动。';
    }
    if (msg.contains('空响应')) {
      return '服务返回为空，请稍后重试。';
    }
    return msg;
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({
    required this.question,
    required this.controller,
    required this.onSubmit,
  });

  final String question;
  final TextEditingController controller;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFC2410C)),
              SizedBox(width: 8),
              Text(
                '还需要补充一点信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9A3412),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(question, style: const TextStyle(height: 1.55)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFF1C899)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFF1C899)),
              ),
              hintText: '例如：已经两天了，没有发热，但晚上咳得更明显',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('继续追问'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onNotifyFamily,
    required this.onFeedback,
  });

  final AiConsultationResponse result;
  final Future<void> Function() onNotifyFamily;
  final Future<void> Function(
    String type, {
    required bool helpful,
    required bool visited,
  }) onFeedback;

  @override
  Widget build(BuildContext context) {
    final presentation = _AnswerPresentation.fromResult(result);
    final highRisk =
        result.riskLevel == 'high' || result.riskLevel == 'emergency';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (highRisk) _UrgentBanner(needFamilyNotify: result.needFamilyNotify),
        if (highRisk) const SizedBox(height: 12),
        _SummaryHero(
          riskLevel: result.riskLevel,
          riskLabel: _riskLabel(result.riskLevel),
          summary: presentation.summary,
          primaryActions: presentation.primaryActions,
        ),
        if (presentation.blocks.isNotEmpty) ...[
          const SizedBox(height: 14),
          _AnswerBreakdown(blocks: presentation.blocks),
        ],
        if (result.recommendedDepartments.isNotEmpty) ...[
          const SizedBox(height: 18),
          _DepartmentSection(items: result.recommendedDepartments),
        ],
        if (result.matchedQaList.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SimilarQaSection(items: result.matchedQaList),
        ],
        const SizedBox(height: 18),
        _ActionPanel(
          needFamilyNotify: result.needFamilyNotify,
          onNotifyFamily: onNotifyFamily,
          onFeedback: onFeedback,
        ),
      ],
    );
  }

  static String _riskLabel(String level) => switch (level) {
        'high' => '高风险',
        'emergency' => '紧急',
        'medium' => '中等风险',
        _ => '低风险',
      };
}

enum _AnswerBlockTone { summary, action, warning, question, safety, neutral }

class _AnswerBlock {
  const _AnswerBlock({
    required this.title,
    required this.body,
    required this.bullets,
    required this.tone,
  });

  final String title;
  final String body;
  final List<String> bullets;
  final _AnswerBlockTone tone;
}

class _AnswerPresentation {
  const _AnswerPresentation({
    required this.summary,
    required this.primaryActions,
    required this.blocks,
  });

  final String summary;
  final List<String> primaryActions;
  final List<_AnswerBlock> blocks;

  static _AnswerPresentation fromResult(AiConsultationResponse result) {
    final blocks = _parseBlocks(result.finalAnswer);
    final mutableBlocks = List<_AnswerBlock>.from(blocks);

    final hasSafetyBlock =
        mutableBlocks.any((block) => block.tone == _AnswerBlockTone.safety);
    final cleanSafety = result.safetyNotice.trim();
    if (!hasSafetyBlock && cleanSafety.isNotEmpty) {
      mutableBlocks.add(
        _AnswerBlock(
          title: '安全提示',
          body: cleanSafety,
          bullets: const [],
          tone: _AnswerBlockTone.safety,
        ),
      );
    }

    final summaryBlock = mutableBlocks.firstWhere(
      (block) => block.tone == _AnswerBlockTone.summary,
      orElse: () => mutableBlocks.isNotEmpty
          ? mutableBlocks.first
          : _AnswerBlock(
              title: '本次判断',
              body: result.finalAnswer.trim(),
              bullets: const [],
              tone: _AnswerBlockTone.neutral,
            ),
    );

    var summary = summaryBlock.body.isNotEmpty
        ? summaryBlock.body
        : (summaryBlock.bullets.isNotEmpty
            ? summaryBlock.bullets.first
            : result.finalAnswer.trim());
    if (summary.isEmpty) {
      summary = cleanSafety.isNotEmpty ? cleanSafety : '已生成本次健康建议，请结合下方内容查看。';
    }

    final actionBlock = mutableBlocks.firstWhere(
      (block) =>
          block.tone == _AnswerBlockTone.action && block.bullets.isNotEmpty,
      orElse: () => const _AnswerBlock(
          title: '', body: '', bullets: [], tone: _AnswerBlockTone.neutral),
    );

    final primaryActions = actionBlock.bullets.isNotEmpty
        ? actionBlock.bullets.take(3).toList()
        : _fallbackActions(summary);

    return _AnswerPresentation(
      summary: summary,
      primaryActions: primaryActions,
      blocks: mutableBlocks,
    );
  }

  static List<_AnswerBlock> _parseBlocks(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const [];

    final regExp = RegExp(r'【([^】]+)】');
    final matches = regExp.allMatches(text).toList();
    if (matches.isEmpty) {
      return [
        _AnswerBlock(
          title: '本次判断',
          body: text,
          bullets: _parseBullets(text),
          tone: _AnswerBlockTone.summary,
        ),
      ];
    }

    final blocks = <_AnswerBlock>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final nextStart =
          i + 1 < matches.length ? matches[i + 1].start : text.length;
      final title = (match.group(1) ?? '').trim();
      final content = text.substring(match.end, nextStart).trim();
      if (title.isEmpty || content.isEmpty) continue;
      blocks.add(
        _AnswerBlock(
          title: title,
          body: _stripBulletLines(content),
          bullets: _parseBullets(content),
          tone: _toneForTitle(title),
        ),
      );
    }
    return blocks;
  }

  static _AnswerBlockTone _toneForTitle(String title) {
    if (title.contains('建议')) return _AnswerBlockTone.action;
    if (title.contains('尽快就医') ||
        title.contains('立即就医') ||
        title.contains('危险')) {
      return _AnswerBlockTone.warning;
    }
    if (title.contains('了解') || title.contains('追问') || title.contains('补充')) {
      return _AnswerBlockTone.question;
    }
    if (title.contains('安全')) return _AnswerBlockTone.safety;
    if (title.contains('说明') || title.contains('判断') || title.contains('结论')) {
      return _AnswerBlockTone.summary;
    }
    return _AnswerBlockTone.neutral;
  }

  static List<String> _parseBullets(String text) {
    final bulletRegExp = RegExp(r'^\s*(?:\d+[.、]|[-•])\s*');
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => bulletRegExp.hasMatch(line))
        .map((line) => line.replaceFirst(bulletRegExp, '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static String _stripBulletLines(String text) {
    final bulletRegExp = RegExp(r'^\s*(?:\d+[.、]|[-•])\s*');
    final remaining = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !bulletRegExp.hasMatch(line))
        .join('\n');
    return remaining.trim();
  }

  static List<String> _fallbackActions(String text) {
    return text
        .replaceAll('\n', ' ')
        .split(RegExp(r'[。；]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList();
  }
}

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.needFamilyNotify});

  final bool needFamilyNotify;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.priority_high_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '需要优先处理',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 4),
                Text(
                  needFamilyNotify
                      ? '症状风险较高，建议尽快就医，并同步告知家属。'
                      : '症状风险较高，建议尽快线下就医或联系专业医生。',
                  style: const TextStyle(color: Color(0xFF9F1239), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.riskLevel,
    required this.riskLabel,
    required this.summary,
    required this.primaryActions,
  });

  final String riskLevel;
  final String riskLabel;
  final String summary;
  final List<String> primaryActions;

  @override
  Widget build(BuildContext context) {
    final palette = _RiskPalette.forLevel(riskLevel);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.background, palette.backgroundSoft],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.badge,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                      color: palette.accent, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              const Text(
                '先看这里',
                style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '这次咨询的核心判断',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: Color(0xFF0F172A),
            ),
          ),
          if (primaryActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '建议先做',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            ...primaryActions.asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                        bottom: entry.key == primaryActions.length - 1 ? 0 : 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: palette.badge,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(
                              color: palette.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _RiskPalette {
  const _RiskPalette({
    required this.background,
    required this.backgroundSoft,
    required this.border,
    required this.badge,
    required this.accent,
  });

  final Color background;
  final Color backgroundSoft;
  final Color border;
  final Color badge;
  final Color accent;

  static _RiskPalette forLevel(String level) {
    switch (level) {
      case 'high':
      case 'emergency':
        return const _RiskPalette(
          background: Color(0xFFFFF1F2),
          backgroundSoft: Color(0xFFFFFBEB),
          border: Color(0xFFFDA4AF),
          badge: Color(0xFFFFE4E6),
          accent: Color(0xFFBE123C),
        );
      case 'medium':
        return const _RiskPalette(
          background: Color(0xFFFFFBEB),
          backgroundSoft: Color(0xFFFFF7ED),
          border: Color(0xFFFCD34D),
          badge: Color(0xFFFEF3C7),
          accent: Color(0xFFB45309),
        );
      default:
        return const _RiskPalette(
          background: Color(0xFFF0FDF4),
          backgroundSoft: Color(0xFFEFF6FF),
          border: Color(0xFFBFDBFE),
          badge: Color(0xFFDBEAFE),
          accent: Color(0xFF1D4ED8),
        );
    }
  }
}

class _AnswerBreakdown extends StatelessWidget {
  const _AnswerBreakdown({required this.blocks});

  final List<_AnswerBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('详细说明',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            '把本次判断拆开看，会更容易知道先做什么、何时就医、还缺哪些信息。',
            style: TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 16),
          ...blocks.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                      bottom: entry.key == blocks.length - 1 ? 0 : 12),
                  child: _AnswerBlockView(block: entry.value),
                ),
              ),
        ],
      ),
    );
  }
}

class _AnswerBlockView extends StatelessWidget {
  const _AnswerBlockView({required this.block});

  final _AnswerBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = _AnswerBlockTheme.forTone(block.tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(theme.icon, color: theme.iconColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    block.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.titleColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (block.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              block.body,
              style: const TextStyle(
                  fontSize: 16, height: 1.65, color: Color(0xFF1E293B)),
            ),
          ],
          if (block.bullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...block.bullets.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: theme.iconBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Icon(theme.bulletIcon,
                          color: theme.iconColor, size: 13),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerBlockTheme {
  const _AnswerBlockTheme({
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
    required this.titleColor,
    required this.icon,
    required this.bulletIcon,
  });

  final Color background;
  final Color border;
  final Color iconBackground;
  final Color iconColor;
  final Color titleColor;
  final IconData icon;
  final IconData bulletIcon;

  static _AnswerBlockTheme forTone(_AnswerBlockTone tone) {
    switch (tone) {
      case _AnswerBlockTone.action:
        return const _AnswerBlockTheme(
          background: Color(0xFFF0FDF4),
          border: Color(0xFFBBF7D0),
          iconBackground: Color(0xFFDCFCE7),
          iconColor: Color(0xFF15803D),
          titleColor: Color(0xFF166534),
          icon: Icons.check_circle_outline_rounded,
          bulletIcon: Icons.check_rounded,
        );
      case _AnswerBlockTone.warning:
        return const _AnswerBlockTheme(
          background: Color(0xFFFFF7ED),
          border: Color(0xFFFED7AA),
          iconBackground: Color(0xFFFFEDD5),
          iconColor: Color(0xFFC2410C),
          titleColor: Color(0xFF9A3412),
          icon: Icons.warning_amber_rounded,
          bulletIcon: Icons.priority_high_rounded,
        );
      case _AnswerBlockTone.question:
        return const _AnswerBlockTheme(
          background: Color(0xFFEFF6FF),
          border: Color(0xFFBFDBFE),
          iconBackground: Color(0xFFDBEAFE),
          iconColor: Color(0xFF2563EB),
          titleColor: Color(0xFF1D4ED8),
          icon: Icons.help_outline_rounded,
          bulletIcon: Icons.arrow_forward_rounded,
        );
      case _AnswerBlockTone.safety:
        return const _AnswerBlockTheme(
          background: Color(0xFFF8FAFC),
          border: Color(0xFFE2E8F0),
          iconBackground: Color(0xFFE2E8F0),
          iconColor: Color(0xFF475569),
          titleColor: Color(0xFF334155),
          icon: Icons.shield_outlined,
          bulletIcon: Icons.circle,
        );
      case _AnswerBlockTone.summary:
      case _AnswerBlockTone.neutral:
        return const _AnswerBlockTheme(
          background: Color(0xFFFAFAFF),
          border: Color(0xFFE5E7EB),
          iconBackground: Color(0xFFF1F5F9),
          iconColor: Color(0xFF475569),
          titleColor: Color(0xFF0F172A),
          icon: Icons.notes_rounded,
          bulletIcon: Icons.circle,
        );
    }
  }
}

class _DepartmentSection extends StatelessWidget {
  const _DepartmentSection({required this.items});

  final List<RecommendedDepartment> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('推荐科室',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          '如果症状持续、反复或加重，可以优先从这些科室开始就诊。',
          style: TextStyle(color: Color(0xFF64748B), height: 1.45),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.local_hospital_outlined,
                      color: Color(0xFF1D4ED8)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.departmentName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.reason,
                        style: const TextStyle(
                            color: Color(0xFF475569), height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '后续接入挂号',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SimilarQaSection extends StatelessWidget {
  const _SimilarQaSection({required this.items});

  final List<MatchedQa> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('相似问答',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...items.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '常见相似问题',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e.question,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, height: 1.35),
                ),
                const SizedBox(height: 10),
                Text(
                  e.answer,
                  style:
                      const TextStyle(color: Color(0xFF334155), height: 1.55),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.needFamilyNotify,
    required this.onNotifyFamily,
    required this.onFeedback,
  });

  final bool needFamilyNotify;
  final Future<void> Function() onNotifyFamily;
  final Future<void> Function(
    String type, {
    required bool helpful,
    required bool visited,
  }) onFeedback;

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
          const Text('接下来可以做什么',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: needFamilyNotify
                ? FilledButton.icon(
                    onPressed: onNotifyFamily,
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('建议同步给家属'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: onNotifyFamily,
                    icon: const Icon(Icons.family_restroom_outlined),
                    label: const Text('同步给家属'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          const Text('这次回答对你有帮助吗',
              style: TextStyle(
                  color: Color(0xFF475569), fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () =>
                    onFeedback('helpful', helpful: true, visited: false),
                child: const Text('有帮助'),
              ),
              OutlinedButton(
                onPressed: () =>
                    onFeedback('not_helpful', helpful: false, visited: false),
                child: const Text('没帮助'),
              ),
              OutlinedButton(
                onPressed: () =>
                    onFeedback('visited_doctor', helpful: true, visited: true),
                child: const Text('我已就医'),
              ),
              OutlinedButton(
                onPressed: () => onFeedback('need_manual_help',
                    helpful: false, visited: false),
                child: const Text('需要人工帮助'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
