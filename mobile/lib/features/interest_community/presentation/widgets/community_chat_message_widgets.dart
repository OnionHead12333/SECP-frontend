import 'package:flutter/material.dart';

import '../../data/community_voice_duration.dart';
import '../../models/community_message.dart';
import 'community_chat_image.dart';
import 'community_member_avatar.dart';

/// 群聊 / 私聊共用的消息气泡与输入栏（老人端大号样式）。
final class CommunityChatDateDivider extends StatelessWidget {
  const CommunityChatDateDivider({super.key, required this.label, this.elderHuge = true});

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

final class CommunityChatMessageTimeLabel extends StatelessWidget {
  const CommunityChatMessageTimeLabel({
    super.key,
    required this.label,
    required this.mine,
    this.elderHuge = true,
  });

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

final class CommunityChatVoiceBubble extends StatelessWidget {
  const CommunityChatVoiceBubble({
    super.key,
    required this.mine,
    required this.message,
    required this.timeLabel,
    required this.bubbleMe,
    required this.bubbleThem,
    required this.playing,
    required this.onTogglePlay,
    this.avatarPath,
    this.emoji,
    this.elderHuge = true,
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
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: elderHuge ? 28 : 24,
                            color: fg.withValues(alpha: 0.85),
                          ),
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
                CommunityChatMessageTimeLabel(label: timeLabel, mine: mine, elderHuge: elderHuge),
              ],
            ),
          ),
          if (mine) ...[
            SizedBox(width: elderHuge ? 10 : 8),
            CommunityMemberAvatar(
              displayName: message.senderDisplay,
              imagePath: avatarPath,
              size: avatarSize,
            ),
          ],
        ],
      ),
    );
  }
}

final class CommunityChatImageBubble extends StatelessWidget {
  const CommunityChatImageBubble({
    super.key,
    required this.mine,
    required this.message,
    required this.timeLabel,
    required this.onImageTap,
    this.avatarPath,
    this.emoji,
    this.elderHuge = true,
  });

  final bool elderHuge;
  final bool mine;
  final InterestCommunityVoiceMessage message;
  final String timeLabel;
  final String? avatarPath;
  final String? emoji;
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
                CommunityChatImage(message: message, maxWidth: maxW, onTap: onImageTap),
                CommunityChatMessageTimeLabel(label: timeLabel, mine: mine, elderHuge: elderHuge),
              ],
            ),
          ),
          if (mine) ...[
            SizedBox(width: elderHuge ? 10 : 8),
            CommunityMemberAvatar(
              displayName: message.senderDisplay,
              imagePath: avatarPath,
              size: avatarSize,
            ),
          ],
        ],
      ),
    );
  }
}

final class CommunityChatTextBubble extends StatelessWidget {
  const CommunityChatTextBubble({
    super.key,
    required this.mine,
    required this.name,
    required this.text,
    required this.timeLabel,
    required this.bubbleMe,
    required this.bubbleThem,
    this.avatarPath,
    this.emoji,
    this.elderHuge = true,
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
            CommunityMemberAvatar(displayName: name, imagePath: avatarPath, emoji: emoji, size: avatarSize),
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
                CommunityChatMessageTimeLabel(label: timeLabel, mine: mine, elderHuge: elderHuge),
              ],
            ),
          ),
          if (mine) ...[
            SizedBox(width: elderHuge ? 10 : 8),
            CommunityMemberAvatar(displayName: name, imagePath: avatarPath, size: avatarSize),
          ],
        ],
      ),
    );
  }
}

final class CommunityChatRecordingBubble extends StatelessWidget {
  const CommunityChatRecordingBubble({super.key, this.elderHuge = true});

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

final class CommunityChatAttachAction extends StatelessWidget {
  const CommunityChatAttachAction({
    super.key,
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

final class CommunityChatInputBar extends StatelessWidget {
  const CommunityChatInputBar({
    super.key,
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
    this.elderHuge = true,
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
