import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../data/child_activity_alerts_api.dart';
import '../../models/child_local_models.dart';
import '../widgets/child_location_map.dart';

/// ③ 安全监护：定位摘要、参考回家路线、求助处理（对接 `/v1/child/...`）。
class ChildSafetyTab extends StatelessWidget {
  const ChildSafetyTab({
    super.key,
    this.location,
    required this.track,
    this.route,
    required this.activity,
    required this.helpRecords,
    required this.activityAlerts,
    required this.onRefreshLocation,
    required this.onResolveHelp,
  });

  final LocationSnapshot? location;
  final List<LocationTrackPoint> track;
  final NavigationRouteSnapshot? route;
  final ActivitySnapshot activity;
  final List<HelpRequestRecord> helpRecords;
  final List<ActivityAlertRecord> activityAlerts;
  final VoidCallback onRefreshLocation;
  final Future<void> Function(String id) onResolveHelp;

  String _fmt(DateTime t) {
    return '${t.month}/${t.day} ${_two(t.hour)}:${_two(t.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _mapModeLabel() {
    return AppConfig.useMockLocation ? '本地自绘兜底' : '高德地图';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = location;
    final mapTrack = track.map((e) => (latitude: e.latitude, longitude: e.longitude)).toList();
    final nav = route;
    final mapRoute = nav == null
        ? const <({double latitude, double longitude})>[]
        : nav.points.map((e) => (latitude: e.latitude, longitude: e.longitude)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _SafetySectionTitle(
          title: '老人位置',
          trailing: IconButton.filledTonal(
            onPressed: onRefreshLocation,
            icon: const Icon(Icons.my_location, size: 20),
            tooltip: '刷新',
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: loc == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('暂无定位数据')),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChildLocationMap(
                        key: ValueKey(
                          '${loc.latitude}_${loc.longitude}_${loc.updatedAt.millisecondsSinceEpoch}',
                        ),
                        latitude: loc.latitude,
                        longitude: loc.longitude,
                        track: mapTrack,
                        route: mapRoute,
                        height: 232,
                        useOfflinePainter: AppConfig.useMockLocation,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConfig.useMockLocation ? const Color(0xFFF8FAFC) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppConfig.useMockLocation ? const Color(0xFFE2E8F0) : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                AppConfig.useMockLocation ? Icons.brush_outlined : Icons.map_outlined,
                                size: 18,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '地图模式',
                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppConfig.useMockLocation ? const Color(0xFFE2E8F0) : const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _mapModeLabel(),
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: AppConfig.useMockLocation ? const Color(0xFF475569) : const Color(0xFF166534),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '数据源：最新定位摘要 + 家围栏参考线',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(loc.address, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 6),
                      Text(
                        '经纬度 ${loc.latitude.toStringAsFixed(5)}，${loc.longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        '上次更新 ${_fmt(loc.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        _SafetySectionTitle(title: '路线与轨迹'),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nav != null) _RouteSummary(route: nav) else const Text('无参考回家路线数据（需定位与家围栏接口返回）'),
                if (nav != null) const SizedBox(height: 14),
                Text(
                  '最近轨迹',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (track.isEmpty)
                  Text('暂无轨迹点', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline))
                else
                  ...track.take(5).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '• ${item.label} · ${_fmt(item.recordedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                const SizedBox(height: 6),
                Text(
                  '蓝线：历史轨迹　橙线：参考回家线',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SafetySectionTitle(title: '活动状态'),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Icons.directions_walk,
                        label: '今日步数',
                        value: '${activity.stepsToday}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.accessibility_new,
                        label: '状态',
                        value: activity.stateLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '数据更新 ${_fmt(activity.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SafetySectionTitle(title: '预警消息'),
        const SizedBox(height: 8),
        if (activityAlerts.isEmpty)
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Center(
                child: Text('暂无预警消息'),
              ),
            ),
          )
        else
          ...activityAlerts.map((alert) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: scheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notifications_active_outlined, color: scheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alert.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (alert.triggeredAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _fmt(alert.triggeredAt!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(alert.content, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
        _SafetySectionTitle(title: '求助记录'),
        const SizedBox(height: 8),
        if (helpRecords.isEmpty)
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Center(
                child: Text('暂无求助记录'),
              ),
            ),
          )
        else
          ...helpRecords.map((r) {
            final pending = r.status == HelpRequestStatus.pending;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: scheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${r.elderName} · ${_fmt(r.createdAt)}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Chip(
                          label: Text(pending ? '待处理' : '已处理'),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: pending ? scheme.errorContainer : scheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(r.summary, style: Theme.of(context).textTheme.bodyMedium),
                    if (pending) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () async {
                            await onResolveHelp(r.id);
                          },
                          child: const Text('标记已处理'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SafetySectionTitle extends StatelessWidget {
  const _SafetySectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.route});

  final NavigationRouteSnapshot route;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Expanded(child: Text('${route.startLabel} → ${route.endLabel}', style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _RouteMetric(label: '预计距离', value: '${route.distanceKm.toStringAsFixed(2)} km'),
              _RouteMetric(label: '预计时间', value: '${route.estimatedMinutes} 分钟'),
            ],
          ),
          const SizedBox(height: 10),
          Text(route.statusText, style: const TextStyle(color: Color(0xFF475569), height: 1.5)),
        ],
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
