import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/app_role.dart';
import '../data/community_avatar_resolver.dart';
import '../data/community_friend_repository.dart';
import '../data/community_demo_repository.dart';
import '../data/elder_avatar_repository.dart';
import '../data/friend_discover_catalog.dart';
import '../data/community_membership_repository.dart';
import '../data/community_scope.dart';
import '../data/community_voice_playback.dart';
import '../data/community_voice_recorder.dart';
import '../models/community_friend.dart';
import '../models/community_message.dart';
import 'community_direct_chat_page.dart';
import 'widgets/community_member_avatar.dart';

/// 群内语音会话：按住说话 · 保存本地语音 · 点击播放。
final class InterestCommunityVoiceChatPage extends StatefulWidget {
  const InterestCommunityVoiceChatPage({
    super.key,
    required this.community,
    required this.audience,
    this.membershipScopeKey,
    this.viewingElderScopeKey,
    this.viewingElderName,
    this.readOnly = false,
  });

  final InterestCommunityBrief community;
  final InterestCommunityAudience audience;
  /// 老人端当前账号 scope。
  final String? membershipScopeKey;
  /// 子女端预览时，绑定老人的 scope。
  final String? viewingElderScopeKey;
  final String? viewingElderName;
  final bool readOnly;

  @override
  State<InterestCommunityVoiceChatPage> createState() => _InterestCommunityVoiceChatPageState();
}

final class _ChatListEntry {
  const _ChatListEntry.date(this.dateLabel) : message = null;
  const _ChatListEntry.message(this.message) : dateLabel = null;

  final String? dateLabel;
  final InterestCommunityVoiceMessage? message;
}

class _InterestCommunityVoiceChatPageState extends State<InterestCommunityVoiceChatPage> {
  final ScrollController _scroll = ScrollController();
  final CommunityVoiceRecorder _recorder = CommunityVoiceRecorder();
  List<_ChatListEntry> _entries = [];
  Set<String> _friendScopeKeys = {};
  Map<String, String> _avatarPaths = {};
  bool _loading = true;
  bool _holdingMic = false;
  bool _sendingHold = false;
  String? _holdErrorText;

  bool get _elderUi => widget.audience == InterestCommunityAudience.elder;

  bool get _canSendVoice => _elderUi && !widget.readOnly;

  bool get _canClearHistory =>
      widget.readOnly && widget.viewingElderScopeKey != null && widget.viewingElderScopeKey!.isNotEmpty;

  String? get _selfScopeKey =>
      _elderUi ? widget.membershipScopeKey : widget.viewingElderScopeKey;

