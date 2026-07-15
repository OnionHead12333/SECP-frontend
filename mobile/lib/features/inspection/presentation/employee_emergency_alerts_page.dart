import 'package:flutter/material.dart';

import '../../emergency/data/emergency_alerts_api.dart';
import '../data/inspection_service.dart';
import '../models/inspection_marker.dart';
import 'inspection_marker_detail_sheet.dart';

class EmployeeEmergencyAlertsPage extends StatefulWidget {
  const EmployeeEmergencyAlertsPage({super.key});

  @override
  State<EmployeeEmergencyAlertsPage> createState() =>
      _EmployeeEmergencyAlertsPageState();
}

class _EmployeeEmergencyAlertsPageState
    extends State<EmployeeEmergencyAlertsPage> {
  bool _loading = true;
  bool _handling = false;
  String? _error;
  List<_SosMarkerAlert> _alerts = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final markers = await InspectionService.getMarkers();
      final sosMarkers = markers
          .where(
              (marker) => marker.isSosAlarm && marker.emergencyAlertId != null)
          .toList(growable: false);
      final loaded = <_SosMarkerAlert>[];
      for (final marker in sosMarkers) {
        final alertId = marker.emergencyAlertId!;
        final alert = await EmergencyAlertsApi.getById(alertId);
        if (alert.status == 'sent') {
          loaded.add(_SosMarkerAlert(marker: marker, alert: alert));
        }
      }
      if (!mounted) return;
      setState(() {
        _alerts = loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '报警列表加载失败，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markHandled(_SosMarkerAlert item) async {
    final id = item.alert.id;
    if (id == null || _handling) return;
    setState(() {
      _handling = true;
    });
    try {
      await EmergencyAlertsApi.markHandled(alertId: id, remark: '员工已到达');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('报警已处理')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('处理失败，请稍后重试')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _handling = false;
        });
      }
    }
  }

  Future<void> _showDetail(_SosMarkerAlert item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => InspectionMarkerDetailSheet(
        marker: item.marker,
        onHandled: (_) => _load(),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '时间未知';
    return '${time.month}/${time.day} ${_two(time.hour)}:${_two(time.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'sent':
        return '报警中';
      case 'handled':
        return '已处理';
      case 'cancelled':
      case 'canceled':
        return '已取消';
      case 'false_alarm':
        return '误报';
      default:
        return status.isEmpty ? '未知' : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS 报警'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_error != null)
              Card(
                elevation: 0,
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
            if (_loading && _alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_alerts.isEmpty)
              Card(
                elevation: 0,
                color: scheme.surfaceContainerLow,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Center(child: Text('暂无待处理 SOS 报警')),
                ),
              )
            else
              ..._alerts.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showDetail(item),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.sos_outlined,
                                color: scheme.error,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.marker.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '报警编号：${item.alert.id ?? item.marker.emergencyAlertId}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      '发出时间：${_formatTime(item.alert.displayTime)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Chip(
                                label: Text(_statusLabel(item.alert.status)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: scheme.errorContainer,
                              ),
                            ],
                          ),
                          if (item.marker.displayMessage != '-') ...[
                            const SizedBox(height: 8),
                            Text(item.marker.displayMessage),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed:
                                  _handling ? null : () => _markHandled(item),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('已到达'),
                            ),
                          ),
                        ],
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

class _SosMarkerAlert {
  const _SosMarkerAlert({
    required this.marker,
    required this.alert,
  });

  final InspectionMarker marker;
  final EmergencyAlertRecord alert;
}
