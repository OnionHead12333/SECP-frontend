import 'package:flutter/material.dart';

class EmployeeHomePage extends StatelessWidget {
  const EmployeeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('员工端首页')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EntryTile(
            title: '巡检地图',
            subtitle: '查看实时地图、设置导航目标并检查启动状态',
            icon: Icons.map_outlined,
            onTap: () =>
                Navigator.of(context).pushNamed('/employee/robot-inspection'),
          ),
          const SizedBox(height: 12),
          _EntryTile(
            title: '异常事件',
            subtitle: '查看待处理的跌倒、裂缝和障碍物',
            icon: Icons.assignment_late_outlined,
            onTap: () => Navigator.of(context).pushNamed('/inspection/events'),
          ),
          const SizedBox(height: 12),
          _EntryTile(
            title: '娱乐',
            subtitle: '发送音乐播放与跳舞演示命令，查看最近任务状态',
            icon: Icons.music_note_outlined,
            onTap: () =>
                Navigator.of(context).pushNamed('/employee/entertainment'),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
