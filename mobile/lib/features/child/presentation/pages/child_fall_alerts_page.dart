import 'package:flutter/material.dart';

import '../../data/child_fall_alerts_api.dart';
import '../../models/child_fall_alert.dart';

class ChildFallAlertsPage extends StatefulWidget {
  const ChildFallAlertsPage({super.key});

  @override
  State<ChildFallAlertsPage> createState() => _ChildFallAlertsPageState();
}

class _ChildFallAlertsPageState extends State<ChildFallAlertsPage> {
  late Future<List<ChildFallAlert>> _future;

  @override
  void initState() {
    super.initState();
    _future = ChildFallAlertsApi.list();
  }

  void _reload() {
    setState(() {
      _future = ChildFallAlertsApi.list();
    });
  }

  Future<void> _showDetail(ChildFallAlert alert) async {
    final detail = await ChildFallAlertsApi.detail(alert.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ChildFallAlertDetailDialog(alert: detail),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('跌倒告警'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ChildFallAlert>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '跌倒告警加载失败：${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final alerts = snapshot.data ?? const <ChildFallAlert>[];
          if (alerts.isEmpty) {
            return const Center(child: Text('暂无绑定老人的跌倒告警'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _statusColor(alert).withValues(alpha: 0.12),
                    foregroundColor: _statusColor(alert),
                    child: const Icon(Icons.personal_injury_outlined),
                  ),
                  title: Text(alert.displayTitle),
                  subtitle: Text(
                    '${alert.displayElderName} · ${alert.locationName ?? '-'} · ${alert.timeText.isEmpty ? '-' : alert.timeText}\n'
                    '等级：${alert.level ?? '-'} · 状态：${alert.status}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDetail(alert),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Color _statusColor(ChildFallAlert alert) {
    return alert.status == 'handled' ? Colors.grey : Colors.red;
  }
}

class _ChildFallAlertDetailDialog extends StatelessWidget {
  const _ChildFallAlertDetailDialog({required this.alert});

  final ChildFallAlert alert;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.displayTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: '老人', value: alert.displayElderName),
                _InfoRow(label: '身份来源', value: alert.identitySource ?? '-'),
                _InfoRow(
                  label: '置信度',
                  value: alert.identityConfidence?.toStringAsFixed(2) ?? '-',
                ),
                _InfoRow(
                  label: '是否通知子女',
                  value: alert.notifiedChild == true ? '已通知' : '未通知',
                ),
                _InfoRow(label: '位置', value: alert.locationName ?? '-'),
                _InfoRow(label: '时间', value: alert.time ?? '-'),
                _InfoRow(label: '图片', value: alert.imageUrl ?? '-'),
                _InfoRow(label: '说明', value: alert.displayMessage),
                _InfoRow(label: '状态', value: alert.status),
                _InfoRow(label: '处理人', value: alert.handler ?? '-'),
                _InfoRow(label: '处理备注', value: alert.remark ?? '-'),
                _InfoRow(label: '处理时间', value: alert.handleTime ?? '-'),
                if (alert.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  _ImagePreview(imageUrl: alert.imageUrl!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (!imageUrl.startsWith('http')) {
      return const _ImagePlaceholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        height: 160,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
