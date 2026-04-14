import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_mock_auth_service.dart';
import '../models/elder_mock_family_member.dart';

class ElderBindingStatusPage extends StatelessWidget {
  const ElderBindingStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = AuthSession.elderPhone ?? '';
    final familyMembers = ElderMockAuthService.familyMembersForPhone(phone);
    final hasBindings = familyMembers.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('家属绑定详情')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SummaryBanner(
            hasBindings: hasBindings,
            familyCount: familyMembers.length,
            phone: phone,
          ),
          const SizedBox(height: 18),
          if (hasBindings) ...[
            Text(
              '已绑定家属',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            for (final member in familyMembers) ...[
              _FamilyMemberCard(member: member),
              const SizedBox(height: 12),
            ],
          ] else ...[
            const _EmptyBindingCard(),
          ],
          const SizedBox(height: 18),
          const _NextStepCard(),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.hasBindings,
    required this.familyCount,
    required this.phone,
  });

  final bool hasBindings;
  final int familyCount;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasBindings
              ? const [Color(0xFFFFF7ED), Color(0xFFEFF6FF)]
              : const [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasBindings ? '当前已完成家属绑定' : '当前还没有家属绑定',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text('老人手机号：${phone.isEmpty ? '-' : phone}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            hasBindings ? '已绑定 $familyCount 位家属，可继续查看家属详情。' : '后续子女完成绑定后，这里会显示家属信息。',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({required this.member});

  final ElderMockFamilyMember member;

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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.family_restroom_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (member.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '主要联系人',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('关系：${member.relation}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text('联系电话：${member.phone}', style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBindingCard extends StatelessWidget {
  const _EmptyBindingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: const [
          Icon(Icons.link_off_outlined, size: 44, color: Color(0xFF64748B)),
          SizedBox(height: 12),
          Text(
            '还没有家属绑定',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            '当前老人账号已经可以正常登录。等子女端完成绑定后，这里会展示家属关系与联系方式。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前页面用途',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Text(
            '这个页面用于承接老人端“绑定部分”的首版界面。当前先展示绑定状态、家属列表和后续说明，等真实接口接入后可以直接替换数据源。',
            style: TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF44403C)),
          ),
        ],
      ),
    );
  }
}
