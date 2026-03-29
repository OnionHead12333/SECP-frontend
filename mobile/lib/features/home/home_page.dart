import 'package:flutter/material.dart';

import 'data/health_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _reload() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智慧养老'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: '重新检测',
          ),
        ],
      ),
      body: FutureBuilder(
        future: HealthApi.fetchHealth(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '无法连接后端：${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final r = snapshot.data!;
          if (!r.isSuccess) {
            return Center(child: Text('接口异常：${r.message} (code=${r.code})'));
          }
          final status = r.data?['status']?.toString() ?? '-';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text('后端状态：$status', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '请先启动 Spring Boot（端口 8080），\n模拟器使用 10.0.2.2 访问本机。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
