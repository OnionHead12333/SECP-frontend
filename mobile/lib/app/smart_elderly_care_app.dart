import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/child/presentation/pages/child_fall_alerts_page.dart';
import '../features/child/presentation/pages/child_remote_car_page.dart';
import '../features/child/presentation/child_main_page.dart';
import '../features/elder/elder_module_routes.dart';
import '../features/elder/presentation/elder_global_sos_overlay.dart';
import '../features/entertainment/presentation/entertainment_page.dart';
import '../features/inspection/presentation/employee_emergency_alerts_page.dart';
import '../features/inspection/presentation/employee_home_page.dart';
import '../features/inspection/presentation/inspection_events_page.dart';
import '../features/inspection/presentation/inspection_map_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 应用根组件：主题、路由入口。
class SmartElderlyCareApp extends StatelessWidget {
  const SmartElderlyCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      title: '智慧养老',
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      builder: (context, child) => ElderGlobalSosOverlay(
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        child: child ?? const SizedBox.shrink(),
      ),
      routes: {
        '/login': (_) => const LoginPage(),
        ...ElderModuleRoutes.routes(),
        '/child': (_) => const ChildMainPage(),
        '/child/fall-alerts': (_) => const ChildFallAlertsPage(),
        '/child/remote-car': (_) => const ChildRemoteCarPage(),
        '/employee': (_) => const EmployeeHomePage(),
        '/employee/emergency-alerts': (_) =>
            const EmployeeEmergencyAlertsPage(),
        '/employee/entertainment': (_) => const EntertainmentPage(),
        '/inspection/map': (_) => const InspectionMapPage(),
        '/inspection/events': (_) => const InspectionEventsPage(),
      },
    );
  }
}
