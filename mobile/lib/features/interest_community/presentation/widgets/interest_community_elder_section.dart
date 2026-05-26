import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../data/community_membership_repository.dart';
import '../../data/interest_community_api.dart';
import '../../data/community_scope.dart';
import '../../models/community_join_result.dart';
import '../../models/community_message.dart';
import '../interest_community_voice_chat_page.dart';
import 'community_welcome_dialog.dart';

/// 老人端兴趣社群列表（可嵌入 Tab，无独立 AppBar）。
final class InterestCommunityElderSection extends StatefulWidget {
  const InterestCommunityElderSection({super.key});

  @override
  State<InterestCommunityElderSection> createState() => _InterestCommunityElderSectionState();
}

class _InterestCommunityElderSectionState extends State<InterestCommunityElderSection> {
  List<InterestCommunityBrief> _communities = [];
  bool _loading = true;
  String? _error;

  String get _scopeKey => CommunityScope.forCurrentElder();

  int get _joinedCount => _communities.where((c) => c.joined).length;

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

  Future<void> _openCommunity(InterestCommunityBrief community) async {
    final joined = community.joined;
    if (joined) {
      await _pushChat(community);
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('加入「${community.name}」？', style: const TextStyle(fontSize: 20)),
        content: const Text(
          '加入后可以和群友按住说话交流。\n\n请勿在群里透露住址、银行卡等隐私信息。',
          style: TextStyle(fontSize: 17, height: 1.5),
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
        title: Text('退出「${community.name}」？', style: const TextStyle(fontSize: 20)),
        content: const Text(
          '退出后仍可重新加入，历史群聊记录仍保留在服务器。',
          style: TextStyle(fontSize: 17, height: 1.5),
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
          audience: InterestCommunityAudience.elder,
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => unawaited(_reload()), child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            '选择感兴趣的群加入，按住说话即可交流。点头像可加好友或发私聊。',
            style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.55),
          ),
          if (_joinedCount > 0) ...[
            const SizedBox(height: 12),
            _JoinedSummaryBanner(count: _joinedCount),
          ],
          const SizedBox(height: 14),
          ..._communities.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CommunityCard(
                community: c,
                joined: c.joined,
                onOpen: () => unawaited(_openCommunity(c)),
                onLeave: c.joined ? () => unawaited(_leaveCommunity(c)) : null,
              ),
            ),
          ),
          Text(
            '当前登录：老人端 ${AuthSession.elderPhone ?? '-'} · 已加入 $_joinedCount 个群',
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _JoinedSummaryBanner extends StatelessWidget {
  const _JoinedSummaryBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6EE7B7).withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF047857), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '您已加入 $count 个兴趣群，点卡片即可进入群聊',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF065F46),
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
    required this.joined,
    required this.onOpen,
    this.onLeave,
  });

  final InterestCommunityBrief community;
  final bool joined;
  final VoidCallback onOpen;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final actionHint = joined ? '已加入 · 点我进群聊' : '点我加入并聊天';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(20),
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
                  Text(community.previewIcon, style: const TextStyle(fontSize: 40, height: 1)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                community.name,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (joined)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '已加入',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          community.shortDescription,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.45),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${community.memberHint} · $actionHint',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 32, color: Color(0xFFCBD5F5)),
                ],
              ),
              if (onLeave != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onLeave, child: const Text('退出此群', style: TextStyle(fontSize: 15))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
