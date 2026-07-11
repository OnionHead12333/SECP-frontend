import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/core/config/app_config.dart';
import 'package:smart_elderly_care_mobile/features/inspection/data/inspection_service.dart';
import 'package:smart_elderly_care_mobile/features/inspection/models/inspection_marker.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/employee_home_page.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/inspection_events_page.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/inspection_map_page.dart';

void main() {
  group('Inspection backend config', () {
    test('uses a local IPv4 backend only for inspection by default', () {
      expect(AppConfig.apiBase, 'http://120.46.62.182:8080/api');
      expect(AppConfig.inspectionApiBase, 'http://192.168.40.1:8080/api');
      expect(AppConfig.useMockInspection, isFalse);
    });
  });

  group('InspectionService mock data', () {
    test('returns six map markers and filters event markers', () async {
      InspectionService.resetMockDataForTest();

      final markers = await InspectionService.getMarkers();
      final events = await InspectionService.getEventMarkers();

      expect(markers, hasLength(6));
      expect(markers.map((e) => e.type), containsAll(['fall', 'crack', 'robot', 'target', 'obstacle']));
      expect(events.map((e) => e.type), everyElement(isIn(['fall', 'crack', 'obstacle'])));
      expect(events.map((e) => e.type), isNot(contains('robot')));
      expect(events.map((e) => e.type), isNot(contains('target')));
    });

    test('handles an unhandled marker and keeps handler metadata', () async {
      InspectionService.resetMockDataForTest();

      final handled = await InspectionService.handleMarker(1, '员工A', '已前往现场确认');
      final detail = await InspectionService.getMarkerDetail(1);

      expect(handled.status, InspectionMarkerStatus.handled);
      expect(detail.status, InspectionMarkerStatus.handled);
      expect(detail.handler, '员工A');
      expect(detail.remark, '已前往现场确认');
      expect(detail.handleTime, isNotNull);
    });
  });

  group('Inspection widgets', () {
    testWidgets('employee home exposes map and event entries', (tester) async {
      await _pump(tester, const EmployeeHomePage());

      expect(find.text('员工端首页'), findsOneWidget);
      expect(find.text('巡检地图'), findsWidgets);
      expect(find.text('异常事件'), findsWidgets);
    });

    testWidgets('map shows all marker types and fall detail fields', (tester) async {
      InspectionService.resetMockDataForTest();
      await _pump(tester, const InspectionMapPage());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('marker-fall-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-fall-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-crack-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-robot-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-target-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('marker-obstacle-6')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('marker-fall-1')));
      await tester.pumpAndSettle();

      expect(find.text('张爷爷疑似跌倒'), findsOneWidget);
      expect(find.text('最近身份缓存'), findsOneWidget);
      expect(find.text('已通知'), findsOneWidget);
    });

    testWidgets('unknown fall, robot status, and handled state are visible', (tester) async {
      InspectionService.resetMockDataForTest();
      await _pump(tester, const InspectionMapPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('marker-fall-2')));
      await tester.pumpAndSettle();
      expect(find.text('未识别'), findsOneWidget);
      expect(find.text('未通知'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('marker-robot-4')));
      await tester.pumpAndSettle();
      expect(find.text('running'), findsOneWidget);
      expect(find.text('safe'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('marker-obstacle-6')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '标记为已处理'));
      await tester.pumpAndSettle();

      expect(find.text('handled'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '标记为已处理'), findsNothing);
      final marker = tester.widget<Opacity>(find.byKey(const ValueKey('marker-opacity-6')));
      expect(marker.opacity, lessThan(1));
    });

    testWidgets('event list only shows fall crack and obstacle', (tester) async {
      InspectionService.resetMockDataForTest();
      await _pump(tester, const InspectionEventsPage());
      await tester.pumpAndSettle();

      expect(find.text('张爷爷疑似跌倒'), findsOneWidget);
      expect(find.text('未知人员疑似跌倒'), findsOneWidget);
      expect(find.text('地面裂缝'), findsOneWidget);
      expect(find.text('前方障碍物'), findsOneWidget);
      expect(find.text('小车当前位置'), findsNothing);
      expect(find.text('导航目标：老人房间A'), findsNothing);
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: child,
      routes: {
        '/inspection/map': (_) => const InspectionMapPage(),
        '/inspection/events': (_) => const InspectionEventsPage(),
      },
    ),
  );
}
