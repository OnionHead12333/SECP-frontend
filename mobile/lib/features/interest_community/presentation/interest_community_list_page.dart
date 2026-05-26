import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../data/community_membership_repository.dart';
import '../data/interest_community_api.dart';
import '../data/community_scope.dart';
import '../models/community_join_result.dart';
import '../models/community_message.dart';
import 'interest_community_voice_chat_page.dart';
import 'widgets/community_welcome_dialog.dart';
import 'widgets/interest_community_elder_section.dart';

/// 兴趣社群首页：老人端大号布局；子女端更紧凑列表。
final class InterestCommunityListPage extends StatefulWidget {
  const InterestCommunityListPage({super.key, required this.audience});

  final InterestCommunityAudience audience;

  @override
  State<InterestCommunityListPage> createState() => _InterestCommunityListPageState();
}

class _InterestCommunityListPageState extends State<InterestCommunityListPage> {
  List<InterestCommunityBrief> _communities = [];
  String? _error;
  bool _loading = true;

  bool get _elderUi => widget.audience == InterestCommunityAudience.elder;

  String get _scopeKey => CommunityScope.forCurrentElder();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await InterestCommunityApi.listCommunities();
      if (!mounted) return;
      setState(() {
        _communities = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Set<String> get _joinedIds =>
      _communities.where((c) => c.joined).map((c) => c.id).toSet();

  Future<void> _openCommunity(InterestCommunityBrief community) async {
    final joined = _joinedIds.contains(community.id);
    if (!_elderUi) {
      await _pushChat(community);
      return;
    }
    if (joined) {
      await _pushChat(community);
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('加入「${community.name}」？', style: TextStyle(fontSize: _elderUi ? 20 : 18)),
        content: Text(
          '加入后可以和群友按住说话交流。\n\n请勿在群里透露住址、银行卡等隐私信息。',
          style: TextStyle(fontSize: _elderUi ? 17 : 15, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('暂不加入')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认加入')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    CommunityJoinResult joinResult;
    try {
      joinResult = await CommunityMembershipRepository.join(
        scopeKey: _scopeKey,
        communityId: community.id,
        communityName: community.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    final welcome = joinResult.welcomeMessage;
    if (!mounted) return;
    if (welcome != null && welcome.isNotEmpty) {
      await CommunityWelcomeDialog.show(
        context,
        communityName: community.name,
        message: welcome,
      );
    }
    await _reload();
    if (!mounted) return;
    await _pushChat(community, joinWelcomeMessage: welcome);
  }

  Future<void> _leaveCommunity(InterestCommunityBrief community) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('退出「${community.name}」？', style: TextStyle(fontSize: _elderUi ? 20 : 18)),
        content: Text(
          '退出后仍可重新加入，历史群聊记录仍保留在服务器。',
          style: TextStyle(fontSize: _elderUi ? 17 : 15, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认退出')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await CommunityMembershipRepository.leave(_scopeKey, community.id);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已退出「${community.name}」')));
  }

  Future<void> _pushChat(
    InterestCommunityBrief community, {
    String? joinWelcomeMessage,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InterestCommunityVoiceChatPage(
          community: community,
          audience: widget.audience,
          membershipScopeKey: _scopeKey,
          joinWelcomeMessage: joinWelcomeMessage,
        ),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_elderUi) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title: const Text('兴趣社群'),
          backgroundColor: const Color(0xFFF7F8FC),
        ),
        body: const InterestCommunityElderSection(),
      );
    }

    final title = '父母兴趣社群';
    final subtitle = '查看老人加入的兴趣群及最近发言，仅预览不可代发。';

    return Scaffold(
      backgroundColor: null,
      appBar: AppBar(
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 8, 20, _elderUi ? 32 : 20),
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: _elderUi ? 17 : 14,
                      color: const Color(0xFF475569),
                      height: 1.55,
                    ),
                  ),
                  if (_elderUi && _joinedIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _JoinedSummaryBanner(count: _joinedIds.length, elderHuge: _elderUi),
                  ],
                  const SizedBox(height: 14),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: _elderUi ? 16 : 14, color: const Color(0xFFB91C1C)),
                      ),
                    ),
                  if (_communities.isEmpty && _error == null)
                    Text(
                      '暂时没有开放社群。',
                      style: TextStyle(fontSize: _elderUi ? 18 : 15),
                    )
                  else
                    ..._communities.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CommunityCard(
                          community: c,
                          elderHuge: _elderUi,
                          joined: c.joined,
                          onOpen: () => unawaited(_openCommunity(c)),
                          onLeave: _elderUi && c.joined
                              ? () => unawaited(_leaveCommunity(c))
                              : null,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    AuthSession.role == null
                        ? ''
                        : (_elderUi
                            ? '当前登录：老人端 ${AuthSession.elderPhone ?? '-'} · 已加入 ${_joinedIds.length} 个群'
                            : '当前登录：子女端 · 请从首页选择老人预览已加入的群聊'),
                    style: TextStyle(
                      fontSize: _elderUi ? 14 : 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _JoinedSummaryBanner extends StatelessWidget {
  const _JoinedSummaryBanner({required this.count, required this.elderHuge});

  final int count;
  final bool elderHuge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(elderHuge ? 16 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6EE7B7).withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: const Color(0xFF047857), size: elderHuge ? 28 : 24),
          SizedBox(width: elderHuge ? 12 : 10),
          Expanded(
            child: Text(
              '您已加入 $count 个兴趣群，点卡片即可进入群聊',
              style: TextStyle(
                fontSize: elderHuge ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF065F46),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.community,
    required this.elderHuge,
    required this.joined,
    required this.onOpen,
    this.onLeave,
  });

  final InterestCommunityBrief community;
  final bool elderHuge;
  final bool joined;
  final VoidCallback onOpen;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final actionHint = joined
        ? (elderHuge ? '已加入 · 点我进群聊' : '已加入 · 查看群内语音')
        : (elderHuge ? '点我加入并聊天' : '老人未加入');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Container(
          padding: EdgeInsets.all(elderHuge ? 20 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: joined ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0),
              width: joined ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.previewIcon,
                    style: TextStyle(fontSize: elderHuge ? 40 : 32, height: 1),
                  ),
                  SizedBox(width: elderHuge ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                community.name,
                                style: TextStyle(
                                  fontSize: elderHuge ? 22 : 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (joined)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '已加入',
                                  style: TextStyle(
                                    fontSize: elderHuge ? 13 : 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          community.shortDescription,
                          style: TextStyle(
                            fontSize: elderHuge ? 16 : 14,
                            color: const Color(0xFF475569),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${community.memberHint} · $actionHint',
                          style: TextStyle(
                            fontSize: elderHuge ? 15 : 13,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: elderHuge ? 32 : 28,
                    color: const Color(0xFFCBD5F5),
                  ),
                ],
              ),
              if (onLeave != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onLeave,
                    child: Text('退出此群', style: TextStyle(fontSize: elderHuge ? 15 : 13)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
