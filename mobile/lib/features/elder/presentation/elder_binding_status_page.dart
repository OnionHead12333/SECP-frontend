import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/config/app_config.dart';
import '../data/elder_bound_family_api.dart';
import '../data/elder_mock_auth_service.dart';
import '../models/elder_bound_child.dart';

class ElderBindingStatusPage extends StatefulWidget {
  const ElderBindingStatusPage({super.key});

  @override
  State<ElderBindingStatusPage> createState() => _ElderBindingStatusPageState();
}

class _ElderBindingStatusPageState extends State<ElderBindingStatusPage> {
  bool _loading = true;
  String? _error;
  List<ElderBoundChild> _children = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (AppConfig.useMockEmergencyContacts) {
        final members = ElderMockAuthService.familyMembersForPhone(AuthSession.elderPhone ?? '');
        if (!mounted) return;
        setState(() {
          _children = [
            for (var i = 0; i < members.length; i++)
              ElderBoundChild(
                childUserId: 'mock_$i',
                name: members[i].name,
                phone: members[i].phone,
                relation: members[i].relation,
                isPrimary: members[i].isPrimary,
              ),
          ];
        });
      } else {
        final list = await ElderBoundFamilyApi.list();
        if (!mounted) return;
        setState(() => _children = list);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = AuthSession.elderPhone ?? '';
    final hasBindings = _children.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('家属绑定详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) ...[
                    Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '加载失败：$_error',
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _load,
                      child: const Text('重试'),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _SummaryBanner(
                    hasBindings: hasBindings,
                    familyCount: _children.length,
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
                    for (final c in _children) ...[
                      _FamilyMemberCard(
                        name: c.name,
                        phone: c.phone,
                        relation: c.relation,
                        isPrimary: c.isPrimary,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ] else if (_error == null) ...[
                    const _EmptyBindingCard(),
                  ],
                  const SizedBox(height: 18),
                  const _NextStepCard(),
                ],
              ),
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
            hasBindings ? '已绑定 $familyCount 位家属，可继续查看下方详情。' : '子女在注册绑定流程中关联本账号后，会在此自动显示。',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({
    required this.name,
    required this.phone,
    required this.relation,
    required this.isPrimary,
  });

  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

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
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '主联系人',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('关系：$relation', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text('联系电话：$phone', style: const TextStyle(fontSize: 16)),
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
      child: const Column(
        children: [
          Icon(Icons.link_off_outlined, size: 44, color: Color(0xFF64748B)),
          SizedBox(height: 12),
          Text(
            '还没有家属绑定',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            '请子女在「带老人注册」流程中完成关联；完成后刷新本页即可看到家属信息。',
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
            '说明',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Text(
            '列表数据来自服务端家庭绑定；紧急联系人见「紧急联系人」页面，与 emergency_contacts 表同步。',
            style: TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF44403C)),
          ),
        ],
      ),
    );
  }
}
