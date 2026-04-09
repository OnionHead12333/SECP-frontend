import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../elder_module_routes.dart';
import 'elder_login_page.dart';

class ElderHomePage extends StatelessWidget {
  const ElderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final elderName = AuthSession.elderName ?? '老人用户';
    final familyCount = AuthSession.elderFamilyCount;
    final claimed = AuthSession.elderClaimed;
    final phone = AuthSession.elderPhone ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('老人端首页'),
        actions: [
          IconButton(
            onPressed: () {
              AuthSession.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const ElderLoginPage()),
                (route) => false,
              );
            },
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFEFF6FF)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '您好，$elderName',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text('手机号：$phone', style: const TextStyle(fontSize: 17)),
                const SizedBox(height: 8),
                Text(
                  claimed ? '当前状态：已认领老人资料' : '当前状态：未认领老人资料',
                  style: TextStyle(
                    fontSize: 17,
                    color: claimed ? const Color(0xFF166534) : const Color(0xFFB45309),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ActionCard(
            icon: Icons.family_restroom_outlined,
            title: '家属绑定状态',
            content: familyCount > 0 ? '当前已绑定 $familyCount 位家属，点击查看绑定详情。' : '当前还没有绑定家属，点击查看绑定说明。',
            onTap: () => Navigator.of(context).pushNamed(ElderModuleRoutes.elderBinding),
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.assignment_turned_in_outlined,
            title: '健康与家庭状态',
            content: '已完成账号进入、资料识别与家属信息承接，后续可继续接入真实服务数据与更多养老功能。',
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.badge_outlined,
            title: '账号信息',
            content: '当前页面展示老人账号基础信息、家属绑定状态与后续服务入口，可作为统一登录后进入老人端的首页承接。',
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF374151)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF4B5563), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFF374151)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: const TextStyle(fontSize: 16, color: Color(0xFF4B5563), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
