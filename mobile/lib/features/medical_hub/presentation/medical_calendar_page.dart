import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../../child/models/child_local_models.dart';
import '../data/medical_hub_api.dart';

/// 医疗提醒日历（月视图 + 当日列表）。
class MedicalCalendarPage extends StatefulWidget {
  const MedicalCalendarPage({super.key, this.elders});

  final List<BoundElder>? elders;

  @override
  State<MedicalCalendarPage> createState() => _MedicalCalendarPageState();
}

class _MedicalCalendarPageState extends State<MedicalCalendarPage> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  String? _elderKey;
  String? _typeFilter;
  List<MedicalCalendarEventView> _events = [];
  bool _busy = false;

  int? get _elderProfileId {
    if (AuthSession.role == AppRole.child) {
      if (widget.elders == null || widget.elders!.isEmpty) return null;
      final key = _elderKey ?? widget.elders!.first.id;
      return int.tryParse(key);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selected = DateTime.now();
    if (widget.elders != null && widget.elders!.isNotEmpty) {
      _elderKey = widget.elders!.first.id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonth());
  }

  Future<void> _loadMonth() async {
    if (AuthSession.role == AppRole.child && _elderProfileId == null) return;
    final start = DateTime(_focused.year, _focused.month, 1);
    final end = DateTime(_focused.year, _focused.month + 1, 1);
    setState(() => _busy = true);
    try {
      final list = await MedicalHubApi.listCalendarEvents(
        elderProfileId: _elderProfileId,
        from: start,
        to: end,
        eventType: _typeFilter != null && _typeFilter!.isNotEmpty ? _typeFilter : null,
      );
      if (!mounted) return;
      setState(() => _events = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<MedicalCalendarEventView> _forDay(DateTime d) {
    return _events.where((e) {
      final sd = DateTime(e.startAt.year, e.startAt.month, e.startAt.day);
      final dd = DateTime(d.year, d.month, d.day);
      return sd == dd;
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  Future<void> _delete(MedicalCalendarEventView e) async {
    try {
      await MedicalHubApi.deleteCalendarEvent(e.id, elderProfileId: _elderProfileId);
      await _loadMonth();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final childNoElder =
        AuthSession.role == AppRole.child && (widget.elders == null || widget.elders!.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('医疗日历')),
      body: childNoElder
          ? const Center(child: Text('请先绑定老人'))
          : Column(
              children: [
                if (widget.elders != null && widget.elders!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DropdownButtonFormField<String>(
                      value: _elderKey,
                      decoration: const InputDecoration(labelText: '查看谁的日历'),
                      items: widget.elders!
                          .map((e) => DropdownMenuItem(value: e.id, child: Text(e.displayName)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _elderKey = v);
                        _loadMonth();
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: _typeFilter == null || _typeFilter!.isEmpty,
                        onSelected: (_) {
                          setState(() => _typeFilter = null);
                          _loadMonth();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('检查'),
                        selected: _typeFilter == 'EXAM',
                        onSelected: (_) {
                          setState(() => _typeFilter = 'EXAM');
                          _loadMonth();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('复诊'),
                        selected: _typeFilter == 'FOLLOWUP',
                        onSelected: (_) {
                          setState(() => _typeFilter = 'FOLLOWUP');
                          _loadMonth();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('用药'),
                        selected: _typeFilter == 'MEDICATION',
                        onSelected: (_) {
                          setState(() => _typeFilter = 'MEDICATION');
                          _loadMonth();
                        },
                      ),
                    ],
                  ),
                ),
                TableCalendar<MedicalCalendarEventView>(
                  firstDay: DateTime(2020, 1, 1),
                  lastDay: DateTime(2035, 12, 31),
                  focusedDay: _focused,
                  selectedDayPredicate: (d) =>
                      _selected != null &&
                      d.year == _selected!.year &&
                      d.month == _selected!.month &&
                      d.day == _selected!.day,
                  eventLoader: _forDay,
                  onDaySelected: (sel, foc) {
                    setState(() {
                      _selected = sel;
                      _focused = foc;
                    });
                  },
                  onPageChanged: (foc) {
                    _focused = foc;
                    _loadMonth();
                  },
                  calendarStyle: const CalendarStyle(markersMaxCount: 3),
                ),
                if (_busy) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        _selected == null ? '选择日期' : '${_selected!.month}月${_selected!.day}日 的安排',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      ...(_selected == null
                          ? <Widget>[]
                          : _forDay(_selected!)
                              .map(
                                (e) => Card(
                                  child: ListTile(
                                    title: Text(e.title),
                                    subtitle: Text(
                                      '${e.eventType} · ${TimeOfDay.fromDateTime(e.startAt).format(context)}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _delete(e),
                                    ),
                                  ),
                                ),
                              )
                              .toList()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
