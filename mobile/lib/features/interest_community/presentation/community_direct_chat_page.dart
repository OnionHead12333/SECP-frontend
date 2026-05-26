import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/community_avatar_resolver.dart';
import '../data/community_direct_chat_service.dart';
import '../data/community_media_cache.dart';
import '../data/community_scope.dart';
import '../data/community_voice_duration.dart';
import '../data/community_voice_playback.dart';
import '../data/community_voice_recorder.dart';
import '../models/community_message.dart';
import 'widgets/community_chat_image.dart';
import 'widgets/community_chat_message_widgets.dart';
import 'widgets/community_chat_scroll.dart';
import 'widgets/community_member_avatar.dart';

/// 老人与好友的一对一私聊（对接后端 API）。
final class CommunityDirectChatPage extends StatefulWidget {
  const CommunityDirectChatPage({
    super.key,
    required this.peerScopeKey,
    required this.peerDisplayName,
    this.peerEmoji,
  });

  final String peerScopeKey;
  final String peerDisplayName;
  final String? peerEmoji;

  @override
  State<CommunityDirectChatPage> createState() => _CommunityDirectChatPageState();
}

final class _DirectListEntry {
  const _DirectListEntry.date(this.dateLabel) : message = null;
  const _DirectListEntry.message(this.message) : dateLabel = null;

  final String? dateLabel;
  final InterestCommunityVoiceMessage? message;
}

class _CommunityDirectChatPageState extends State<CommunityDirectChatPage> {
  final ScrollController _scroll = ScrollController();
  final CommunityVoiceRecorder _recorder = CommunityVoiceRecorder();
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  List<_DirectListEntry> _entries = [];
  List<InterestCommunityVoiceMessage> _rawMessages = [];
  Map<String, String> _avatarPaths = {};
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _nextBefore;
  bool _stickToBottom = true;
  bool _holdingMic = false;
  bool _sendingHold = false;
  bool _sendingImage = false;
  bool _sendingText = false;
  bool _voiceInputMode = true;
  String? _holdErrorText;

  String get _ownerScope => CommunityScope.forCurrentElder();

  String? get _peerEmoji => widget.peerEmoji;

