import 'package:flutter/material.dart';

/// 原为老人端全局悬浮 SOS；已按产品要求移除悬浮入口，此处保留为 builder 透传。
class ElderGlobalSosOverlay extends StatelessWidget {
  const ElderGlobalSosOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
