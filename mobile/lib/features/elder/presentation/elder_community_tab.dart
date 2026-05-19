import 'package:flutter/material.dart';

import '../../interest_community/presentation/widgets/elder_friend_section.dart';
import '../../interest_community/presentation/widgets/interest_community_elder_section.dart';

/// 老人端底部导航「社群」Tab：兴趣社群 + 我的好友。
final class ElderCommunityTab extends StatelessWidget {
  const ElderCommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('社群', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tabs: const [
                      Tab(text: '兴趣社群'),
                      Tab(text: '我的好友'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: TabBarView(
              children: [
                InterestCommunityElderSection(),
                ElderFriendSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