  @override
  void initState() {
    super.initState();
    CommunityVoicePlayback.playingMessageId.addListener(_onPlaybackChanged);
    _scroll.addListener(_onScroll);
    unawaited(_loadInitial());
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _stickToBottom = CommunityChatScroll.isNearBottom(pos);
    if (CommunityChatScroll.isNearTop(pos) && !_loadingMore && _hasMore) {
      unawaited(_loadOlder());
    }
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  List<_DirectListEntry> _buildEntries(List<InterestCommunityVoiceMessage> messages) {
    final entries = <_DirectListEntry>[];
    DateTime? lastDay;
    for (final m in messages) {
      final dt = DateTime.fromMillisecondsSinceEpoch(m.createdAtMillis).toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      if (lastDay == null || day != lastDay) {
        entries.add(_DirectListEntry.date(_dateLabel(day)));
        lastDay = day;
      }
      entries.add(_DirectListEntry.message(m));
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
    if (prepend) {
      final existing = _rawMessages.map((e) => e.id).toSet();
      final older = incoming.where((m) => !existing.contains(m.id)).toList();
      _rawMessages = [...older, ..._rawMessages];
    } else {
      _rawMessages = List.of(incoming);
    }
    _rawMessages.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    _hasMore = hasMore;
    _nextBefore = nextBefore;
    _entries = _buildEntries(_rawMessages);
  }

  Future<void> _refreshAvatars() async {
    final scopeKeys = <String>{_ownerScope, widget.peerScopeKey};
    final remoteAvatarUrls = <String, String>{};
    for (final m in _rawMessages) {
      if (m.senderScopeKey.isNotEmpty) scopeKeys.add(m.senderScopeKey);
      final url = m.senderAvatarUrl;
      if (m.senderScopeKey.isNotEmpty && url != null && url.isNotEmpty) {
        remoteAvatarUrls[m.senderScopeKey] = url;
      }
    }
    final paths = await CommunityAvatarResolver.loadPathsForScopes(
      scopeKeys,
      remoteAvatarUrlsByScope: remoteAvatarUrls,
    );
    if (!mounted) return;
    setState(() => _avatarPaths = paths);
  }

  Future<void> _loadInitial() async {
    setState(() => _initialLoading = true);
    try {
      final list = await CommunityDirectChatService.loadMessages(
        peerScopeKey: widget.peerScopeKey,
      );
      if (!mounted) return;
      _applyMessages(list, prepend: false, hasMore: false, nextBefore: null);
      final ids = _rawMessages.map((m) => m.id);
      CommunityMediaCache.evictNotIn(ids);
      CommunityVoiceDuration.evictNotIn(ids);
      setState(() => _initialLoading = false);
      _stickToBottom = true;
      unawaited(_refreshAvatars());
      CommunityChatScroll.anchorToLatest(_scroll, animated: false);
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
      final page = await CommunityDirectChatService.loadMessagesPage(
        peerScopeKey: widget.peerScopeKey,
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
      CommunityChatScroll.preserveAfterPrepend(
        controller: _scroll,
        oldPixels: oldPixels,
        oldMax: oldMax,
      );
      unawaited(_refreshAvatars());
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
      final list = await CommunityDirectChatService.loadMessages(
        peerScopeKey: widget.peerScopeKey,
      );
      if (!mounted) return;
      _applyMessages(list, prepend: false, hasMore: false, nextBefore: null);
      final ids = _rawMessages.map((m) => m.id);
      CommunityMediaCache.evictNotIn(ids);
      CommunityVoiceDuration.evictNotIn(ids);
      setState(() {});
      unawaited(_refreshAvatars());
      if (shouldScroll) CommunityChatScroll.anchorToLatest(_scroll, animated: scrollToBottom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  bool _isMine(InterestCommunityVoiceMessage m) =>
      m.mine ?? (m.senderScopeKey == _ownerScope);

  String? _avatarPathForMessage(InterestCommunityVoiceMessage m) {
    final key = m.senderScopeKey;
    if (key.isEmpty) return null;
    return _avatarPaths[key];
  }

  String? _emojiForMessage(InterestCommunityVoiceMessage m) {
    if (m.senderEmoji != null && m.senderEmoji!.isNotEmpty) return m.senderEmoji;
    if (m.senderScopeKey == widget.peerScopeKey) return _peerEmoji;
    return CommunityAvatarResolver.emojiForScope(m.senderScopeKey);
  }

  Future<void> _toggleVoicePlay(InterestCommunityVoiceMessage message) async {
    final ok = await CommunityVoicePlayback.toggleMessage(message);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('媒体不可用')),
      );
    }
  }

  void _previewImage(InterestCommunityVoiceMessage message) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CommunityChatImagePreview(message: message)),
        ),
      ),
    );
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
          const SnackBar(content: Text('说话时间太短，请按住多说一会儿。')),
        );
        return;
      }
      final sent = await CommunityDirectChatService.sendVoice(
        peerScopeKey: widget.peerScopeKey,
        file: File(result.path),
        durationMs: result.durationMs,
      );
      CommunityVoiceDuration.remember(
        sent.id,
        sent.durationMs > 0 ? sent.durationMs : result.durationMs,
      );
      await _reload(scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：${e.toString().replaceFirst('Exception: ', '')}')),
      );
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
      await CommunityDirectChatService.sendText(
        peerScopeKey: widget.peerScopeKey,
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
              CommunityChatAttachAction(
                icon: Icons.photo_camera_outlined,
                label: '拍照',
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_pickAndSendImage(ImageSource.camera));
                },
              ),
              CommunityChatAttachAction(
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

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_sendingImage || _sendingHold) return;
    final xfile = await _imagePicker.pickImage(source: source, maxWidth: 2400, imageQuality: 88);
    if (xfile == null || !mounted) return;

    final file = File(xfile.path);
    // 防止设备/系统相册返回了非图片文件（例如音频），导致后端 MIME 校验失败。
    final ok = await _isProbablyImageFile(file);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片发送失败：请选择图片文件（非音频）')),
      );
      return;
    }

    setState(() => _sendingImage = true);
    try {
      await CommunityDirectChatService.sendImage(
        peerScopeKey: widget.peerScopeKey,
        file: file,
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

  Future<bool> _isProbablyImageFile(File file) async {
    if (!await file.exists()) return false;
    final lower = file.path.toLowerCase();
    final extOk = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
    if (!extOk) return false;

    // 轻量识别文件头，避免仅靠后缀。
    try {
      final len = await file.length();
      if (len < 12) return false;
      final raf = file.openRead(0, 32);
      final chunk = await raf.reduce((a, b) => a..addAll(b));
      final bytes = chunk;

      // JPEG: FF D8 FF
      if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return true;
      }
      // PNG: 89 50 4E 47 0D 0A 1A 0A
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0D &&
          bytes[5] == 0x0A &&
          bytes[6] == 0x1A &&
          bytes[7] == 0x0A) {
        return true;
      }
      // WEBP: RIFF....WEBP
      if (bytes.length >= 12 &&
          bytes[0] == 'R'.codeUnitAt(0) &&
          bytes[1] == 'I'.codeUnitAt(0) &&
          bytes[2] == 'F'.codeUnitAt(0) &&
          bytes[3] == 'F'.codeUnitAt(0) &&
          bytes[8] == 'W'.codeUnitAt(0) &&
          bytes[9] == 'E'.codeUnitAt(0) &&
          bytes[10] == 'B'.codeUnitAt(0) &&
          bytes[11] == 'P'.codeUnitAt(0)) {
        return true;
      }
      // BMP: 'BM'
      if (bytes.length >= 2 &&
          bytes[0] == 'B'.codeUnitAt(0) &&
          bytes[1] == 'M'.codeUnitAt(0)) {
        return true;
      }
    } catch (_) {
      return false;
    }
    // 如果文件头识别失败，但后缀看起来像图片，也允许上传（兼容某些奇怪格式）。
    return extOk;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    CommunityVoicePlayback.playingMessageId.removeListener(_onPlaybackChanged);
    unawaited(CommunityVoicePlayback.stop());
    unawaited(_recorder.dispose());
    final ids = _rawMessages.map((m) => m.id);
    CommunityMediaCache.evictNotIn(ids);
    CommunityVoiceDuration.evictNotIn(ids);
    _textCtrl.dispose();
    _textFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleMe = Theme.of(context).colorScheme.primary;
    const bubbleThem = Color(0xFFE2E8F0);
    final peerAvatarPath = _avatarPaths[widget.peerScopeKey];

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Row(
          children: [
            CommunityMemberAvatar(
              displayName: widget.peerDisplayName,
              imagePath: peerAvatarPath,
              emoji: _peerEmoji,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerDisplayName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
                  style: const TextStyle(fontSize: 15, color: Color(0xFFB45309)),
                ),
              ),
            ),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: _initialLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty && !_holdingMic
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '暂无消息\n按住说话、点键盘输入文字，或点 + 发送图片',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        cacheExtent: 800,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: _entries.length + (_holdingMic ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i < _entries.length) {
                            final entry = _entries[i];
                            if (entry.dateLabel != null) {
                              return CommunityChatDateDivider(label: entry.dateLabel!);
                            }
                            final m = entry.message!;
                            final mine = _isMine(m);
                            final timeLabel = _formatMessageTime(m.createdAtMillis);
                            final avatarPath = _avatarPathForMessage(m);
                            final emoji = _emojiForMessage(m);
                            if (m.isImage) {
                              return CommunityChatImageBubble(
                                key: ValueKey('img_${m.id}'),
                                mine: mine,
                                message: m,
                                timeLabel: timeLabel,
                                avatarPath: avatarPath,
                                emoji: emoji,
                                onImageTap: () => _previewImage(m),
                              );
                            }
                            if (m.isVoice) {
                              return CommunityChatVoiceBubble(
                                key: ValueKey('voice_${m.id}'),
                                mine: mine,
                                message: m,
                                timeLabel: timeLabel,
                                bubbleMe: bubbleMe,
                                bubbleThem: bubbleThem,
                                playing: CommunityVoicePlayback.playingMessageId.value == m.id,
                                onTogglePlay: () => unawaited(_toggleVoicePlay(m)),
                                avatarPath: avatarPath,
                                emoji: emoji,
                              );
                            }
                            return CommunityChatTextBubble(
                              key: ValueKey('text_${m.id}'),
                              mine: mine,
                              name: m.senderDisplay,
                              text: m.textContent,
                              timeLabel: timeLabel,
                              bubbleMe: bubbleMe,
                              bubbleThem: bubbleThem,
                              avatarPath: avatarPath,
                              emoji: emoji,
                            );
                          }
                          if (_holdingMic && i == _entries.length) {
                            return const CommunityChatRecordingBubble();
                          }
                          return const SizedBox.shrink();
                        },
                      ),
          ),
          CommunityChatInputBar(
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
          ),
        ],
      ),
    );
  }
}
