import 'package:flutter/material.dart';

/// 入群成功后立即展示群助手欢迎语（数据来自 join API，非消息列表）。
abstract final class CommunityWelcomeDialog {
  static Future<void> show(
    BuildContext context, {
    required String communityName,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.celebration_outlined, color: Color(0xFF1565C0), size: 36),
        title: Text('欢迎加入「$communityName」', style: const TextStyle(fontSize: 20)),
        content: SingleChildScrollView(
          child: Text(
            message.trim(),
            style: const TextStyle(fontSize: 17, height: 1.55, color: Color(0xFF334155)),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
