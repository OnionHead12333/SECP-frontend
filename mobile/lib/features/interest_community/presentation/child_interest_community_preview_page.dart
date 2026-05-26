import 'dart:async';

import 'package:flutter/material.dart';

import '../../child/models/child_local_models.dart';
import '../data/interest_community_api.dart';
import '../data/community_scope.dart';
import '../models/community_message.dart';
import 'interest_community_voice_chat_page.dart';

/// 子女端：预览绑定老人加入的兴趣群及最近发言。
final class ChildInterestCommunityPreviewPage extends StatefulWidget {
  const ChildInterestCommunityPreviewPage({
    super.key,
    required this.elders,
    required this.initialElderId,
  });

  final List<BoundElder> elders;
  final String initialElderId;

  @override
  State<ChildInterestCommunityPreviewPage> createState() => _ChildInterestCommunityPreviewPageState();
}

class _JoinedCommunityPreview {
  const _JoinedCommunityPreview({
    required this.community,
    required this.latestMessage,
  });

  final InterestCommunityBrief community;
  final InterestCommunityVoiceMessage? latestMessage;
}

class _ChildInterestCommunityPreviewPageState extends State<ChildInterestCommunityPreviewPage> {
  List<_JoinedCommunityPreview> _items = const [];
  bool _loading = true;
  late String _selectedElderId;

  BoundElder? get _selectedElder {
    for (final e in widget.elders) {
      if (e.id == _selectedElderId) return e;
    }
    return widget.elders.isEmpty ? null : widget.elders.first;
  }

  String get _scopeKey {
    final elder = _selectedElder;
    if (elder == null) return '';
    return CommunityScope.forBoundElder(elder);
  }

  @override
  void initState() {
    super.initState();
    _selectedElderId = widget.elders.any((e) => e.id == widget.initialElderId)
        ? widget.initialElderId
        : (widget.elders.isNotEmpty ? widget.elders.first.id : widget.initialElderId);
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final elder = _selectedElder;
    if (elder == null) {
      setState(() {
        _items = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final elderProfileId = int.tryParse(elder.id);
    if (elderProfileId == null || elderProfileId <= 0) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
      });
      return;
    }
    List<ChildCommunityOverviewItem> overview;
    try {
      overview = await InterestCommunityApi.listChildOverview(elderProfileId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _loading = false);
      return;
    }
    final items = overview
        .where((e) => e.joined)
        .map(
          (e) => _JoinedCommunityPreview(
            community: e.community,
            latestMessage: e.latestMessage,
          ),
        )
        .toList();
    items.sort((a, b) {
      final ta = a.latestMessage?.createdAtMillis ?? 0;
      final tb = b.latestMessage?.createdAtMillis ?? 0;
      return tb.compareTo(ta);
    });
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _switchElder() async {
    if (widget.elders.length <= 1) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  '切换查看的老人',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ...widget.elders.map(
                (e) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: e.id == _selectedElderId
                        ? Theme.of(ctx).colorScheme.primaryContainer
                        : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.elderly,
                      color: e.id == _selectedElderId
                          ? Theme.of(ctx).colorScheme.onPrimaryContainer
                          : Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(e.displayName),
                  subtitle: e.accountHint == null || e.accountHint!.isEmpty
                      ? null
                      : Text(e.accountHint!),
                  trailing: e.id == _selectedElderId ? const Icon(Icons.check_circle, color: Color(0xFF047857)) : null,
                  onTap: () => Navigator.pop(ctx, e.id),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == _selectedElderId || !mounted) return;
    setState(() => _selectedElderId = picked);
    await _reload();
  }

  Future<void> _openChat(InterestCommunityBrief community) async {
    final elder = _selectedElder;
    if (elder == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InterestCommunityVoiceChatPage(
          community: community,
          audience: InterestCommunityAudience.child,
          readOnly: true,
          viewingElderScopeKey: _scopeKey,
          viewingElderName: elder.displayName,
          elderProfileId: int.tryParse(elder.id),
        ),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  String _formatTime(int millis) {
    if (millis <= 0) return '暂无发言';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays == 1) return '昨天';
    return '${dt.month}月${dt.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final elder = _selectedElder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('父母兴趣社群'),
        actions: [
          if (widget.elders.length > 1)
            TextButton.icon(
              onPressed: () => unawaited(_switchElder()),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('切换老人'),
            ),
        ],
      ),
      body: elder == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '请先在「设置」中绑定老人',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (widget.elders.length > 1)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => unawaited(_switchElder()),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.elderly, color: scheme.primary, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '当前查看：${elder.displayName}',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '共绑定 ${widget.elders.length} 位老人 · 点击切换',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.unfold_more_rounded, color: scheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: scheme.primaryContainer,
                                    foregroundColor: scheme.onPrimaryContainer,
                                    child: const Icon(Icons.elderly),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          elder.displayName,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _items.isEmpty
                                              ? '尚未加入任何兴趣群'
                                              : '已加入 ${_items.length} 个兴趣群',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '预览父母群聊；清空记录仅对你隐藏历史，不影响父母与其他群友。',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_items.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.groups_outlined, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                                const SizedBox(height: 12),
                                Text(
                                  '${elder.displayName} 还未加入兴趣群',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '可在老人端首页进入「兴趣社群」加入太极、书法、健身或慢旅游等官方群。',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => unawaited(_openChat(item.community)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.community.previewIcon, style: const TextStyle(fontSize: 32, height: 1)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.community.name,
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item.latestMessage == null
                                                  ? '暂无发言记录'
                                                  : (item.latestMessage!.isVoice
                                                      ? '最近发送了一条 ${item.latestMessage!.displaySummary} 的语音'
                                                      : '「${item.latestMessage!.textContent}」'),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item.latestMessage == null
                                                  ? item.community.memberHint
                                                  : '${item.latestMessage!.senderDisplay} · ${_formatTime(item.latestMessage!.createdAtMillis)}',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
