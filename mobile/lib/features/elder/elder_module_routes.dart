import 'package:flutter/material.dart';

import 'presentation/elder_binding_status_page.dart';
import 'presentation/elder_home_page.dart';
import 'presentation/elder_register_page.dart';

/// 老人端模块对外暴露的路由常量与路由表。
final class ElderModuleRoutes {
  ElderModuleRoutes._();

  static const String elderRegister = '/elder/register';
  static const String elderHome = '/elder/home';
  static const String elderBinding = '/elder/binding';

  static Map<String, WidgetBuilder> routes() {
    return {
      elderRegister: (_) => const ElderRegisterPage(),
      elderHome: (_) => const ElderHomePage(),
      elderBinding: (_) => const ElderBindingStatusPage(),
    };
  }
}
