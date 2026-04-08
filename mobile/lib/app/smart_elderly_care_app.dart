import 'package:flutter/material.dart';

import '../features/child/presentation/child_main_page.dart';
import '../features/elder/presentation/elder_home_page.dart';
import '../features/elder/presentation/elder_login_page.dart';

/// 应用根组件：主题、路由入口。
class SmartElderlyCareApp extends StatelessWidget {
  const SmartElderlyCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智慧养老',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      initialRoute: '/elder/login',
      routes: {
        '/elder/login': (_) => const ElderLoginPage(),
        '/elder/home': (_) => const ElderHomePage(),
        '/child': (_) => const ChildMainPage(),
      },
    );
  }
}
