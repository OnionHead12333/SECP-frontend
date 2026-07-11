import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/core/config/app_config.dart';
import 'package:smart_elderly_care_mobile/features/inspection/data/inspection_service.dart';
import 'package:smart_elderly_care_mobile/features/inspection/models/inspection_marker.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/employee_home_page.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/inspection_events_page.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/inspection_map_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Inspection backend config', () {
    test('uses real inspection backend by default', () {
      expect(AppConfig.inspectionApiBase, contains('/api'));
      expect(AppConfig.useMockInspection, isFalse);
    });
  });

  group('InspectionService data parsing', () {
    test('loads the yahboomcar map asset metadata', () async {
      InspectionService.resetMockDataForTest();

      final mapInfo = await InspectionService.getMapInfo();

      expect(mapInfo.imageAsset, 'assets/robot_maps/yahboomcar.png');
      expect(mapInfo.width, 608);
      expect(mapInfo.height, 384);
    });

    test('maps backend mapImage to the bundled yahboomcar asset', () {
      final mapInfo = InspectionMapInfo.fromJson({
        'mapName': 'yahboomcar',
        'mapImage': '/static/robot_maps/yahboomcar.png',
        'width': 608,
        'height': 384,
      });

      expect(mapInfo.imageAsset, 'assets/robot_maps/yahboomcar.png');
      expect(mapInfo.imageUrl, '/static/robot_maps/yahboomcar.png');
      expect(mapInfo.width, 608);
      expect(mapInfo.height, 384);
    });

    test('parses navigation and obstacle status from backend payload', () {
      final status = InspectionNavigationStatus.fromJson({
        'status': 'running',
        'obstacleStatus': 'safe',
        'robotX': 260,
        'robotY': 300,
        'targetX': 520,
        'targetY': 300,
        'targetName': '老人房间A',
        'description': '导航中',
      });

      expect(status.navigationStatus, 'running');
      expect(status.obstacleStatus, 'safe');
      expect(status.robotX, 260);
      expect(status.robotY, 300);
      expect(status.targetX, 520);
      expect(status.targetY, 300);
      expect(status.targetName, '老人房间A');
      expect(status.displayMessage, '导航中');
    });

    test('returns six mock markers and filters event markers in test mode',
        () async {
      InspectionService.resetMockDataForTest();

      final markers = await InspectionService.getMarkers();
      final events = await InspectionService.getEventMarkers();

      expect(markers, hasLength(6));
      expect(markers.map((e) => e.type),
          containsAll(['fall', 'crack', 'robot', 'target', 'obstacle']));
      expect(events.map((e) => e.type),
          everyElement(isIn(['fall', 'crack', 'obstacle'])));
      expect(events.map((e) => e.type), isNot(contains('robot')));
      expect(events.map((e) => e.type), isNot(contains('target')));
    });

    test('handles an unhandled marker and keeps handler metadata in test mode',
        () async {
      InspectionService.resetMockDataForTest();

      final handled = await InspectionService.handleMarker(1, '员工A', '已前往现场确认');
      final detail = await InspectionService.getMarkerDetail(1);

      expect(handled.status, InspectionMarkerStatus.handled);
      expect(detail.status, InspectionMarkerStatus.handled);
      expect(detail.handler, '员工A');
      expect(detail.remark, '已前往现场确认');
      expect(detail.handleTime, isNotNull);
    });

    test('uses description before message and falls back to message', () {
      final withDescription = InspectionMarker.fromJson({
        'id': 7,
        'type': 'obstacle',
        'title': '障碍物',
        'x': 10,
        'y': 20,
        'status': 'unhandled',
        'description': '后端描述',
        'message': '后端消息',
      });
      final withMessage = InspectionMarker.fromJson({
        'id': 8,
        'type': 'crack',
        'title': '裂缝',
        'x': 10,
        'y': 20,
        'status': 'unhandled',
        'message': '只有消息',
      });

      expect(withDescription.displayMessage, '后端描述');
      expect(withMessage.displayMessage, '只有消息');
    });
  });

  group('Inspection widgets', () {
    testWidgets('employee home exposes map and event entries', (tester) async {
      await _pump(tester, const EmployeeHomePage());

      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('event list only shows fall crack and obstacle',
        (tester) async {
      InspectionService.resetMockDataForTest();
      await _pump(tester, const InspectionEventsPage());
      await _pumpAsyncWork(tester);

      expect(find.byType(ListTile), findsNWidgets(4));
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

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
