import 'package:flutter/material.dart';

import '../data/entertainment_api.dart';

class EntertainmentPage extends StatefulWidget {
  const EntertainmentPage({super.key});

  @override
  State<EntertainmentPage> createState() => _EntertainmentPageState();
}

class _EntertainmentPageState extends State<EntertainmentPage> {
  static const _danceModes = ['gentle', 'happy', 'exercise'];

  String _danceMode = _danceModes.first;
  bool _loading = true;
  bool _sending = false;
  bool _stoppingDance = false;
  String? _error;
  String? _activeDanceTaskId;
  String? _danceStopText;
  List<EntertainmentMusic> _music = const [];
  List<EntertainmentTaskStatus> _tasks = const [];
  EntertainmentTaskStatus? _status;

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
      final results = await Future.wait<Object?>([
        EntertainmentApi.fetchMusic(),
        EntertainmentApi.fetchTasks(),
        EntertainmentApi.fetchStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _music = results[0] as List<EntertainmentMusic>;
        _tasks = results[1] as List<EntertainmentTaskStatus>;
        _status = results[2] as EntertainmentTaskStatus?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendPlay(EntertainmentMusic music) async {
    await _sendCommand(
      successText: '命令已发送',
      send: () => EntertainmentApi.playMusic(music),
    );
  }

  Future<void> _sendDance(EntertainmentMusic music) async {
    await _sendCommand(
      successText: '跳舞命令已发送',
      send: () => EntertainmentApi.startDance(music, danceMode: _danceMode),
      onSuccess: (status) {
        if (status?.taskId != null && status!.taskId!.isNotEmpty) {
          _activeDanceTaskId = status.taskId;
          _danceStopText = null;
        }
      },
    );
  }

  Future<void> _stopDance() async {
    final taskId = _activeDanceTaskId;
    if (taskId == null || taskId.isEmpty || _stoppingDance) return;
    setState(() {
      _stoppingDance = true;
      _danceStopText = '正在停止...';
    });
    try {
      final status = await EntertainmentApi.stopDance(taskId);
      if (!mounted) return;
      setState(() {
        if (status != null) _status = status;
        if (status?.status.toLowerCase() == 'cancelled' ||
            status?.status.toLowerCase() == 'canceled') {
          _danceStopText = '已停止';
          _activeDanceTaskId = null;
        } else {
          _danceStopText = status?.message ?? '停止命令已发送';
        }
      });
      await _refreshTasksAndStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _danceStopText = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_danceStopText!)),
      );
    } finally {
      if (mounted) setState(() => _stoppingDance = false);
    }
  }

  Future<void> _sendCommand({
    required String successText,
    required Future<EntertainmentTaskStatus?> Function() send,
    void Function(EntertainmentTaskStatus? status)? onSuccess,
  }) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final status = await send();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successText)),
      );
      setState(() {
        onSuccess?.call(status);
        if (status != null) _status = status;
      });
      await _refreshTasksAndStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refreshTasksAndStatus() async {
    try {
      final results = await Future.wait<Object?>([
        EntertainmentApi.fetchTasks(),
        EntertainmentApi.fetchStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<EntertainmentTaskStatus>;
        _status = results[1] as EntertainmentTaskStatus?;
      });
    } catch (_) {
      // Command success is already visible; task refresh can recover on manual refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('娱乐'),
        backgroundColor: const Color(0xFFF7F8FC),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _music.isEmpty && _tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _music.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _StatusPanel(
              status: _status ?? (_tasks.isEmpty ? null : _tasks.first)),
          const SizedBox(height: 12),
          _ModeSelector(
            value: _danceMode,
            modes: _danceModes,
            activeTaskId: _activeDanceTaskId,
            stopping: _stoppingDance,
            stopText: _danceStopText,
            onChanged: (value) => setState(() => _danceMode = value),
            onStopDance: _stopDance,
          ),
          const SizedBox(height: 12),
          Text(
            '音乐列表',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (_music.isEmpty)
            const _EmptyPanel(text: '暂无音乐')
          else
            for (final item in _music) ...[
              _MusicCard(
                music: item,
                sending: _sending,
                onPlay: () => _sendPlay(item),
                onDance: () => _sendDance(item),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 6),
          Text(
            '最近任务',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (_tasks.isEmpty)
            const _EmptyPanel(text: '暂无任务')
          else
            for (final task in _tasks) ...[
              _TaskTile(task: task),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status});

  final EntertainmentTaskStatus? status;

  @override
  Widget build(BuildContext context) {
    final value = status?.status ?? 'pending';
    return _Panel(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _statusColor(value).withValues(alpha: 0.12),
            child: Icon(Icons.sensors_outlined, color: _statusColor(value)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '最近任务状态',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.value,
    required this.modes,
    required this.activeTaskId,
    required this.stopping,
    required this.stopText,
    required this.onChanged,
    required this.onStopDance,
  });

  final String value;
  final List<String> modes;
  final String? activeTaskId;
  final bool stopping;
  final String? stopText;
  final ValueChanged<String> onChanged;
  final VoidCallback onStopDance;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_run_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '跳舞模式',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              DropdownButton<String>(
                value: value,
                items: [
                  for (final mode in modes)
                    DropdownMenuItem(value: mode, child: Text(mode)),
                ],
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ],
          ),
          if (activeTaskId != null || stopText != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      activeTaskId == null || stopping ? null : onStopDance,
                  icon: stopping
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: Text(stopping ? '正在停止...' : '停止'),
                ),
                if (stopText != null)
                  Text(
                    stopText!,
                    style: TextStyle(
                      color: stopText == '已停止'
                          ? const Color(0xFF15803D)
                          : const Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({
    required this.music,
    required this.sending,
    required this.onPlay,
    required this.onDance,
  });

  final EntertainmentMusic music;
  final bool sending;
  final VoidCallback onPlay;
  final VoidCallback onDance;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(child: Icon(Icons.music_note)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      music.musicName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${music.artist} · ${_formatDuration(music.durationSeconds)}',
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            music.suitableScene,
            style: const TextStyle(color: Color(0xFF334155)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: sending ? null : onPlay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('播放音乐'),
              ),
              OutlinedButton.icon(
                onPressed: sending ? null : onDance,
                icon: const Icon(Icons.sports_kabaddi_outlined),
                label: const Text('播放并跳舞'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final EntertainmentTaskStatus task;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (task.musicName != null) task.musicName,
      if (task.commandType != null) task.commandType,
      if (task.danceMode != null) task.danceMode,
      if (task.message != null) task.message,
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(Icons.task_alt, color: _statusColor(task.status)),
        title: Text(task.status),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: task.taskId == null
            ? null
            : Text(
                task.taskId!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Panel(child: Center(child: Text(text)));
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return const Color(0xFF15803D);
    case 'failed':
    case 'cancelled':
    case 'canceled':
      return const Color(0xFFB91C1C);
    case 'running':
      return const Color(0xFF2563EB);
    case 'sent':
      return const Color(0xFF7C3AED);
    case 'pending':
    default:
      return const Color(0xFFB45309);
  }
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}
