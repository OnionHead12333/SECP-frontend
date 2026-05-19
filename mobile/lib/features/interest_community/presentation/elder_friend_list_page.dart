import 'package:flutter/material.dart';

import 'widgets/elder_friend_section.dart';

/// 老人端：我的好友列表（独立页面，内容与「社群」Tab 一致）。
final class ElderFriendListPage extends StatelessWidget {
  const ElderFriendListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('我的好友'),
        backgroundColor: const Color(0xFFF7F8FC),
      ),
      body: const ElderFriendSection(),
    );
  }
}
