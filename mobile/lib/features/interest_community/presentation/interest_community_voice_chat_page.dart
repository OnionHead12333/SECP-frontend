import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/app_role.dart';
import '../data/community_avatar_resolver.dart';
import '../data/community_friend_repository.dart';
import '../data/community_group_chat_service.dart';
import '../data/community_media_cache.dart';
import '../data/elder_avatar_repository.dart';
import '../data/friend_discover_catalog.dart';
import '../data/community_membership_repository.dart';
import '../data/community_scope.dart';
import '../data/community_voice_duration.dart';
import '../data/community_voice_playback.dart';
import '../data/community_voice_recorder.dart';
import '../models/community_friend.dart';
import '../models/community_message.dart';
import 'community_direct_chat_page.dart';
import 'widgets/community_chat_image.dart';
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
    this.elderProfileId,
    this.readOnly = false,
    this.joinWelcomeMessage,
  });

  final InterestCommunityBrief community;
  final InterestCommunityAudience audience;
  /// 老人端当前账号 scope。
  final String? membershipScopeKey;
  /// 子女端预览时，绑定老人的 scope。
  final String? viewingElderScopeKey;
  final String? viewingElderName;
  /// 子女端预览时绑定老人的 `elderProfileId`。
  final int? elderProfileId;
  final bool readOnly;
  /// 本次入群接口返回的欢迎语（与历史消息列表分离展示）。
  final String? joinWelcomeMessage;

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
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  List<_ChatListEntry> _entries = [];
  List<InterestCommunityVoiceMessage> _rawMessages = [];
  Set<String> _friendScopeKeys = {};
  Map<String, String> _avatarPaths = {};
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _nextBefore;
  bool _stickToBottom = true;
  bool _voiceInputMode = true;
  bool _holdingMic = false;
  bool _sendingHold = false;
  bool _sendingImage = false;
  bool _sendingText = false;
  String? _holdErrorText;
  bool _showJoinWelcomeBanner = false;

  bool get _elderUi => widget.audience == InterestCommunityAudience.elder;

  bool get _canSend => _elderUi && !widget.readOnly;

  bool get _canClearHistory => !_initialLoading;

  bool get _canLeaveGroup {
    if (!_canSend) return false;
    final scope = widget.membershipScopeKey;
    return scope != null && scope.isNotEmpty;
  }

  String? get _selfScopeKey =>
      _elderUi ? widget.membershipScopeKey : widget.viewingElderScopeKey;

  @override
  void initState() {
    super.initState();
    final welcome = widget.joinWelcomeMessage?.trim();
    _showJoinWelcomeBanner = welcome != null && welcome.isNotEmpty;
    CommunityVoicePlayback.playingMessageId.addListener(_onPlaybackChanged);
    _scroll.addListener(_onScroll);
    unawaited(_bootstrap());
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    // reverse ListView：pixels≈0 为底部（最新消息）
    _stickToBottom = pos.pixels <= 96;
    if (pos.pixels >= pos.maxScrollExtent - 140 && !_loadingMore && _hasMore) {
      unawaited(_loadOlder());
    }
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    if (_elderUi && !widget.readOnly) {
      final joined = widget.community.joined ||
          await CommunityMembershipRepository.isJoined(
            widget.membershipScopeKey ?? CommunityScope.forCurrentElder(),
            widget.community.id,
          );
      if (!mounted) return;
      if (!joined) {
        setState(() => _initialLoading = false);
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
    await _loadInitial();
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

  static String _formatMessageTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (day == today) return hm;
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == yesterday) return '昨天 $hm';
    return '${dt.month}/${dt.day} $hm';
  }

  void _applyMessages(
    List<InterestCommunityVoiceMessage> incoming, {
    required bool prepend,
    required bool hasMore,
    String? nextBefore,
  }) {
    final filtered = incoming.where((m) => m.senderScopeKey != 'system').toList();
    if (prepend) {
      final existing = _rawMessages.map((e) => e.id).toSet();
      final older = filtered.where((m) => !existing.contains(m.id)).toList();
      _rawMessages = [...older, ..._rawMessages];
    } else {
      _rawMessages = filtered;
    }
    _rawMessages.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    _hasMore = hasMore;
    _nextBefore = nextBefore;
    _entries = _buildEntries(_rawMessages);
  }

  Future<void> _refreshAvatarsAndFriends() async {
    final list = _rawMessages;
    final scopeKeys = <String>{};
    final remoteAvatarUrls = <String, String>{};
    for (final m in list) {
      if (m.senderScopeKey.isNotEmpty) scopeKeys.add(m.senderScopeKey);
      final url = m.senderAvatarUrl;
      if (m.senderScopeKey.isNotEmpty && url != null && url.isNotEmpty) {
        remoteAvatarUrls[m.senderScopeKey] = url;
      }
    }
    final selfScope = _selfScopeKey;
    if (selfScope != null && selfScope.isNotEmpty) scopeKeys.add(selfScope);
    final avatarPaths = await CommunityAvatarResolver.loadPathsForScopes(
      scopeKeys,
      remoteAvatarUrlsByScope: remoteAvatarUrls,
    );
    Set<String> friendKeys = _friendScopeKeys;
    if (_elderUi && !widget.readOnly) {
      final scope = widget.membershipScopeKey ?? CommunityScope.forCurrentElder();
      friendKeys = await CommunityFriendRepository.loadFriendScopeKeys(scope);
    }
    if (!mounted) return;
    setState(() {
      _avatarPaths = avatarPaths;
      _friendScopeKeys = friendKeys;
    });
  }

  Future<void> _loadInitial() async {
    setState(() => _initialLoading = true);
    try {
      // 自动翻页拉全量（后端首屏为最近一页 ASC），进入后锚定最新消息
      final list = await CommunityGroupChatService.loadMessages(
        communityId: widget.community.id,
        audience: widget.audience,
        elderProfileId: widget.elderProfileId,
      );
      if (!mounted) return;
      _applyMessages(list, prepend: false, hasMore: false, nextBefore: null);
      final ids = _rawMessages.map((m) => m.id);
      CommunityMediaCache.evictNotIn(ids);
      CommunityVoiceDuration.evictNotIn(ids);
      setState(() => _initialLoading = false);
      _stickToBottom = true;
      unawaited(_refreshAvatarsAndFriends());
      _anchorToLatest(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _loadOlder({bool silent = false}) async {
    if (_loadingMore || !_hasMore) return;
    final before = _nextBefore;
    if (before == null || before.isEmpty) return;
    if (!silent) setState(() => _loadingMore = true);
    final oldPixels = _scroll.hasClients ? _scroll.position.pixels : 0.0;
    final oldMax = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    try {
      final page = await CommunityGroupChatService.loadMessagesPage(
        communityId: widget.community.id,
        audience: widget.audience,
        elderProfileId: widget.elderProfileId,
        before: before,
      );
      if (!mounted) return;
      _applyMessages(
        page.items,
        prepend: true,
        hasMore: page.hasMore,
        nextBefore: page.nextBefore,
      );
      setState(() {});
      if (_scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients || !mounted) return;
          if (oldPixels <= 96) {
            _scroll.jumpTo(0);
          } else {
            final delta = _scroll.position.maxScrollExtent - oldMax;
            _scroll.jumpTo((oldPixels + delta).clamp(0.0, _scroll.position.maxScrollExtent));
          }
        });
      }
      unawaited(_refreshAvatarsAndFriends());
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _loadingMore = false);
    }
  }

  Future<void> _reload({bool scrollToBottom = false}) async {
    final shouldScroll = scrollToBottom || _stickToBottom;
    try {
      final list = await CommunityGroupChatService.loadMessages(
        communityId: widget.community.id,
        audience: widget.audience,
        elderProfileId: widget.elderProfileId,
      );
      if (!mounted) return;
      _applyMessages(list, prepend: false, hasMore: false, nextBefore: null);
      final ids = _rawMessages.map((m) => m.id);
      CommunityMediaCache.evictNotIn(ids);
      CommunityVoiceDuration.evictNotIn(ids);
      setState(() {});
      unawaited(_refreshAvatarsAndFriends());
      if (shouldScroll) _anchorToLatest(animated: scrollToBottom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }


  String? _avatarPathForMessage(InterestCommunityVoiceMessage m) {
    final key = m.senderScopeKey;
    if (key.isEmpty) return null;
    return _avatarPaths[key];
  }

  String? _emojiForMessage(InterestCommunityVoiceMessage m) {
    if (m.senderEmoji != null && m.senderEmoji!.isNotEmpty) return m.senderEmoji;
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

  Future<void> _toggleVoicePlay(InterestCommunityVoiceMessage message) async {
    final ok = await CommunityVoicePlayback.toggleMessage(message);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('媒体不可用')),
      );
    }
  }

  Future<void> _pickSelfAvatar() async {
    final scope = widget.membershipScopeKey ?? CommunityScope.forCurrentElder();
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    try {
      final saved = await ElderAvatarRepository.saveFromFile(scopeKey: scope, sourcePath: picked.path);
      if (!mounted) return;
      setState(() => _avatarPaths = {..._avatarPaths, scope: saved});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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
    final catalog = FriendDiscoverCatalog.byScopeKey(m.senderScopeKey);
    final candidate = catalog ??
        ElderFriendCandidate(
          scopeKey: m.senderScopeKey,
          displayName: m.senderDisplay,
          phone: '',
          hint: '来自「${widget.community.name}」',
          emoji: _emojiForMessage(m) ?? '👤',
        );
    await CommunityFriendRepository.addFriend(ownerScopeKey: scope, candidate: candidate);
    if (!mounted) return;
    setState(() => _friendScopeKeys = {..._friendScopeKeys, candidate.scopeKey});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加好友「${candidate.displayName}」')),
    );
  }

  /// reverse ListView 下锚定到最新消息（列表底部，pixels → 0）。
  void _anchorToLatest({bool animated = true}) {
    if (!_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _anchorToLatest(animated: animated));
      return;
    }
    void jump() {
      if (!_scroll.hasClients || !mounted) return;
      const target = 0.0;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  bool _isMineMessage(InterestCommunityVoiceMessage m) {
    if (m.mine != null) return m.mine!;
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

  Future<void> _showChatMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(widget.community.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                widget.readOnly
                    ? '子女端预览 · ${widget.viewingElderName ?? "绑定老人"}'
                    : '成员 ${widget.community.memberHint}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (_canClearHistory)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFB45309)),
                title: const Text('清空聊天记录'),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
            if (_canLeaveGroup)
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                title: const Text('退出群聊'),
                onTap: () => Navigator.pop(ctx, 'leave'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'clear':
        await _confirmClearHistory();
      case 'leave':
        await _confirmLeaveGroup();
    }
  }

  Future<void> _confirmLeaveGroup() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('退出「${widget.community.name}」？'),
        content: const Text(
          '退出后仍可重新加入，历史群聊记录仍保留在服务器。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final scope = widget.membershipScopeKey ?? CommunityScope.forCurrentElder();
    await CommunityMembershipRepository.leave(scope, widget.community.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已退出「${widget.community.name}」')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_sendingImage || _sendingHold) return;
    final xfile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (xfile == null || !mounted) return;
    setState(() => _sendingImage = true);
    try {
      await CommunityGroupChatService.sendImage(
        communityId: widget.community.id,
        file: File(xfile.path),
      );
      await _reload(scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片发送失败：${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachAction(
                icon: Icons.photo_camera_outlined,
                label: '拍照',
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickAndSendImage(ImageSource.camera));
                },
              ),
              _AttachAction(
                icon: Icons.photo_library_outlined,
                label: '相册',
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickAndSendImage(ImageSource.gallery));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _previewImage(InterestCommunityVoiceMessage message) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CommunityChatImagePreview(message: message),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录？'),
        content: const Text(
          '仅对你隐藏此前的消息，群友与其他家人仍能看到完整记录。\n清空后新消息会正常显示。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认清空')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await CommunityVoicePlayback.stop();
    await CommunityGroupChatService.clearHistory(
      communityId: widget.community.id,
      audience: widget.audience,
      elderProfileId: widget.elderProfileId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清空，仅对你不可见此前的消息')),
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
      final sent = await CommunityGroupChatService.sendVoice(
        communityId: widget.community.id,
        file: File(result.path),
        durationMs: result.durationMs,
      );
      CommunityVoiceDuration.remember(sent.id, sent.durationMs > 0 ? sent.durationMs : result.durationMs);
      await _reload(scrollToBottom: true);
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

  void _toggleInputMode() {
    if (_voiceInputMode) {
      setState(() => _voiceInputMode = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _textFocus.requestFocus();
      });
    } else {
      _textFocus.unfocus();
      setState(() => _voiceInputMode = true);
    }
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sendingText || _sendingHold || _sendingImage) return;
    setState(() => _sendingText = true);
    try {
      await CommunityGroupChatService.sendText(
        communityId: widget.community.id,
        textContent: text,
      );
      _textCtrl.clear();
      await _reload(scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _sendingText = false);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    CommunityVoicePlayback.playingMessageId.removeListener(_onPlaybackChanged);
    unawaited(CommunityVoicePlayback.stop());
    unawaited(_recorder.dispose());
    final ids = _entries
        .map((e) => e.message?.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty);
    CommunityMediaCache.evictNotIn(ids);
    CommunityVoiceDuration.evictNotIn(ids);
    _textCtrl.dispose();
    _textFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = _elderUi ? 24.0 : 18.0;
    final bubbleMe = Theme.of(context).colorScheme.primary;
    final bubbleThem = const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          widget.community.name,
          style: TextStyle(fontSize: titleSize - 4, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => unawaited(_showChatMenu()),
            icon: const Icon(Icons.more_vert),
            tooltip: '更多',
          ),
        ],
      ),
      body: Column(
        children: [
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
            if (_showJoinWelcomeBanner && widget.joinWelcomeMessage != null)
              _JoinWelcomeBanner(
                elderHuge: _elderUi,
                message: widget.joinWelcomeMessage!,
                onDismiss: () => setState(() => _showJoinWelcomeBanner = false),
              ),
            Expanded(
              child: _initialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty && !_holdingMic
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '暂无消息\n新发言会显示在这里；若刚清空记录，此前内容仅对你不可见',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _elderUi ? 16 : 14,
                                color: const Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      cacheExtent: 800,
                      padding: const EdgeInsets.fromLTRB(16, 120, 16, 8),
                      itemCount: _entries.length + (_holdingMic ? 1 : 0) + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        final total = _entries.length + (_holdingMic ? 1 : 0) + (_loadingMore ? 1 : 0);
                        // reverse：最大 index 在顶部，用于加载更早消息
                        if (_loadingMore && i == total - 1) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              ),
                            ),
                          );
                        }
                        if (_holdingMic && i == 0) {
                          return _RecordingBubble(elderHuge: _elderUi);
                        }
                        var messageSlot = i;
                        if (_holdingMic) messageSlot--;
                        if (messageSlot < 0 || messageSlot >= _entries.length) {
                          return const SizedBox.shrink();
                        }
                        final entry = _entries[_entries.length - 1 - messageSlot];
                        if (entry.dateLabel != null) {
                          return _DateDivider(label: entry.dateLabel!, elderHuge: _elderUi);
                        }
                        final m = entry.message!;
                        final mine = _isMineMessage(m);
                        final timeLabel = _formatMessageTime(m.createdAtMillis);
                        if (m.isImage) {
                          return _ImageBubble(
                            key: ValueKey('img_${m.id}'),
                            elderHuge: _elderUi,
                            mine: mine,
                            message: m,
                            timeLabel: timeLabel,
                            avatarPath: _avatarPathForMessage(m),
                            emoji: _emojiForMessage(m),
                            onAvatarTap: _elderUi && !widget.readOnly
                                ? () => unawaited(_onAvatarTap(m))
                                : null,
                            onImageTap: () => _previewImage(m),
                          );
                        }
                        if (m.isVoice) {
                          return _VoiceBubble(
                            key: ValueKey('voice_${m.id}'),
                            elderHuge: _elderUi,
                            mine: mine,
                            message: m,
                            timeLabel: timeLabel,
                            bubbleMe: bubbleMe,
                            bubbleThem: bubbleThem,
                            playing: CommunityVoicePlayback.playingMessageId.value == m.id,
                            onTogglePlay: () => unawaited(_toggleVoicePlay(m)),
                            avatarPath: _avatarPathForMessage(m),
                            emoji: _emojiForMessage(m),
                            onAvatarTap: _elderUi && !widget.readOnly
                                ? () => unawaited(_onAvatarTap(m))
                                : null,
                          );
                        }
                        return _TextBubble(
                          key: ValueKey('text_${m.id}'),
                          elderHuge: _elderUi,
                          mine: mine,
                          name: m.senderDisplay,
                          text: m.textContent,
                          timeLabel: timeLabel,
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
            if (_canSend)
              _ChatInputBar(
                elderHuge: _elderUi,
                voiceInputMode: _voiceInputMode,
                holding: _holdingMic,
                busy: (_sendingHold && !_holdingMic) || _sendingImage || _sendingText,
                textController: _textCtrl,
                textFocusNode: _textFocus,
                onToggleInputMode: _toggleInputMode,
                onAttach: _showAttachSheet,
                onSendText: () => unawaited(_sendText()),
                onHoldStart: () => unawaited(_onHoldStart()),
                onHoldEnd: () => unawaited(_onHoldEnd()),
                onHoldCancel: () => unawaited(_abortHoldSilently()),
              )
            else
              _ReadOnlyBar(elderHuge: _elderUi),
          ],
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

class _MessageTimeLabel extends StatelessWidget {
  const _MessageTimeLabel({required this.label, required this.mine, required this.elderHuge});

  final String label;
  final bool mine;
  final bool elderHuge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4, left: mine ? 0 : 4, right: mine ? 4 : 0),
      child: Text(
        label,
        style: TextStyle(fontSize: elderHuge ? 12 : 11, color: const Color(0xFF94A3B8)),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({
    super.key,
    required this.elderHuge,
    required this.mine,
    required this.message,
    required this.timeLabel,
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
  final String timeLabel;
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
                          FutureBuilder<int>(
                            future: CommunityVoiceDuration.resolveMs(message),
                            builder: (context, snap) {
                              final ms = (snap.data ?? 0) > 0 ? snap.data! : message.durationMs;
                              return Text(
                                InterestCommunityVoiceMessage.formatDurationMs(ms),
                                style: TextStyle(
                                  fontSize: elderHuge ? 22 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: fg,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _MessageTimeLabel(label: timeLabel, mine: mine, elderHuge: elderHuge),
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

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({
    super.key,
    required this.elderHuge,
    required this.mine,
    required this.message,
    required this.timeLabel,
    this.avatarPath,
    this.emoji,
    this.onAvatarTap,
    required this.onImageTap,
  });

  final bool elderHuge;
  final bool mine;
  final InterestCommunityVoiceMessage message;
  final String timeLabel;
  final String? avatarPath;
  final String? emoji;
  final VoidCallback? onAvatarTap;
  final VoidCallback onImageTap;

  @override
  Widget build(BuildContext context) {
    final avatarSize = elderHuge ? 44.0 : 36.0;
    final maxW = elderHuge ? 220.0 : 200.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.senderDisplay,
                      style: TextStyle(
                        fontSize: elderHuge ? 14 : 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                CommunityChatImage(
                  message: message,
                  maxWidth: maxW,
                  onTap: onImageTap,
                ),
                _MessageTimeLabel(label: timeLabel, mine: mine, elderHuge: elderHuge),
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
    super.key,
    required this.elderHuge,
    required this.mine,
    required this.name,
    required this.text,
    required this.timeLabel,
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
  final String timeLabel;
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
                _MessageTimeLabel(label: timeLabel, mine: mine, elderHuge: elderHuge),
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
  const _ReadOnlyBar({required this.elderHuge});

  final bool elderHuge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8FC),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, color: const Color(0xFF64748B), size: elderHuge ? 24 : 20),
              SizedBox(width: elderHuge ? 10 : 8),
              Expanded(
                child: Text(
                  '子女端仅预览，不能发言 · ⋮ 可清空你这边看到的记录',
                  style: TextStyle(
                    fontSize: elderHuge ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachAction extends StatelessWidget {
  const _AttachAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE2E8F0),
              child: Icon(icon, size: 28, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.elderHuge,
    required this.voiceInputMode,
    required this.holding,
    required this.busy,
    required this.textController,
    required this.textFocusNode,
    required this.onToggleInputMode,
    required this.onAttach,
    required this.onSendText,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
  });

  final bool elderHuge;
  final bool voiceInputMode;
  final bool holding;
  final bool busy;
  final TextEditingController textController;
  final FocusNode textFocusNode;
  final VoidCallback onToggleInputMode;
  final VoidCallback onAttach;
  final VoidCallback onSendText;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onHoldCancel;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final fontSize = elderHuge ? 18.0 : 16.0;
    final inputHeight = elderHuge ? 48.0 : 44.0;

    return Material(
      color: const Color(0xFFF7F8FC),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 8, 8 + bottom * 0.15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: busy ? null : onAttach,
                icon: Icon(Icons.add_circle_outline, size: elderHuge ? 32 : 28),
                color: const Color(0xFF475569),
                tooltip: '发送图片',
              ),
              IconButton(
                onPressed: busy ? null : onToggleInputMode,
                icon: Icon(
                  voiceInputMode ? Icons.keyboard_rounded : Icons.mic_rounded,
                  size: elderHuge ? 30 : 26,
                ),
                color: const Color(0xFF475569),
                tooltip: voiceInputMode ? '切换键盘输入' : '切换语音输入',
              ),
              Expanded(
                child: voiceInputMode
                    ? Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: busy ? null : (_) => onHoldStart(),
                        onPointerUp: (_) => onHoldEnd(),
                        onPointerCancel: (_) => onHoldCancel(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: inputHeight,
                          decoration: BoxDecoration(
                            color: holding ? const Color(0xFF047857) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: holding ? const Color(0xFF047857) : const Color(0xFFD1D5DB),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: busy && !holding
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : Text(
                                  holding ? '松手发送' : '按住 说话',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w700,
                                    color: holding ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                        ),
                      )
                    : TextField(
                        controller: textController,
                        focusNode: textFocusNode,
                        enabled: !busy,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(fontSize: fontSize),
                        textInputAction: TextInputAction.send,
                        onSubmitted: busy ? null : (_) => onSendText(),
                        decoration: InputDecoration(
                          hintText: '输入文字消息',
                          hintStyle: TextStyle(
                            fontSize: fontSize - 1,
                            color: const Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: elderHuge ? 12 : 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
              ),
              if (!voiceInputMode) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: busy ? null : onSendText,
                  icon: busy
                      ? SizedBox(
                          width: elderHuge ? 24 : 22,
                          height: elderHuge ? 24 : 22,
                          child: const CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Icon(Icons.send_rounded, size: elderHuge ? 30 : 26),
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: '发送',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinWelcomeBanner extends StatelessWidget {
  const _JoinWelcomeBanner({
    required this.elderHuge,
    required this.message,
    required this.onDismiss,
  });

  final bool elderHuge;
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.all(elderHuge ? 14 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_outlined, color: const Color(0xFF1565C0), size: elderHuge ? 28 : 24),
              SizedBox(width: elderHuge ? 12 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '群助手',
                      style: TextStyle(
                        fontSize: elderHuge ? 15 : 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.trim(),
                      style: TextStyle(
                        fontSize: elderHuge ? 16 : 14,
                        height: 1.45,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 20),
                color: const Color(0xFF64748B),
                tooltip: '关闭',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
