import 'package:flutter/material.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/child/presentation/child_main_page.dart';
import '../features/home/home_page.dart';

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
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/child': (_) => const ChildMainPage(),
      },
    );
  }
}
