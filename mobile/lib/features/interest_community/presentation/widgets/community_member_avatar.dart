import 'dart:io';

import 'package:flutter/material.dart';

/// 群聊/资料中的圆形头像。
final class CommunityMemberAvatar extends StatelessWidget {
  const CommunityMemberAvatar({
    super.key,
    required this.displayName,
    this.imagePath,
    this.emoji,
    this.size = 44,
    this.onTap,
  });

  final String displayName;
  final String? imagePath;
  final String? emoji;
  final double size;
  final VoidCallback? onTap;

  static String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return String.fromCharCode(t.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    Widget child;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      child = ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (emoji != null && emoji!.isNotEmpty) {
      child = CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFE2E8F0),
        child: Text(emoji!, style: TextStyle(fontSize: size * 0.46)),
      );
    } else {
      child = CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFDBEAFE),
        foregroundColor: const Color(0xFF1D4ED8),
        child: Text(
          _initial(displayName),
          style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w800),
        ),
      );
    }

    if (onTap == null) return SizedBox(width: size, height: size, child: child);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }
}
