import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elderly_care_mobile/core/network/api_client.dart';
import 'package:smart_elderly_care_mobile/features/child/models/child_local_models.dart';
import 'package:smart_elderly_care_mobile/features/child/presentation/tabs/child_safety_tab.dart';
import 'package:smart_elderly_care_mobile/features/emergency/data/emergency_alerts_api.dart';
import 'package:smart_elderly_care_mobile/features/inspection/presentation/employee_emergency_alerts_page.dart';

void main() {
  test('updates SOS alert status through the global handled endpoint',
      () async {
    final captured = <String, Object?>{};
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        captured['method'] = options.method;
        captured['path'] = options.uri.path;
        captured['data'] = options.data;
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            data: {'code': 0, 'message': 'ok', 'data': null},
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    await EmergencyAlertsApi.markHandled(alertId: 42, remark: '员工已到达');

    expect(captured['method'], 'PUT');
    expect(captured['path'], '/api/v1/emergency-alerts/42/status');
    expect(captured['data'], {'status': 'handled', 'remark': '员工已到达'});
  });

  test('accepts plain handled alert response from status endpoint', () async {
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            data: {'id': 42, 'status': 'handled'},
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    await EmergencyAlertsApi.markHandled(alertId: 42, remark: '员工已到达');
  });

  test('accepts empty 204 response from status endpoint', () async {
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 204,
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    await EmergencyAlertsApi.markHandled(alertId: 42, remark: '员工已到达');
  });

  testWidgets('child safety tab only shows the handled action for sent alerts',
      (tester) async {
    final resolvedIds = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChildSafetyTab(
            location: null,
            track: const [],
            route: null,
            activity: ActivitySnapshot(
              stepsToday: 0,
              stateLabel: '正常',
              updatedAt: DateTime(2026, 7, 14, 10),
            ),
            helpRecords: [
              HelpRequestRecord(
                id: '42',
                elderName: '张爷爷',
                createdAt: DateTime(2026, 7, 14, 9),
                summary: '安全求助，待处理',
                status: HelpRequestStatus.pending,
                rawStatus: 'sent',
              ),
              HelpRequestRecord(
                id: '43',
                elderName: '李奶奶',
                createdAt: DateTime(2026, 7, 14, 8),
                summary: '撤销倒计时中',
                status: HelpRequestStatus.pending,
                rawStatus: 'pending_revoke',
              ),
            ],
            activityAlerts: const [],
            onRefreshLocation: () {},
            onResolveHelp: (id) async => resolvedIds.add(id),
          ),
        ),
      ),
    );

    expect(find.text('已到达'), findsOneWidget);
    await tester.tap(find.text('已到达'));
    await tester.pump();

    expect(resolvedIds, ['42']);
  });

  testWidgets('employee SOS page reads marker alert ids and marks them handled',
      (tester) async {
    final requests = <String, Object?>{};
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        requests['${options.method} ${options.uri.path}'] = options.data;
        if (options.uri.path.endsWith('/inspection/markers')) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              data: {
                'data': [
                  {
                    'id': 123,
                    'type': 'sos',
                    'level': 'danger',
                    'title': 'SOS报警',
                    'description': '老人触发SOS报警',
                    'status': 'unhandled',
                    'x': 10,
                    'y': 20,
                    'payloadJson':
                        '{"purpose":"sos_alarm","alertId":42,"loop":true}',
                  }
                ],
              },
            ),
          );
          return;
        }
        if (options.uri.path.endsWith('/v1/emergency-alerts/42')) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              data: {
                'code': 0,
                'message': 'ok',
                'data': {
                  'id': 42,
                  'status': 'sent',
                  'alertType': 'sos',
                  'sentTime': '2026-07-14T09:00:00Z',
                },
              },
            ),
          );
          return;
        }
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            data: {'code': 0, 'message': 'ok', 'data': null},
          ),
        );
      },
    );
    ApiClient.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.dio.interceptors.remove(interceptor));

    await tester.pumpWidget(
      const MaterialApp(home: EmployeeEmergencyAlertsPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(requests.keys, contains('GET /api/inspection/markers'));
    expect(requests.keys, contains('GET /api/v1/emergency-alerts/42'));
    expect(find.text('SOS报警'), findsOneWidget);
    expect(find.text('已到达'), findsOneWidget);

    await tester.tap(find.text('已到达'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      requests['PUT /api/v1/emergency-alerts/42/status'],
      {'status': 'handled', 'remark': '员工已到达'},
    );
  });
}
