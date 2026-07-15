import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/core/config/app_config.dart';
import 'package:smart_elderly_care_mobile/core/network/api_client.dart';
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
        'id': 77,
        'status': 'running',
        'obstacleStatus': 'safe',
        'robotX': 260,
        'robotY': 300,
        'targetX': 520,
        'targetY': 300,
        'targetName': 'room A',
        'description': 'navigating',
      });

      expect(status.taskId, 77);
      expect(status.navigationStatus, 'running');
      expect(status.obstacleStatus, 'safe');
      expect(status.robotX, 260);
      expect(status.robotY, 300);
      expect(status.targetX, 520);
      expect(status.targetY, 300);
      expect(status.targetName, 'room A');
      expect(status.displayMessage, 'navigating');
    });

    test('creates and cancels navigation tasks through backend endpoints',
        () async {
      InspectionService.clearTestOverrides();
      final requests = <String, Object?>{};
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          requests[options.uri.path] = options.data;
          final data = options.uri.path.endsWith('/cancel')
              ? {
                  'data': {'id': 77, 'status': 'cancelled'}
                }
              : {
                  'data': {
                    'id': 77,
                    'status': 'running',
                    'targetName': 'target',
                    'targetX': 123.0,
                    'targetY': 234.0,
                  }
                };
          handler.resolve(
            Response<Object?>(requestOptions: options, data: data),
          );
        },
      );
      ApiClient.dio.interceptors.add(interceptor);
      addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

      final task = await InspectionService.createNavigationTask(
        targetName: 'target',
        targetX: 123,
        targetY: 234,
      );
      await InspectionService.cancelNavigationTask(77);

      expect(task.id, 77);
      expect(task.status, 'running');
      expect(requests.keys, contains('/api/navigation/tasks'));
      expect(requests.keys, contains('/api/navigation/tasks/77/cancel'));
      expect(requests['/api/navigation/tasks'], {
        'robotId': 1,
        'creatorId': 9001,
        'mapId': 1,
        'targetName': 'target',
        'targetX': 123.0,
        'targetY': 234.0,
      });
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

      final handled =
          await InspectionService.handleMarker(1, 'staff A', 'done');
      final detail = await InspectionService.getMarkerDetail(1);

      expect(handled.status, InspectionMarkerStatus.handled);
      expect(detail.status, InspectionMarkerStatus.handled);
      expect(detail.handler, 'staff A');
      expect(detail.remark, 'done');
      expect(detail.handleTime, isNotNull);
    });

    test('uses description before message and falls back to message', () {
      final withDescription = InspectionMarker.fromJson({
        'id': 7,
        'type': 'obstacle',
        'title': 'obstacle',
        'x': 10,
        'y': 20,
        'status': 'unhandled',
        'description': 'description',
        'message': 'message',
      });
      final withMessage = InspectionMarker.fromJson({
        'id': 8,
        'type': 'crack',
        'title': 'crack',
        'x': 10,
        'y': 20,
        'status': 'unhandled',
        'message': 'message only',
      });

      expect(withDescription.displayMessage, 'description');
      expect(withMessage.displayMessage, 'message only');
    });

    test('recognizes SOS markers from type and payload alert id', () {
      final byType = InspectionMarker.fromJson({
        'id': 9,
        'type': 'sos',
        'title': 'SOS报警',
        'x': 10,
        'y': 20,
        'status': 'unhandled',
        'payloadJson': '{"purpose":"sos_alarm","alertId":456,"loop":true}',
      });
      final byPayload = InspectionMarker.fromJson({
        'id': 10,
        'type': 'alarm',
        'title': '报警',
        'x': 10,
        'y': 20,
        'status': 'unhandled',
        'payloadJson': '{"purpose":"sos_alarm","alertId":789}',
      });

      expect(byType.isSosAlarm, isTrue);
      expect(byType.emergencyAlertId, 456);
      expect(byType.isEvent, isTrue);
      expect(byPayload.isSosAlarm, isTrue);
      expect(byPayload.emergencyAlertId, 789);
      expect(byPayload.isEvent, isTrue);
    });
  });

  group('Inspection widgets', () {
    testWidgets('employee home exposes map and event entries', (tester) async {
      await _pump(tester, const EmployeeHomePage());

      expect(find.byType(ListTile), findsNWidgets(4));
    });

    testWidgets('event list includes SOS markers from inspection backend',
        (tester) async {
      InspectionService.clearTestOverrides();
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.path.endsWith('/inspection/markers')) {
            handler.resolve(Response<Object?>(
              requestOptions: options,
              data: {
                'data': [
                  {
                    'id': 1,
                    'type': 'fall',
                    'title': 'fall',
                    'x': 10,
                    'y': 20,
                    'status': 'unhandled',
                  },
                  {
                    'id': 2,
                    'type': 'sos',
                    'title': 'SOS报警',
                    'x': 20,
                    'y': 30,
                    'status': 'unhandled',
                    'payloadJson':
                        '{"purpose":"sos_alarm","alertId":456,"loop":true}',
                  },
                  {
                    'id': 3,
                    'type': 'robot',
                    'title': 'robot',
                    'x': 30,
                    'y': 40,
                    'status': 'active',
                  },
                ],
              },
            ));
            return;
          }
          handler.resolve(Response<Object?>(
            requestOptions: options,
            data: {'data': {}},
          ));
        },
      );
      ApiClient.dio.interceptors.add(interceptor);
      addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

      await _pump(tester, const InspectionEventsPage());
      await _pumpAsyncWork(tester);

      expect(find.text('fall'), findsOneWidget);
      expect(find.text('SOS报警'), findsOneWidget);
      expect(find.text('robot'), findsNothing);
    });

    testWidgets('new navigation target appears immediately after task creation',
        (tester) async {
      InspectionService.clearTestOverrides();
      final requests = <String>[];
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options.uri.path);
          if (options.uri.path.endsWith('/inspection/map')) {
            handler.resolve(Response<Object?>(
              requestOptions: options,
              data: {
                'data': {
                  'mapName': 'test map',
                  'width': 608,
                  'height': 384,
                },
              },
            ));
            return;
          }
          if (options.uri.path.endsWith('/inspection/markers')) {
            handler.resolve(Response<Object?>(
              requestOptions: options,
              data: {
                'data': [
                  {
                    'id': 4,
                    'type': 'robot',
                    'title': 'robot',
                    'x': 260,
                    'y': 300,
                    'status': 'active',
                  },
                  {
                    'id': 5,
                    'type': 'target',
                    'title': 'old target',
                    'x': 520,
                    'y': 300,
                    'status': 'active',
                  },
                ],
              },
            ));
            return;
          }
          if (options.uri.path.endsWith('/navigation/status')) {
            handler.resolve(Response<Object?>(
              requestOptions: options,
              data: {
                'data': {
                  'id': 77,
                  'status': 'running',
                  'obstacleStatus': 'safe',
                },
              },
            ));
            return;
          }
          if (options.uri.path.endsWith('/navigation/tasks')) {
            final body = Map<String, Object?>.from(options.data as Map);
            handler.resolve(Response<Object?>(
              requestOptions: options,
              data: {
                'data': {
                  'id': 77,
                  'status': 'running',
                  'targetName': body['targetName'],
                  'targetX': body['targetX'],
                  'targetY': body['targetY'],
                },
              },
            ));
            return;
          }
          handler.reject(DioException(requestOptions: options));
        },
      );
      ApiClient.dio.interceptors.add(interceptor);
      addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

      await _pump(tester, const InspectionMapPage());
      await _pumpAsyncWork(tester);

      expect(find.byKey(const ValueKey('marker-target-5')), findsOneWidget);

      final canvas = find.byKey(const ValueKey('inspection-map-canvas'));
      await tester.tapAt(tester.getTopLeft(canvas) + const Offset(160, 120));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认'));
      await _pumpAsyncWork(tester);

      expect(requests, contains('/api/navigation/tasks'));
      expect(find.byKey(const ValueKey('marker-target--77')), findsOneWidget);
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
