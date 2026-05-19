import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../data/community_catalog.dart';
import '../../data/community_membership_repository.dart';
import '../../data/community_scope.dart';
import '../../models/community_message.dart';
import '../interest_community_voice_chat_page.dart';

/// 老人端兴趣社群列表（可嵌入 Tab，无独立 AppBar）。
final class InterestCommunityElderSection extends StatefulWidget {
  const InterestCommunityElderSection({super.key});

  @override
  State<InterestCommunityElderSection> createState() => _InterestCommunityElderSectionState();
}

class _InterestCommunityElderSectionState extends State<InterestCommunityElderSection> {
  Set<String> _joinedIds = {};
  bool _loading = true;

  String get _scopeKey => CommunityScope.forCurrentElder();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final joined = await CommunityMembershipRepository.loadJoinedIds(_scopeKey);
    if (!mounted) return;
    setState(() {
      _joinedIds = joined;
      _loading = false;
    });
  }

  Future<void> _openCommunity(InterestCommunityBrief community) async {
    final joined = _joinedIds.contains(community.id);
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
    await CommunityMembershipRepository.join(
      scopeKey: _scopeKey,
      communityId: community.id,
      communityName: community.name,
    );
    await _reload();
    if (!mounted) return;
    await _pushChat(community);
  }

  Future<void> _leaveCommunity(InterestCommunityBrief community) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('退出「${community.name}」？', style: const TextStyle(fontSize: 20)),
        content: const Text(
          '退出后仍可重新加入，本机演示消息会保留在群里供其他成员查看。',
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

  Future<void> _pushChat(InterestCommunityBrief community) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InterestCommunityVoiceChatPage(
          community: community,
          audience: InterestCommunityAudience.elder,
          membershipScopeKey: _scopeKey,
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
          if (_joinedIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _JoinedSummaryBanner(count: _joinedIds.length),
          ],
          const SizedBox(height: 14),
          ...CommunityCatalog.all.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CommunityCard(
                community: c,
                joined: _joinedIds.contains(c.id),
                onOpen: () => unawaited(_openCommunity(c)),
                onLeave: _joinedIds.contains(c.id) ? () => unawaited(_leaveCommunity(c)) : null,
              ),
            ),
          ),
          Text(
            '当前登录：老人端 ${AuthSession.elderPhone ?? '-'} · 已加入 ${_joinedIds.length} 个群',
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
