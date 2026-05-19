import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/community_friend_repository.dart';
import '../../data/community_scope.dart';
import '../../data/elder_avatar_repository.dart';
import '../../models/community_friend.dart';
import '../community_direct_chat_page.dart';
import '../elder_add_friend_page.dart';
import 'community_member_avatar.dart';

/// 老人端好友列表（可嵌入 Tab，无独立 AppBar）。
final class ElderFriendSection extends StatefulWidget {
  const ElderFriendSection({super.key});

  @override
  State<ElderFriendSection> createState() => _ElderFriendSectionState();
}

class _ElderFriendSectionState extends State<ElderFriendSection> {
  List<ElderFriend> _friends = [];
  Map<String, String> _avatarPaths = {};
  bool _loading = true;

  String get _ownerScope => CommunityScope.forCurrentElder();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await CommunityFriendRepository.loadFriends(_ownerScope);
    final avatarPaths = <String, String>{};
    for (final f in list) {
      final path = await ElderAvatarRepository.loadPath(f.scopeKey);
      if (path != null) avatarPaths[f.scopeKey] = path;
    }
    if (!mounted) return;
    setState(() {
      _friends = list;
      _avatarPaths = avatarPaths;
      _loading = false;
    });
  }

  Future<void> _openChat(ElderFriend friend) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityDirectChatPage(
          peerScopeKey: friend.scopeKey,
          peerDisplayName: friend.displayName,
          peerEmoji: friend.emoji,
        ),
      ),
    );
  }

  Future<void> _openAddFriend() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ElderAddFriendPage(ownerScopeKey: _ownerScope),
      ),
    );
    if (added == true) await _reload();
  }

  Future<void> _confirmRemove(ElderFriend friend) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友？', style: TextStyle(fontSize: 20)),
        content: Text(
          '确定将「${friend.displayName}」从好友列表移除？\n对方不会收到通知（当前为本地演示）。',
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await CommunityFriendRepository.removeFriend(
      ownerScopeKey: _ownerScope,
      friendScopeKey: friend.scopeKey,
    );
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除好友「${friend.displayName}」')));
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '添加同兴趣群里的朋友，方便发私聊。点头像或在群里也可加好友。',
                  style: TextStyle(fontSize: 16, color: Color(0xFF475569), height: 1.55),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(_openAddFriend()),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_friends.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.people_outline, size: 56, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text('还没有好友', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    '可通过手机号添加，或在兴趣群聊里点击群友头像添加',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B), height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => unawaited(_openAddFriend()),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('去添加好友', style: TextStyle(fontSize: 17)),
                  ),
                ],
              ),
            )
          else
            ..._friends.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => unawaited(_openChat(f)),
                    onLongPress: () => unawaited(_confirmRemove(f)),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CommunityMemberAvatar(
                            displayName: f.displayName,
                            imagePath: _avatarPaths[f.scopeKey],
                            emoji: f.emoji,
                            size: 52,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.displayName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(f.phone, style: const TextStyle(fontSize: 16, color: Color(0xFF64748B))),
                                if (f.hint.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(f.hint, style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF1565C0)),
                          IconButton(
                            onPressed: () => unawaited(_confirmRemove(f)),
                            icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8)),
                            tooltip: '删除好友',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
