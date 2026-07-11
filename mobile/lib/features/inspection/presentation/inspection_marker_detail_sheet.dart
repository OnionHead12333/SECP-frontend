import 'package:flutter/material.dart';

import '../data/inspection_service.dart';
import '../models/inspection_marker.dart';

class InspectionMarkerDetailSheet extends StatefulWidget {
  const InspectionMarkerDetailSheet({
    super.key,
    required this.marker,
    required this.onHandled,
  });

  final InspectionMarker marker;
  final ValueChanged<InspectionMarker> onHandled;

  @override
  State<InspectionMarkerDetailSheet> createState() => _InspectionMarkerDetailSheetState();
}

class _InspectionMarkerDetailSheetState extends State<InspectionMarkerDetailSheet> {
  late InspectionMarker _marker;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _marker = widget.marker;
  }

  Future<void> _handle() async {
    setState(() => _handling = true);
    try {
      final updated = await InspectionService.handleMarker(
        _marker.id,
        '员工A',
        '已前往现场确认',
      );
      if (!mounted) return;
      setState(() => _marker = updated);
      widget.onHandled(updated);
    } finally {
      if (mounted) {
        setState(() => _handling = false);
      }
    }
  }

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
                        _marker.title,
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
                ..._detailRows(),
                if (_marker.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  _ImagePreview(imageUrl: _marker.imageUrl!),
                ],
                if (_marker.handler != null || _marker.remark != null || _marker.handleTime != null) ...[
                  const SizedBox(height: 12),
                  _InfoRow(label: '处理人', value: _marker.handler ?? '-'),
                  _InfoRow(label: '处理备注', value: _marker.remark ?? '-'),
                  _InfoRow(label: '处理时间', value: _marker.handleTime ?? '-'),
                ],
                if (_marker.canHandle) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _handling ? null : _handle,
                    icon: _handling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.task_alt),
                    label: const Text('标记为已处理'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _detailRows() {
    switch (_marker.type) {
      case 'fall':
        return [
          const _InfoRow(label: '事件类型', value: '跌倒'),
          _InfoRow(label: '摔倒人员', value: _marker.elderName ?? '-'),
          _InfoRow(label: '身份来源', value: _identitySourceText(_marker.identitySource)),
          _InfoRow(label: '置信度', value: _confidenceText(_marker.identityConfidence)),
          _InfoRow(label: '是否通知子女', value: _marker.notifiedChild == true ? '已通知' : '未通知'),
          _InfoRow(label: '位置', value: _marker.locationName ?? '-'),
          _InfoRow(label: '时间', value: _marker.time ?? '-'),
          _InfoRow(label: '状态', value: InspectionMarker.statusToJson(_marker.status)),
        ];
      case 'crack':
        return [
          const _InfoRow(label: '事件类型', value: '裂缝'),
          _InfoRow(label: '位置', value: _marker.locationName ?? '-'),
          _InfoRow(label: '风险等级', value: _marker.level ?? '-'),
          _InfoRow(label: '时间', value: _marker.time ?? '-'),
          _InfoRow(label: '状态', value: InspectionMarker.statusToJson(_marker.status)),
        ];
      case 'robot':
        return [
          const _InfoRow(label: '事件类型', value: '小车当前位置'),
          _InfoRow(label: '导航状态', value: _marker.navigationStatus ?? '-'),
          _InfoRow(label: '避障状态', value: _marker.obstacleStatus ?? '-'),
          const _InfoRow(label: '当前模式', value: '巡检中'),
        ];
      case 'target':
        return [
          const _InfoRow(label: '事件类型', value: '导航目标点'),
          _InfoRow(label: '位置', value: _marker.locationName ?? '-'),
          _InfoRow(label: '状态', value: InspectionMarker.statusToJson(_marker.status)),
        ];
      case 'obstacle':
        return [
          const _InfoRow(label: '事件类型', value: '障碍物'),
          _InfoRow(label: '位置', value: _marker.locationName ?? '-'),
          _InfoRow(label: '风险等级', value: _marker.level ?? '-'),
          _InfoRow(label: '状态', value: InspectionMarker.statusToJson(_marker.status)),
        ];
      default:
        return [
          _InfoRow(label: '事件类型', value: _marker.type),
          _InfoRow(label: '状态', value: InspectionMarker.statusToJson(_marker.status)),
        ];
    }
  }

  static String _identitySourceText(String? source) {
    switch (source) {
      case 'current_frame':
        return '当前帧识别';
      case 'recent_identity':
        return '最近身份缓存';
      case 'unknown':
        return '未识别';
      default:
        return '-';
    }
  }

  static String _confidenceText(double? value) {
    if (value == null) return '-';
    return value.toStringAsFixed(2);
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
