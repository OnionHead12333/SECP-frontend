import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../data/community_friend_repository.dart';
import '../data/friend_discover_catalog.dart';
import '../models/community_friend.dart';

/// 老人端：添加好友（手机号 / 同群推荐）。
final class ElderAddFriendPage extends StatefulWidget {
  const ElderAddFriendPage({super.key, required this.ownerScopeKey});

  final String ownerScopeKey;

  @override
  State<ElderAddFriendPage> createState() => _ElderAddFriendPageState();
}

class _ElderAddFriendPageState extends State<ElderAddFriendPage> {
  final _phoneCtrl = TextEditingController();
  Set<String> _friendScopeKeys = {};
  bool _loading = true;
  bool _submitting = false;

  static final RegExp _cnMobile = RegExp(r'^1[3-9]\d{9}$');

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final keys = await CommunityFriendRepository.loadFriendScopeKeys(widget.ownerScopeKey);
    if (!mounted) return;
    setState(() {
      _friendScopeKeys = keys;
      _loading = false;
    });
  }

  String? get _selfPhone => AuthSession.elderPhone?.trim();

  Future<void> _addCandidate(ElderFriendCandidate candidate) async {
    if (_friendScopeKeys.contains(candidate.scopeKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${candidate.displayName}」已经是您的好友')),
      );
      return;
    }
    if (_selfPhone != null && _selfPhone == candidate.phone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能添加自己为好友')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await CommunityFriendRepository.addFriend(
        ownerScopeKey: widget.ownerScopeKey,
        candidate: candidate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加好友「${candidate.displayName}」')),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addByPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (!_cnMobile.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入11位中国大陆手机号')),
      );
      return;
    }
    if (_selfPhone != null && _selfPhone == phone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能添加自己为好友')),
      );
      return;
    }
    if (await CommunityFriendRepository.isFriendByPhone(widget.ownerScopeKey, phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该手机号已在好友列表中')),
      );
      return;
    }

    final known = FriendDiscoverCatalog.byPhone(phone);
    final candidate = known ??
        ElderFriendCandidate(
          scopeKey: 'phone_$phone',
          displayName: '手机尾号${phone.substring(phone.length - 4)}',
          phone: phone,
          hint: '通过手机号添加',
          emoji: '👤',
        );
    await _addCandidate(candidate);
  }

  List<ElderFriendCandidate> get _recommendations {
    return FriendDiscoverCatalog.all
        .where((c) => !_friendScopeKeys.contains(c.scopeKey))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('添加好友'),
        backgroundColor: const Color(0xFFF7F8FC),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '通过手机号添加',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        style: const TextStyle(fontSize: 20),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '请输入对方手机号',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _submitting ? null : () => unawaited(_addByPhone()),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('添加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '同群推荐',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  '这些朋友也在兴趣社群里，可以一键添加',
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.45),
                ),
                const SizedBox(height: 12),
                if (_recommendations.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      '推荐好友都已添加完毕',
                      style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                    ),
                  )
                else
                  ..._recommendations.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _submitting ? null : () => unawaited(_addCandidate(c)),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Text(c.emoji, style: const TextStyle(fontSize: 36, height: 1)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.displayName,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c.phone,
                                        style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.hint,
                                        style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1565C0)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
