import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../data/community_direct_repository.dart';
import '../data/community_scope.dart';
import '../data/community_voice_playback.dart';
import '../data/community_voice_recorder.dart';
import '../data/elder_avatar_repository.dart';
import '../data/friend_discover_catalog.dart';
import '../models/community_message.dart';
import 'widgets/community_member_avatar.dart';

/// 老人与好友的一对一语音私聊（本机演示）。
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
  List<_DirectListEntry> _entries = [];
  String? _selfAvatarPath;
  String? _peerAvatarPath;
  bool _loading = true;
  bool _holdingMic = false;
  bool _sendingHold = false;
  String? _holdErrorText;

  String get _ownerScope => CommunityScope.forCurrentElder();

  @override
  void initState() {
    super.initState();
    CommunityVoicePlayback.playingMessageId.addListener(_onPlaybackChanged);
    unawaited(_reload());
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

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await CommunityDirectRepository.loadThread(
      ownerScope: _ownerScope,
      peerScope: widget.peerScopeKey,
    );
    final selfAvatar = await ElderAvatarRepository.loadPath(_ownerScope);
    final peerAvatar = await ElderAvatarRepository.loadPath(widget.peerScopeKey);
    if (!mounted) return;
    setState(() {
      _entries = _buildEntries(list);
      _selfAvatarPath = selfAvatar;
      _peerAvatarPath = peerAvatar;
      _loading = false;
    });
    _scrollToBottom();
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

  bool _isMine(InterestCommunityVoiceMessage m) => m.senderScopeKey == _ownerScope;

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
      final msg = InterestCommunityVoiceMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_direct',
        communityId: 'direct',
        role: CommunitySenderRole.elder,
        senderDisplay: AuthSession.elderName ?? '我',
        senderScopeKey: _ownerScope,
        kind: CommunityMessageKind.voice,
        audioPath: result.path,
        durationMs: result.durationMs,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await CommunityDirectRepository.appendMessage(
        ownerScope: _ownerScope,
        peerScope: widget.peerScopeKey,
        message: msg,
      );
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
    final bubbleMe = Theme.of(context).colorScheme.primary;
    const bubbleThem = Color(0xFFE2E8F0);
    final peerEmoji = widget.peerEmoji ?? FriendDiscoverCatalog.byScopeKey(widget.peerScopeKey)?.emoji;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Row(
          children: [
            CommunityMemberAvatar(
              displayName: widget.peerDisplayName,
              imagePath: _peerAvatarPath,
              emoji: peerEmoji,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerDisplayName,
                style: const TextStyle(fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '与「${widget.peerDisplayName}」的私聊。按住底部按钮说话，松手发送。',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF64748B), height: 1.52),
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
                    style: const TextStyle(fontSize: 15, color: Color(0xFFB45309)),
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
                          return _RecordingBubble(selfAvatarPath: _selfAvatarPath);
                        }
                        if (i >= _entries.length) return const SizedBox.shrink();
                        final entry = _entries[i];
                        if (entry.dateLabel != null) {
                          return _DateDivider(label: entry.dateLabel!);
                        }
                        final m = entry.message!;
                        final mine = _isMine(m);
                        final avatarPath = mine ? _selfAvatarPath : _peerAvatarPath;
                        final emoji = mine ? null : peerEmoji;
                        if (m.isVoice) {
                          return _VoiceRow(
                            mine: mine,
                            message: m,
                            avatarPath: avatarPath,
                            emoji: emoji,
                            bubbleMe: bubbleMe,
                            bubbleThem: bubbleThem,
                            playing: CommunityVoicePlayback.playingMessageId.value == m.id,
                            onTogglePlay: () => unawaited(
                              CommunityVoicePlayback.toggle(m.id, m.audioPath!),
                            ),
                          );
                        }
                        return _TextRow(
                          mine: mine,
                          name: m.senderDisplay,
                          text: m.textContent,
                          avatarPath: avatarPath,
                          emoji: emoji,
                          bubbleMe: bubbleMe,
                          bubbleThem: bubbleThem,
                        );
                      },
                    ),
            ),
            _MicBar(
              holding: _holdingMic,
              busy: _sendingHold && !_holdingMic,
              onHoldStart: () => unawaited(_onHoldStart()),
              onHoldEnd: () => unawaited(_onHoldEnd()),
              onHoldCancel: () => unawaited(_abortHoldSilently()),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.mine,
    required this.message,
    required this.avatarPath,
    required this.emoji,
    required this.bubbleMe,
    required this.bubbleThem,
    required this.playing,
    required this.onTogglePlay,
  });

  final bool mine;
  final InterestCommunityVoiceMessage message;
  final String? avatarPath;
  final String? emoji;
  final Color bubbleMe;
  final Color bubbleThem;
  final bool playing;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : const Color(0xFF0F172A);
    final bg = mine ? bubbleMe : bubbleThem;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            CommunityMemberAvatar(displayName: message.senderDisplay, imagePath: avatarPath, emoji: emoji, size: 40),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                  child: Text(
                    message.senderDisplay,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                ),
                Material(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 18),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 18),
                    ),
                    onTap: onTogglePlay,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                            size: 36,
                            color: fg,
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.graphic_eq_rounded, size: 28, color: fg.withValues(alpha: 0.85)),
                          const SizedBox(width: 10),
                          Text(
                            message.displaySummary,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg),
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
            const SizedBox(width: 8),
            CommunityMemberAvatar(displayName: message.senderDisplay, imagePath: avatarPath, size: 40),
          ],
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.mine,
    required this.name,
    required this.text,
    required this.avatarPath,
    required this.emoji,
    required this.bubbleMe,
    required this.bubbleThem,
  });

  final bool mine;
  final String name;
  final String text;
  final String? avatarPath;
  final String? emoji;
  final Color bubbleMe;
  final Color bubbleThem;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : const Color(0xFF0F172A);
    final bg = mine ? bubbleMe : bubbleThem;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            CommunityMemberAvatar(displayName: name, imagePath: avatarPath, emoji: emoji, size: 40),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 20, height: 1.5, fontWeight: FontWeight.w600, color: fg),
                  ),
                ),
              ],
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 8),
            CommunityMemberAvatar(displayName: name, imagePath: avatarPath, size: 40),
          ],
        ],
      ),
    );
  }
}

class _RecordingBubble extends StatelessWidget {
  const _RecordingBubble({this.selfAvatarPath});

  final String? selfAvatarPath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_rounded, size: 28, color: Color(0xFF047857)),
                SizedBox(width: 10),
                Text('正在录音…', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CommunityMemberAvatar(displayName: '我', imagePath: selfAvatarPath, size: 40),
        ],
      ),
    );
  }
}

class _MicBar extends StatelessWidget {
  const _MicBar({
    required this.holding,
    required this.busy,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
  });

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
          children: [
            Text(
              holding ? '松手即可发送语音…' : (busy ? '正在发送语音…' : '按住下方的「按住说话」'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F766E)),
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
                    width: 220,
                    height: 84,
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
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mic_rounded, size: 34, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text('按住说话', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
