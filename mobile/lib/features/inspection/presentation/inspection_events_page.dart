import 'package:flutter/material.dart';

import '../data/inspection_service.dart';
import '../models/inspection_marker.dart';
import 'inspection_marker_detail_sheet.dart';

class InspectionEventsPage extends StatefulWidget {
  const InspectionEventsPage({super.key});

  @override
  State<InspectionEventsPage> createState() => _InspectionEventsPageState();
}

class _InspectionEventsPageState extends State<InspectionEventsPage> {
  late Future<List<InspectionMarker>> _future;

  @override
  void initState() {
    super.initState();
    _future = InspectionService.getEventMarkers();
  }

  void _reload() {
    setState(() {
      _future = InspectionService.getEventMarkers();
    });
  }

  Future<void> _showDetail(InspectionMarker marker) async {
    final detail = await InspectionService.getMarkerDetail(marker.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => InspectionMarkerDetailSheet(
        marker: detail,
        onHandled: (_) => _reload(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('异常事件'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<InspectionMarker>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data ?? const <InspectionMarker>[];
          if (events.isEmpty) {
            return const Center(child: Text('暂无异常事件'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _eventColor(event).withValues(alpha: 0.14),
                    foregroundColor: _eventColor(event),
                    child: Icon(_eventIcon(event)),
                  ),
                  title: Text(event.title),
                  subtitle: Text(
                      '${event.locationName ?? '-'} · ${event.time ?? '-'}'),
                  trailing: Text(InspectionMarker.statusToJson(event.status)),
                  onTap: () => _showDetail(event),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Color _eventColor(InspectionMarker marker) {
    if (marker.status == InspectionMarkerStatus.handled) return Colors.grey;
    if (marker.isSosAlarm) return Colors.red.shade800;
    switch (marker.type) {
      case 'fall':
        return Colors.red;
      case 'crack':
        return Colors.amber.shade700;
      case 'obstacle':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  static IconData _eventIcon(InspectionMarker marker) {
    if (marker.isSosAlarm) return Icons.sos_outlined;
    switch (marker.type) {
      case 'sos':
        return Icons.sos_outlined;
      case 'fall':
        return Icons.personal_injury_outlined;
      case 'crack':
        return Icons.warning_amber_outlined;
      case 'obstacle':
        return Icons.report_problem_outlined;
      default:
        return Icons.error_outline;
    }
  }
}