  @override
  void initState() {
    super.initState();
    CommunityVoicePlayback.playingMessageId.addListener(_onPlaybackChanged);
    unawaited(_bootstrap());
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    final scope = widget.membershipScopeKey;
    if (_elderUi && scope != null && scope.isNotEmpty) {
      final joined = await CommunityMembershipRepository.isJoined(scope, widget.community.id);
      if (!mounted) return;
      if (!joined) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先加入该群后再发言')),
          );
          Navigator.of(context).pop();
        });
        return;
      }
    }
    await _reload();
  }

  List<_ChatListEntry> _buildEntries(List<InterestCommunityVoiceMessage> messages) {
    final entries = <_ChatListEntry>[];
    DateTime? lastDay;
    for (final m in messages) {
      final dt = DateTime.fromMillisecondsSinceEpoch(m.createdAtMillis).toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      if (lastDay == null || day != lastDay) {
        entries.add(_ChatListEntry.date(_dateLabel(day)));
        lastDay = day;
      }
      entries.add(_ChatListEntry.message(m));
    }
    return entries;
  }

  static String _dateLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return '今天';
    if (day == yesterday) return '昨天';
    return '${day.month}月${day.day}日';
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await CommunityDemoRepository.seedPeerMessagesIfNeeded(widget.community.id);
    final list = await CommunityDemoRepository.loadMessages(widget.community.id);
    Set<String> friendKeys = {};
    final scopeKeys = <String>{};
    for (final m in list) {
      if (m.senderScopeKey.isNotEmpty) scopeKeys.add(m.senderScopeKey);
    }
    final selfScope = _selfScopeKey;
    if (selfScope != null && selfScope.isNotEmpty) scopeKeys.add(selfScope);
    final avatarPaths = await CommunityAvatarResolver.loadPathsForScopes(scopeKeys);
    if (_elderUi && !widget.readOnly) {
      final scope = widget.membershipScopeKey ?? CommunityScope.forCurrentElder();
      friendKeys = await CommunityFriendRepository.loadFriendScopeKeys(scope);
    }
    if (!mounted) return;
    setState(() {
      _entries = _buildEntries(list);
      _friendScopeKeys = friendKeys;
      _avatarPaths = avatarPaths;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }


  String? _avatarPathForMessage(InterestCommunityVoiceMessage m) {
    final key = m.senderScopeKey;
    if (key.isEmpty) return null;
    return _avatarPaths[key];
  }

  String? _emojiForMessage(InterestCommunityVoiceMessage m) {
    if (m.senderScopeKey.isEmpty || m.senderScopeKey == 'system') return null;
    return CommunityAvatarResolver.emojiForScope(m.senderScopeKey);
  }

  Future<void> _openDirectChat(InterestCommunityVoiceMessage m) async {
    if (m.senderScopeKey.isEmpty || m.senderScopeKey == 'system') return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityDirectChatPage(
          peerScopeKey: m.senderScopeKey,
          peerDisplayName: m.senderDisplay,
          peerEmoji: _emojiForMessage(m),
        ),
      ),
    );
  }

  Future<void> _pickSelfAvatar() async {
    final scope = widget.membershipScopeKey ?? CommunityScope.forCurrentElder();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final saved = await ElderAvatarRepository.saveFromFile(scopeKey: scope, sourcePath: picked.path);
    if (!mounted) return;
    setState(() => _avatarPaths = {..._avatarPaths, scope: saved});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
  }

  Future<void> _onAvatarTap(InterestCommunityVoiceMessage m) async {
    if (!_elderUi || widget.readOnly) return;
    if (_isMineMessage(m)) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册更换头像', style: TextStyle(fontSize: 18)),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickSelfAvatar());
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (m.senderScopeKey.isEmpty || m.senderScopeKey == 'system') return;

    final isFriend = _friendScopeKeys.contains(m.senderScopeKey);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  CommunityMemberAvatar(
                    displayName: m.senderDisplay,
                    imagePath: _avatarPathForMessage(m),
                    emoji: _emojiForMessage(m),
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.senderDisplay,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            if (!isFriend)
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('加好友', style: TextStyle(fontSize: 18)),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_addFriendFromMessage(m));
                },
              ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('发消息', style: TextStyle(fontSize: 18)),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_openDirectChat(m));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFriendFromMessage(InterestCommunityVoiceMessage m) async {
    final scope = widget.membershipScopeKey ?? CommunityScope.forCurrentElder();
    final candidate = FriendDiscoverCatalog.byScopeKey(m.senderScopeKey) ??
        ElderFriendCandidate(
          scopeKey: m.senderScopeKey,
          displayName: m.senderDisplay,
          phone: '',
          hint: '来自「${widget.community.name}」',
          emoji: '👤',
        );
    if (candidate.phone.isEmpty && FriendDiscoverCatalog.byScopeKey(m.senderScopeKey) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请前往「我的好友」通过手机号添加该朋友')),
      );
      return;
    }
    await CommunityFriendRepository.addFriend(ownerScopeKey: scope, candidate: candidate);
    if (!mounted) return;
    setState(() => _friendScopeKeys = {..._friendScopeKeys, candidate.scopeKey});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加好友「${candidate.displayName}」')),
    );
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!_scroll.hasClients || !mounted) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      });
    });
  }

  bool _isMineMessage(InterestCommunityVoiceMessage m) {
    final selfScope = _selfScopeKey;
    if (selfScope != null && selfScope.isNotEmpty && m.senderScopeKey.isNotEmpty) {
      return m.senderScopeKey == selfScope;
    }
    if (_elderUi) {
      final name = AuthSession.elderName ?? '我';
      return m.role == CommunitySenderRole.elder && m.senderDisplay == name;
    }
    final elderName = widget.viewingElderName;
    return elderName != null &&
        elderName.isNotEmpty &&
        m.role == CommunitySenderRole.elder &&
        m.senderDisplay == elderName;
  }

  String _senderLabel() {
    if (widget.audience == InterestCommunityAudience.elder) {
      return AuthSession.elderName ?? '我';
    }
    switch (AuthSession.role) {
      case AppRole.child:
        return '子女端';
      default:
        return '子女端家属';
    }
  }

  CommunitySenderRole get _senderRole =>
      widget.audience == InterestCommunityAudience.elder
          ? CommunitySenderRole.elder
          : CommunitySenderRole.child;

  Future<void> _confirmClearHistory() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录？'),
        content: const Text(
          '将删除本群全部聊天内容，老人端与子女端会同步清空。\n此操作不可恢复。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认清空')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await CommunityVoicePlayback.stop();
    await CommunityDemoRepository.clearMessages(widget.community.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本群聊天记录已清空')),
    );
    await _reload();
  }

  Future<void> _onHoldStart() async {
    if (_sendingHold) return;
    setState(() {
      _holdErrorText = null;
      _sendingHold = true;
      _holdingMic = true;
    });
    try {
      final blocker = await _recorder.permissionBlocker();
      if (!mounted) return;
      if (blocker != null) {
        setState(() {
          _holdErrorText = blocker;
          _holdingMic = false;
          _sendingHold = false;
        });
        return;
      }
      await _recorder.startRecording();
      if (!mounted) return;
      setState(() => _sendingHold = false);
    } catch (_) {
      if (!mounted) return;
      await _recorder.cancelRecording();
      setState(() {
        _holdErrorText = '录音启动失败，请稍后再试。';
        _holdingMic = false;
        _sendingHold = false;
      });
    }
  }

  Future<void> _onHoldEnd() async {
    if (!_holdingMic) return;
    setState(() {
      _holdingMic = false;
      _sendingHold = true;
    });
    try {
      final result = await _recorder.stopRecording();
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_elderUi ? '说话时间太短，请按住多说一会儿。' : '录音太短，未发送。')),
        );
        return;
      }
      final scope = widget.membershipScopeKey ?? CommunityScope.forCurrentElder();
      final msg = InterestCommunityVoiceMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_${widget.community.id}',
        communityId: widget.community.id,
        role: _senderRole,
        senderDisplay: _senderLabel(),
        senderScopeKey: scope,
        kind: CommunityMessageKind.voice,
        audioPath: result.path,
        durationMs: result.durationMs,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await CommunityDemoRepository.appendMessage(msg);
      await _reload();
    } finally {
      if (mounted) setState(() => _sendingHold = false);
    }
  }

  Future<void> _abortHoldSilently() async {
    await _recorder.cancelRecording();
    if (!mounted) return;
    setState(() {
      _holdingMic = false;
      _sendingHold = false;
    });
  }

  @override
  void dispose() {
    CommunityVoicePlayback.playingMessageId.removeListener(_onPlaybackChanged);
    unawaited(CommunityVoicePlayback.stop());
    unawaited(_recorder.dispose());
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = _elderUi ? 24.0 : 18.0;
    final bubbleMe = Theme.of(context).colorScheme.primary;
    final bubbleThem = const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: _elderUi ? const Color(0xFFF7F8FC) : null,
      appBar: AppBar(
        title: Text(widget.community.name, style: TextStyle(fontSize: titleSize - 4)),
        actions: [
          if (_canClearHistory)
            IconButton(
              onPressed: () => unawaited(_confirmClearHistory()),
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空聊天记录',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(_elderUi ? 22 : 16, 4, _elderUi ? 22 : 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.readOnly
                      ? '与老人端显示完全一致：父母发言在右侧，群友在左侧。可播放语音，右上角可清空记录。'
                      : '按住底部绿色按钮说话，松手后发送语音消息；点击气泡可播放。点头像可加好友或发私聊。',
                  style: TextStyle(
                    fontSize: _elderUi ? 16 : 13,
                    color: const Color(0xFF64748B),
                    height: 1.52,
                  ),
                ),
              ),
            ),
            if (_holdErrorText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _holdErrorText!,
                    style: TextStyle(fontSize: _elderUi ? 15 : 13, color: const Color(0xFFB45309)),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      itemCount: _entries.length + (_holdingMic ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (_holdingMic && i == _entries.length) {
                          return _RecordingBubble(elderHuge: _elderUi);
                        }
                        if (i >= _entries.length) return const SizedBox.shrink();
                        final entry = _entries[i];
                        if (entry.dateLabel != null) {
                          return _DateDivider(label: entry.dateLabel!, elderHuge: _elderUi);
                        }
                        final m = entry.message!;
                        final mine = _isMineMessage(m);
                        if (m.isVoice) {
                          return _VoiceBubble(
                            elderHuge: _elderUi,
                            mine: mine,
                            message: m,
                            bubbleMe: bubbleMe,
                            bubbleThem: bubbleThem,
                            playing: CommunityVoicePlayback.playingMessageId.value == m.id,
                            onTogglePlay: () => unawaited(
                              CommunityVoicePlayback.toggle(m.id, m.audioPath!),
                            ),
                            avatarPath: _avatarPathForMessage(m),
                            emoji: _emojiForMessage(m),
                            onAvatarTap: _elderUi && !widget.readOnly
                                ? () => unawaited(_onAvatarTap(m))
                                : null,
                          );
                        }
                        return _TextBubble(
                          elderHuge: _elderUi,
                          mine: mine,
                          name: m.senderDisplay,
                          text: m.textContent,
                          bubbleMe: bubbleMe,
                          bubbleThem: bubbleThem,
                          avatarPath: _avatarPathForMessage(m),
                          emoji: _emojiForMessage(m),
                          onAvatarTap: _elderUi && !widget.readOnly
                              ? () => unawaited(_onAvatarTap(m))
                              : null,
                        );
                      },
                    ),
            ),
            if (_canSendVoice)
              _MicBar(
                elderHuge: _elderUi,
                holding: _holdingMic,
                busy: _sendingHold && !_holdingMic,
                onHoldStart: () => unawaited(_onHoldStart()),
                onHoldEnd: () => unawaited(_onHoldEnd()),
                onHoldCancel: () => unawaited(_abortHoldSilently()),
              )
            else
              _ReadOnlyBar(
                elderHuge: _elderUi,
                onClearHistory: _canClearHistory ? () => unawaited(_confirmClearHistory()) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label, required this.elderHuge});

  final String label;
  final bool elderHuge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: elderHuge ? 14 : 12, vertical: elderHuge ? 6 : 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: elderHuge ? 14 : 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({
    required this.elderHuge,
    required this.mine,
    required this.message,
    required this.bubbleMe,
    required this.bubbleThem,
    required this.playing,
    required this.onTogglePlay,
    this.avatarPath,
    this.emoji,
    this.onAvatarTap,
  });

  final bool elderHuge;
  final bool mine;
  final InterestCommunityVoiceMessage message;
  final Color bubbleMe;
  final Color bubbleThem;
  final bool playing;
  final VoidCallback onTogglePlay;
  final String? avatarPath;
  final String? emoji;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : const Color(0xFF0F172A);
    final bg = mine ? bubbleMe : bubbleThem;
    final avatarSize = elderHuge ? 44.0 : 36.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            CommunityMemberAvatar(
              displayName: message.senderDisplay,
              imagePath: avatarPath,
              emoji: emoji,
              size: avatarSize,
              onTap: onAvatarTap,
            ),
            SizedBox(width: elderHuge ? 10 : 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                  child: Text(
                    message.senderDisplay,
                    style: TextStyle(
                      fontSize: elderHuge ? 14 : 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Material(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(elderHuge ? 18 : 16),
                    topRight: Radius.circular(elderHuge ? 18 : 16),
                    bottomLeft: Radius.circular(mine ? (elderHuge ? 18 : 16) : 4),
                    bottomRight: Radius.circular(mine ? 4 : (elderHuge ? 18 : 16)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(elderHuge ? 18 : 16),
                      topRight: Radius.circular(elderHuge ? 18 : 16),
                      bottomLeft: Radius.circular(mine ? (elderHuge ? 18 : 16) : 4),
                      bottomRight: Radius.circular(mine ? 4 : (elderHuge ? 18 : 16)),
                    ),
                    onTap: onTogglePlay,
                    child: Padding(
                      padding: EdgeInsets.all(elderHuge ? 16 : 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                            size: elderHuge ? 36 : 32,
                            color: fg,
                          ),
                          SizedBox(width: elderHuge ? 12 : 10),
                          Icon(Icons.graphic_eq_rounded, size: elderHuge ? 28 : 24, color: fg.withValues(alpha: 0.85)),
                          SizedBox(width: elderHuge ? 10 : 8),
                          Text(
                            message.displaySummary,
                            style: TextStyle(
                              fontSize: elderHuge ? 22 : 18,
                              fontWeight: FontWeight.w800,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mine) ...[
            SizedBox(width: elderHuge ? 10 : 8),
            CommunityMemberAvatar(
              displayName: message.senderDisplay,
              imagePath: avatarPath,
              size: avatarSize,
              onTap: onAvatarTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.elderHuge,
    required this.mine,
    required this.name,
    required this.text,
    required this.bubbleMe,
    required this.bubbleThem,
    this.avatarPath,
    this.emoji,
    this.onAvatarTap,
  });

  final bool elderHuge;
  final bool mine;
  final String name;
  final String text;
  final Color bubbleMe;
  final Color bubbleThem;
  final String? avatarPath;
  final String? emoji;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : const Color(0xFF0F172A);
    final bg = mine ? bubbleMe : bubbleThem;
    final avatarSize = elderHuge ? 44.0 : 36.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            CommunityMemberAvatar(
              displayName: name,
              imagePath: avatarPath,
              emoji: emoji,
              size: avatarSize,
              onTap: onAvatarTap,
            ),
            SizedBox(width: elderHuge ? 10 : 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: elderHuge ? 14 : 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(elderHuge ? 16 : 14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(elderHuge ? 18 : 16),
                      topRight: Radius.circular(elderHuge ? 18 : 16),
                      bottomLeft: Radius.circular(mine ? (elderHuge ? 18 : 16) : 4),
                      bottomRight: Radius.circular(mine ? 4 : (elderHuge ? 18 : 16)),
                    ),
                  ),
                  child: Text(
                    text,
                    textAlign: mine ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      fontSize: elderHuge ? 20 : 16,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mine) ...[
            SizedBox(width: elderHuge ? 10 : 8),
            CommunityMemberAvatar(
              displayName: name,
              imagePath: avatarPath,
              size: avatarSize,
              onTap: onAvatarTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingBubble extends StatelessWidget {
  const _RecordingBubble({required this.elderHuge});

  final bool elderHuge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: EdgeInsets.all(elderHuge ? 16 : 14),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_rounded, size: elderHuge ? 28 : 24, color: const Color(0xFF047857)),
              SizedBox(width: elderHuge ? 10 : 8),
              Text(
                '正在录音…',
                style: TextStyle(
                  fontSize: elderHuge ? 20 : 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF065F46),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyBar extends StatelessWidget {
  const _ReadOnlyBar({
    required this.elderHuge,
    this.onClearHistory,
  });

  final bool elderHuge;
  final VoidCallback? onClearHistory;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + MediaQuery.paddingOf(context).bottom * 0.2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.visibility_outlined, color: const Color(0xFF64748B), size: elderHuge ? 26 : 22),
                SizedBox(width: elderHuge ? 12 : 10),
                Expanded(
                  child: Text(
                    '子女端仅预览，不能在此群发言',
                    style: TextStyle(
                      fontSize: elderHuge ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            if (onClearHistory != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onClearHistory,
                icon: const Icon(Icons.delete_outline),
                label: const Text('清空本群聊天记录'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MicBar extends StatelessWidget {
  const _MicBar({
    required this.elderHuge,
    required this.holding,
    required this.busy,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
  });

  final bool elderHuge;
  final bool holding;
  final bool busy;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onHoldCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: holding ? 8 : 0,
      shadowColor: const Color(0xFF065F46).withValues(alpha: 0.3),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom * 0.2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              holding ? '松手即可发送语音…' : (busy ? '正在发送语音…' : '按住下方的「按住说话」'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: elderHuge ? 17 : 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => onHoldStart(),
                onPointerUp: (_) => onHoldEnd(),
                onPointerCancel: (_) => onHoldCancel(),
                child: AnimatedScale(
                  scale: holding ? 1.06 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: SizedBox(
                    width: elderHuge ? 220 : 200,
                    height: elderHuge ? 84 : 72,
                    child: Material(
                      color: holding ? const Color(0xFF047857) : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(999),
                      child: Center(
                        child: busy && !holding
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mic_rounded, size: elderHuge ? 34 : 30, color: Colors.white),
                                  SizedBox(width: elderHuge ? 12 : 8),
                                  Text(
                                    holding ? '录音中...' : '按住说话',
                                    style: TextStyle(
                                      fontSize: elderHuge ? 22 : 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '手指离开屏幕即结束录音并发送',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: elderHuge ? 13 : 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
