import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:smart_elderly_care_mobile/core/auth/auth_session.dart';
import 'package:smart_elderly_care_mobile/core/network/api_client.dart';
import 'package:smart_elderly_care_mobile/features/child/data/child_fall_alerts_api.dart';
import 'package:smart_elderly_care_mobile/features/child/models/child_fall_alert.dart';
import 'package:smart_elderly_care_mobile/features/child/models/child_local_models.dart';
import 'package:smart_elderly_care_mobile/features/child/presentation/pages/child_fall_alerts_page.dart';
import 'package:smart_elderly_care_mobile/features/child/presentation/tabs/child_overview_tab.dart';
import 'package:smart_elderly_care_mobile/features/child/models/device_status_snapshot.dart';

void main() {
  tearDown(() {
    ChildFallAlertsApi.clearMockAlertsForTest();
    AuthSession.clear();
  });

  test('child fall alert parses unknown identity and message fallback', () {
    final alert = ChildFallAlert.fromJson({
      'id': 2,
      'title': '后端标题',
      'elderName': '',
      'identitySource': 'unknown',
      'identityConfidence': 0,
      'notifiedChild': true,
      'locationName': '一层大厅',
      'time': '2026-07-10 16:40',
      'level': 'danger',
      'status': 'unhandled',
      'message': '只有 message',
    });

    expect(alert.displayElderName, '未知人员');
    expect(alert.displayTitle, '未知人员疑似跌倒');
    expect(alert.displayMessage, '只有 message');
  });

  test('child fall alerts sort unhandled before handled', () {
    final alerts = ChildFallAlert.sorted([
      ChildFallAlert.fromJson({
        'id': 1,
        'title': '已处理',
        'elderName': '张爷爷',
        'x': 0,
        'y': 0,
        'status': 'handled',
        'time': '2026-07-10 16:30',
      }),
      ChildFallAlert.fromJson({
        'id': 2,
        'title': '未处理',
        'elderName': '李奶奶',
        'x': 0,
        'y': 0,
        'status': 'unhandled',
        'time': '2026-07-10 16:40',
      }),
    ]);

    expect(alerts.map((e) => e.status), ['unhandled', 'handled']);
  });

  test('child fall alerts API sends current childUserId query', () async {
    AuthSession.childUserId = 42;
    final captured = <String, Map<String, dynamic>>{};
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        captured[options.path] = Map<String, dynamic>.from(
          options.queryParameters,
        );
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            data: {
              'code': 0,
              'message': 'ok',
              'data': options.path.endsWith('/7') ? {'id': 7} : <Object?>[],
            },
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    await ChildFallAlertsApi.list();
    await ChildFallAlertsApi.detail(7);

    expect(captured['/child/fall-alerts']?['childUserId'], 42);
    expect(captured['/child/fall-alerts/7']?['childUserId'], 42);
  });

  testWidgets('child fall alerts page shows bound elder empty message',
      (tester) async {
    ChildFallAlertsApi.setMockAlertsForTest([]);

    await tester.pumpWidget(const MaterialApp(home: ChildFallAlertsPage()));
    await tester.pumpAndSettle();

    expect(find.text('暂无绑定老人的跌倒告警'), findsOneWidget);
  });

  testWidgets('child overview exposes fall alerts entry', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChildOverviewTab(
            elders: [BoundElder(id: '1', displayName: '张爷爷')],
            currentElder: BoundElder(id: '1', displayName: '张爷爷'),
            activity: ActivitySnapshot(
              stepsToday: 0,
              stateLabel: '正常',
              updatedAt: DateTime(2026, 7, 10, 16),
            ),
            helpRecords: const [],
            deviceStatuses: const <DeviceStatusSnapshot>[],
            onOpenFallAlerts: () => opened = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('跌倒告警'));

    expect(opened, isTrue);
  });

  testWidgets('child fall alerts page shows list and read-only detail',
      (tester) async {
    ChildFallAlertsApi.setMockAlertsForTest([
      {
        'id': 1,
        'title': '张爷爷疑似跌倒',
        'elderName': '张爷爷',
        'identitySource': 'recent_identity',
        'identityConfidence': 0.89,
        'notifiedChild': true,
        'locationName': '一层东侧走廊',
        'time': '2026-07-10 16:30',
        'level': 'danger',
        'status': 'handled',
        'description': '后端描述',
        'handler': '员工A',
        'remark': '已前往现场确认',
        'handleTime': '2026-07-10 16:35',
      },
      {
        'id': 2,
        'title': '未知人员疑似跌倒',
        'elderName': '',
        'identitySource': 'unknown',
        'identityConfidence': 0,
        'notifiedChild': false,
        'locationName': '一层大厅',
        'time': '2026-07-10 16:40',
        'level': 'danger',
        'status': 'unhandled',
        'message': '只有 message',
      },
    ]);

    await tester.pumpWidget(const MaterialApp(home: ChildFallAlertsPage()));
    await tester.pumpAndSettle();

    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(2));
    expect(
      tester.widget<ListTile>(tiles.at(0)).title,
      isA<Text>().having((text) => text.data, 'data', '未知人员疑似跌倒'),
    );
    expect(find.text('张爷爷疑似跌倒'), findsOneWidget);

    await tester.tap(find.text('未知人员疑似跌倒'));
    await tester.pumpAndSettle();

    expect(find.text('未知人员'), findsWidgets);
    expect(find.text('unknown'), findsOneWidget);
    expect(find.text('未通知'), findsOneWidget);
    expect(find.text('只有 message'), findsOneWidget);
    expect(find.text('标记为已处理'), findsNothing);
  });
}
