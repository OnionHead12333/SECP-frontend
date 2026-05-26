import 'package:flutter/material.dart';

import '../../data/community_media_cache.dart';
import '../../data/community_media_load_result.dart';
import '../../models/community_message.dart';

/// 群聊图片气泡：按需下载 bytes → [Image.memory]，失败显示「媒体不可用」。
final class CommunityChatImage extends StatelessWidget {
  const CommunityChatImage({
    super.key,
    required this.message,
    this.fit = BoxFit.cover,
    this.maxWidth = 240,
    this.maxHeight = 280,
    this.minHeight = 120,
    this.onTap,
  });

  final InterestCommunityVoiceMessage message;
  final BoxFit fit;
  final double maxWidth;
  final double maxHeight;
  final double minHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CommunityMediaLoadResult>(
      future: CommunityMediaCache.loadImage(message),
      builder: (context, snap) {
        final state = snap.data;
        Widget child;
        bool tappable = false;

        if (snap.connectionState != ConnectionState.done || state is CommunityMediaLoading) {
          child = _placeholderBox(
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        } else if (state is CommunityMediaReady && state.bytes != null && state.bytes!.isNotEmpty) {
          tappable = onTap != null;
          child = Image.memory(
            state.bytes!,
            fit: fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        } else {
          final label = state is CommunityMediaUnavailable ? state.message : '媒体不可用';
          child = _placeholderBox(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey.shade600),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: tappable ? onTap : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _placeholderBox({required Widget child}) {
    return Container(
      width: maxWidth,
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// 全屏预览（同样走按需下载）。
final class CommunityChatImagePreview extends StatelessWidget {
  const CommunityChatImagePreview({super.key, required this.message});

  final InterestCommunityVoiceMessage message;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CommunityMediaLoadResult>(
      future: CommunityMediaCache.loadImage(message),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        final state = snap.data;
        if (state is CommunityMediaReady && state.bytes != null && state.bytes!.isNotEmpty) {
          return InteractiveViewer(
            child: Image.memory(state.bytes!, fit: BoxFit.contain),
          );
        }
        final label = state is CommunityMediaUnavailable ? state.message : '媒体不可用';
        return Text(label, style: const TextStyle(color: Colors.white));
      },
    );
  }
}
