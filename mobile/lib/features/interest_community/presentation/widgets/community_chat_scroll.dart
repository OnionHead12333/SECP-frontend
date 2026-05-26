import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 群聊 / 私聊列表滚动：正序（早→晚），短内容顶对齐，长内容默认在底部。
abstract final class CommunityChatScroll {
  static bool isNearBottom(ScrollPosition pos, {double threshold = 96}) {
    return pos.pixels >= pos.maxScrollExtent - threshold;
  }

  static bool isNearTop(ScrollPosition pos, {double threshold = 140}) {
    return pos.pixels <= threshold;
  }

  /// 锚定到最新消息（列表最底端）。
  static void anchorToLatest(
    ScrollController controller, {
    bool animated = true,
  }) {
    if (!controller.hasClients) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        anchorToLatest(controller, animated: animated);
      });
      return;
    }

    void jump() {
      if (!controller.hasClients) return;
      final target = controller.position.maxScrollExtent;
      if (animated) {
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        controller.jumpTo(target);
      }
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      jump();
      SchedulerBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  /// 在列表顶部插入更早消息后保持阅读位置。
  static void preserveAfterPrepend({
    required ScrollController controller,
    required double oldPixels,
    required double oldMax,
  }) {
    if (!controller.hasClients) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      final pos = controller.position;
      if (isNearBottom(pos) || oldPixels >= oldMax - 96) {
        controller.jumpTo(pos.maxScrollExtent);
      } else {
        final delta = pos.maxScrollExtent - oldMax;
        controller.jumpTo(
          (oldPixels + delta).clamp(0.0, pos.maxScrollExtent),
        );
      }
    });
  }
}
